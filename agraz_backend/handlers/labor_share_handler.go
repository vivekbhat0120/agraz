package handler

import (
	"strings"
	"unicode"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"github.com/shopspring/decimal"
	"gorm.io/gorm"
)

func digitsOnlyPhone(s string) string {
	var b strings.Builder
	for _, r := range s {
		if unicode.IsDigit(r) {
			b.WriteRune(r)
		}
	}
	return b.String()
}

func last10Phone(s string) string {
	d := digitsOnlyPhone(s)
	if len(d) >= 10 {
		return d[len(d)-10:]
	}
	return d
}

func reverseLaborKind(kind string) string {
	switch normalizeLaborEntryKind(kind) {
	case "payment":
		return "receipt"
	default:
		return "receivable"
	}
}

func findUserByMobileLast10(mobile string, excludeUID uint, tenantID uint) *models.User {
	d := last10Phone(mobile)
	if len(d) < 10 || userDB == nil {
		return nil
	}
	q := userDB.Model(&models.User{}).Where("id <> ?", excludeUID)
	if tenantID > 0 {
		q = q.Where("tenant_id = ?", tenantID)
	}
	var user models.User
	err := q.Where(
		"right(regexp_replace(coalesce(mobile_number,''), '[^0-9]', '', 'g'), 10) = ?",
		d,
	).First(&user).Error
	if err != nil {
		return nil
	}
	return &user
}

func extraAmounts(extra *models.LaborExtra) (rent, food, bonus decimal.Decimal) {
	if extra == nil {
		return decimal.Zero, decimal.Zero, decimal.Zero
	}
	return extra.Rent, extra.Food, extra.Bonus
}

func sourceUserTenant(uid uint) (models.User, uint) {
	var src models.User
	if userDB == nil {
		return src, 1
	}
	_ = userDB.First(&src, uid).Error
	tid := src.TenantID
	if tid == 0 {
		tid = 1
	}
	return src, tid
}

// syncLaborShare offers (or refreshes) a reverse confirmation to the labourer
// if their mobile matches a registered app user. Fail-open: never blocks the
// farmer's own labour save.
func syncLaborShare(sourceUID uint, labor models.Labor, extra *models.LaborExtra) {
	if laborDB == nil || labor.ID == 0 || sourceUID == 0 {
		return
	}
	if normalizeLaborEntryKind(labor.EntryKind) == "tally" ||
		normalizeLaborEntryKind(labor.EntryKind) == "opening" {
		cancelPendingLaborShares(labor.ID)
		return
	}
	mob := ""
	if labor.Mobile != nil {
		mob = strings.TrimSpace(*labor.Mobile)
	}
	if last10Phone(mob) == "" {
		cancelPendingLaborShares(labor.ID)
		return
	}

	src, tid := sourceUserTenant(sourceUID)
	target := findUserByMobileLast10(mob, sourceUID, tid)
	if target == nil || target.ID == 0 || target.ID == sourceUID {
		cancelPendingLaborShares(labor.ID)
		return
	}

	farmerMobile := ""
	if src.MobileNumber != nil {
		farmerMobile = last10Phone(*src.MobileNumber)
	}
	var farmerMobPtr *string
	if farmerMobile != "" {
		farmerMobPtr = &farmerMobile
	}

	display := userDisplayName(src)
	if strings.TrimSpace(display) == "" {
		display = "Farmer"
	}

	rent, food, bonus := extraAmounts(extra)
	snap := models.LaborShare{
		SourceLaborID:   labor.ID,
		SourceUserID:    sourceUID,
		TargetUserID:    target.ID,
		Status:          "pending",
		Name:            display,
		Mobile:          farmerMobPtr,
		Wage:            labor.Wage,
		Hours:           labor.Hours,
		NumberOfLabours: labor.NumberOfLabours,
		Shift:           labor.Shift,
		Category:        labor.Category,
		Gender:          labor.Gender,
		WorkType:        labor.WorkType,
		Location:        labor.Location,
		Narration:       labor.Narration,
		Date:            labor.Date,
		EntryKind:       reverseLaborKind(labor.EntryKind),
		Rent:            rent,
		Food:            food,
		Bonus:           bonus,
		RecordedAs:      strings.TrimSpace(labor.Name),
	}

	var existing models.LaborShare
	err := laborDB.Where("source_labor_id = ?", labor.ID).First(&existing).Error
	if err != nil {
		if err == gorm.ErrRecordNotFound {
			_ = laborDB.Create(&snap).Error
		}
		return
	}
	if existing.Status != "pending" {
		return
	}
	snap.ID = existing.ID
	snap.CreatedAt = existing.CreatedAt
	_ = laborDB.Save(&snap).Error
}

