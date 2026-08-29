package handler

import (
	"crypto/rand"
	"errors"
	"fmt"
	"log"
	"math/big"
	"strings"
	"time"

	"erp.local/backend/mailer"
	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

const (
	resetCodeTTL        = 10 * time.Minute
	resetResendCooldown = 60 * time.Second
	resetMaxAttempts    = 5
)

func generateResetCode() (string, error) {
	n, err := rand.Int(rand.Reader, big.NewInt(1000000))
	if err != nil {
		return "", err
	}
	return fmt.Sprintf("%06d", n.Int64()), nil
}

func normalizeResetEmail(email string) string {
	return strings.TrimSpace(strings.ToLower(email))
}

func findActiveResetCode(email string, tid uint) (*models.PasswordResetCode, error) {
	var row models.PasswordResetCode
	err := userDB.Where(
		"LOWER(email) = ? AND tenant_id = ? AND used_at IS NULL AND expires_at > ?",
		email, tid, time.Now(),
	).Order("id DESC").First(&row).Error
	if err != nil {
		return nil, err
	}
	return &row, nil
}

func loadResetUser(email string, tid uint) (*models.User, error) {
	var user models.User
	if err := userDB.Where("LOWER(email) = ? AND tenant_id = ?", email, tid).First(&user).Error; err != nil {
		return nil, err
	}
	return &user, nil
}

func matchResetCode(row *models.PasswordResetCode, code string) bool {
	code = strings.TrimSpace(code)
	if code == "" || row == nil {
		return false
	}
	return bcrypt.CompareHashAndPassword([]byte(row.CodeHash), []byte(code)) == nil
}

func bumpResetAttempts(row *models.PasswordResetCode) {
	row.Attempts++
	updates := map[string]interface{}{"attempts": row.Attempts}
	if row.Attempts >= resetMaxAttempts {
		now := time.Now()
		row.UsedAt = &now
		updates["used_at"] = now
	}
	_ = userDB.Model(row).Updates(updates).Error
}

func sendResetCodeEmail(to, code string) error {
	subject := "Your Agraz password reset code"
	body := fmt.Sprintf(
		"Your Agraz password reset code is: %s\n\nThis code expires in 10 minutes.\nIf you did not request this, you can ignore this email.\n",
		code,
	)
	return mailer.Send(to, subject, body)
}

// ForgotPassword handles POST /api/forgot-password and /api/mobile/forgot-password.
func ForgotPassword(c *fiber.Ctx) error {
	type bodyIn struct {
		Email string `json:"email"`
	}
	var body bodyIn
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	email := normalizeResetEmail(body.Email)
	if email == "" || !strings.Contains(email, "@") {
		return c.Status(400).JSON(fiber.Map{"error": "A valid email is required"})
	}
	if !mailer.Configured() {
		return c.Status(500).JSON(fiber.Map{"error": "Email sending is not configured on the server"})
	}

	tid := tenantIDFromCtx(c)
	user, err := loadResetUser(email, tid)
	if err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "No account found with that email"})
	}

	var latest models.PasswordResetCode
	if err := userDB.Where("user_id = ? AND tenant_id = ?", user.ID, tid).
		Order("id DESC").First(&latest).Error; err == nil {
		if time.Since(latest.CreatedAt) < resetResendCooldown {
			wait := int((resetResendCooldown - time.Since(latest.CreatedAt)).Seconds()) + 1
			return c.Status(429).JSON(fiber.Map{
				"error":       fmt.Sprintf("Please wait %d seconds before requesting another code", wait),
				"retry_after": wait,
			})
		}
	}

	code, err := generateResetCode()
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to generate reset code"})
	}
	hash, err := bcrypt.GenerateFromPassword([]byte(code), bcrypt.DefaultCost)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to generate reset code"})
	}

	now := time.Now()
	_ = userDB.Model(&models.PasswordResetCode{}).
		Where("user_id = ? AND tenant_id = ? AND used_at IS NULL", user.ID, tid).
		Update("used_at", now).Error

	row := models.PasswordResetCode{
		TenantID:  tid,
		UserID:    user.ID,
		Email:     email,
		CodeHash:  string(hash),
		ExpiresAt: now.Add(resetCodeTTL),
		CreatedAt: now,
	}
	if err := userDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to save reset code"})
	}

	if err := sendResetCodeEmail(email, code); err != nil {
		log.Printf("forgot-password email failed for %s: %v", email, err)
		_ = userDB.Delete(&row).Error
		return c.Status(500).JSON(fiber.Map{"error": "Failed to send reset code. Please try again."})
	}
	log.Printf("forgot-password email sent to %s (from SMTP_USER, not as recipient)", email)

	return c.JSON(fiber.Map{
		"message":    "A 6-digit code was sent to your email.",
		"expires_in": int(resetCodeTTL.Seconds()),
	})
}