func cancelPendingLaborShares(laborID uint) {
	if laborDB == nil || laborID == 0 {
		return
	}
	_ = laborDB.Where("source_labor_id = ? AND status = ?", laborID, "pending").
		Delete(&models.LaborShare{}).Error
}

func ListLaborShares(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	status := strings.ToLower(strings.TrimSpace(c.Query("status")))
	if status == "" {
		status = "pending"
	}
	if status != "pending" && status != "accepted" && status != "rejected" && status != "all" {
		return c.Status(400).JSON(fiber.Map{"error": "status must be pending, accepted, rejected, or all"})
	}

	q := laborDB.Model(&models.LaborShare{}).Where("target_user_id = ?", uid)
	if status != "all" {
		q = q.Where("status = ?", status)
	}
	var rows []models.LaborShare
	if err := q.Order("date DESC, id DESC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": rows, "total": len(rows)})
}

func CountPendingLaborShares(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var n int64
	if err := laborDB.Model(&models.LaborShare{}).
		Where("target_user_id = ? AND status = ?", uid, "pending").
		Count(&n).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"pending": n})
}

func AcceptLaborShare(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var share models.LaborShare
	if err := laborDB.Where("id = ? AND target_user_id = ?", c.Params("id"), uid).
		First(&share).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Confirmation not found"})
	}
	if share.Status == "accepted" && share.LaborWorkID != nil {
		var existing models.LaborWorkEntry
		if err := laborWorkDB.First(&existing, *share.LaborWorkID).Error; err == nil {
			return c.JSON(fiber.Map{"message": "Already confirmed", "data": share, "work": existing})
		}
	}
	if share.Status != "pending" {
		return c.Status(400).JSON(fiber.Map{"error": "This entry is no longer pending"})
	}

	narr := strings.TrimSpace(share.Narration)
	if extraNote := extrasNarration(share.Rent, share.Food, share.Bonus); extraNote != "" {
		if narr == "" {
			narr = extraNote
		} else {
			narr = narr + " | " + extraNote
		}
	}

	work := models.LaborWorkEntry{
		UserID:          uid,
		Name:            share.Name,
		Wage:            share.Wage,
		Hours:           share.Hours,
		NumberOfLabours: share.NumberOfLabours,
		Shift:           share.Shift,
		Category:        share.Category,
		Gender:          share.Gender,
		WorkType:        share.WorkType,
		Location:        share.Location,
		Narration:       narr,
		Date:            share.Date,
		Mobile:          share.Mobile,
		EntryKind:       share.EntryKind,
	}
	if work.NumberOfLabours < 1 {
		work.NumberOfLabours = 1
	}

	tx := laborDB.Begin()
	if tx.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": tx.Error.Error()})
	}
	workDB := tx
	if laborWorkDB != nil && laborWorkDB != laborDB {
		workDB = laborWorkDB
	}
	if err := workDB.Create(&work).Error; err != nil {
		tx.Rollback()
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	wid := work.ID
	share.LaborWorkID = &wid
	share.Status = "accepted"
	if err := tx.Save(&share).Error; err != nil {
		tx.Rollback()
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if err := tx.Commit().Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "Entry confirmed", "data": share, "work": work})
}

func extrasNarration(rent, food, bonus decimal.Decimal) string {
	var parts []string
	if rent.IsPositive() {
		parts = append(parts, "Rent "+rent.StringFixed(2))
	}
	if food.IsPositive() {
		parts = append(parts, "Food "+food.StringFixed(2))
	}
	if bonus.IsPositive() {
		parts = append(parts, "Bonus "+bonus.StringFixed(2))
	}
	return strings.Join(parts, " · ")
}

func RejectLaborShare(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	var share models.LaborShare
	if err := laborDB.Where("id = ? AND target_user_id = ?", c.Params("id"), uid).
		First(&share).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "Confirmation not found"})
	}
	if share.Status != "pending" {
		return c.Status(400).JSON(fiber.Map{"error": "This entry is no longer pending"})
	}
	share.Status = "rejected"
	if err := laborDB.Save(&share).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"message": "Entry rejected", "data": share})
}