// VerifyResetCode handles POST /api/verify-reset-code and /api/mobile/verify-reset-code.
func VerifyResetCode(c *fiber.Ctx) error {
	type bodyIn struct {
		Email string `json:"email"`
		Code  string `json:"code"`
	}
	var body bodyIn
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	email := normalizeResetEmail(body.Email)
	code := strings.TrimSpace(body.Code)
	if email == "" || code == "" {
		return c.Status(400).JSON(fiber.Map{"error": "email and code are required"})
	}

	tid := tenantIDFromCtx(c)
	row, err := findActiveResetCode(email, tid)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return c.Status(400).JSON(fiber.Map{"error": "Invalid or expired code. Request a new one."})
		}
		return c.Status(500).JSON(fiber.Map{"error": "Failed to verify code"})
	}
	if !matchResetCode(row, code) {
		bumpResetAttempts(row)
		return c.Status(400).JSON(fiber.Map{"error": "Incorrect code. Please try again."})
	}
	return c.JSON(fiber.Map{"message": "Code verified. You can set a new password.", "valid": true})
}

// ResetPasswordWithCode handles POST /api/reset-password and /api/mobile/reset-password.
func ResetPasswordWithCode(c *fiber.Ctx) error {
	type bodyIn struct {
		Email           string `json:"email"`
		Code            string `json:"code"`
		NewPassword     string `json:"new_password"`
		ConfirmPassword string `json:"confirm_password"`
	}
	var body bodyIn
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	email := normalizeResetEmail(body.Email)
	code := strings.TrimSpace(body.Code)
	if email == "" || code == "" {
		return c.Status(400).JSON(fiber.Map{"error": "email and code are required"})
	}
	if body.NewPassword == "" || len(body.NewPassword) < 6 {
		return c.Status(400).JSON(fiber.Map{"error": "New password must be at least 6 characters"})
	}
	if body.ConfirmPassword != "" && body.ConfirmPassword != body.NewPassword {
		return c.Status(400).JSON(fiber.Map{"error": "passwords do not match"})
	}

	tid := tenantIDFromCtx(c)
	row, err := findActiveResetCode(email, tid)
	if err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			return c.Status(400).JSON(fiber.Map{"error": "Invalid or expired code. Request a new one."})
		}
		return c.Status(500).JSON(fiber.Map{"error": "Failed to verify code"})
	}
	if !matchResetCode(row, code) {
		bumpResetAttempts(row)
		return c.Status(400).JSON(fiber.Map{"error": "Incorrect code. Please try again."})
	}

	var user models.User
	if err := userDB.Where("id = ? AND tenant_id = ?", row.UserID, tid).First(&user).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "No account found with that email"})
	}

	hashed, err := hashPassword(body.NewPassword)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Password encryption failed"})
	}
	now := time.Now()
	if err := userDB.Model(&user).Updates(map[string]interface{}{
		"password":       hashed,
		"plain_password": body.NewPassword,
		"updated_at":     now,
	}).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to reset password"})
	}
	_ = userDB.Model(row).Update("used_at", now).Error

	return c.JSON(fiber.Map{"message": "Password reset successfully. You can sign in now."})
}
