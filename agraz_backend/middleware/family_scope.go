package middleware

import (
	"encoding/json"
	"strings"

	"erp.local/backend/initializers"
	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/datatypes"
)

const (
	CtxOwnerUserID      = "owner_user_id"
	CtxIsSubUser        = "is_sub_user"
	CtxDisabledFeatures = "disabled_features"
)

// FamilyScope attaches the farm owner id (main account) and enforces
// per-sub-member option disables. Must run after Protected().
func FamilyScope() fiber.Handler {
	return func(c *fiber.Ctx) error {
		uid, ok := userIDFromLocals(c)
		if !ok || uid == 0 {
			return c.Next()
		}

		var u models.User
		if err := initializers.DB.Select(
			"id", "parent_user_id", "disabled_features", "active", "approved",
		).First(&u, uid).Error; err != nil {
			return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
				"error":   "User not found",
				"message": "User not found",
			})
		}

		ownerID := uid
		disabled := parseDisabledFeatures(u.DisabledFeatures)
		isSub := false

		if u.ParentUserID != nil && *u.ParentUserID > 0 {
			var parent models.User
			if err := initializers.DB.Select("id", "active", "approved").
				First(&parent, *u.ParentUserID).Error; err != nil {
				return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
					"error":   "Main account is no longer available",
					"message": "Main account is no longer available",
				})
			}
			if !parent.Active || !parent.Approved {
				return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{
					"error":   "Main account is inactive",
					"message": "Main account is inactive",
				})
			}
			ownerID = parent.ID
			isSub = true
		}

		c.Locals(CtxOwnerUserID, ownerID)
		c.Locals(CtxIsSubUser, isSub)
		c.Locals(CtxDisabledFeatures, disabled)

		if isSub {
			if feat := featureForPath(c.Path()); feat != "" && containsString(disabled, feat) {
				return c.Status(fiber.StatusForbidden).JSON(fiber.Map{
					"error":   "This option is disabled for your account",
					"message": "This option is disabled for your account",
					"code":    "feature_disabled",
					"feature": feat,
				})
			}
		}

		return c.Next()
	}
}

func userIDFromLocals(c *fiber.Ctx) (uint, bool) {
	v := c.Locals("user_id")
	if v == nil {
		return 0, false
	}
	switch id := v.(type) {
	case float64:
		return uint(id), true
	case int:
		return uint(id), true
	case uint:
		return id, true
	default:
		return 0, false
	}
}

func parseDisabledFeatures(raw datatypes.JSON) []string {
	if len(raw) == 0 {
		return []string{}
	}
	var keys []string
	if err := json.Unmarshal(raw, &keys); err != nil || keys == nil {
		return []string{}
	}
	out := make([]string, 0, len(keys))
	for _, k := range keys {
		k = strings.TrimSpace(k)
		if k != "" {
			out = append(out, k)
		}
	}
	return out
}

func containsString(list []string, key string) bool {
	for _, v := range list {
		if v == key {
			return true
		}
	}
	return false
}

func featureForPath(path string) string {
	p := strings.TrimPrefix(path, "/api")
	p = strings.TrimPrefix(p, "/")
	switch {
	case strings.HasPrefix(p, "income_expense"):
		return "income_expense"
	case strings.HasPrefix(p, "organizations"), strings.HasPrefix(p, "org_"):
		return "organization"
	case strings.HasPrefix(p, "labors"), strings.HasPrefix(p, "labor_rates"):
		return "labour"
	case strings.HasPrefix(p, "labor_works"), strings.HasPrefix(p, "labor_shares"):
		return "labour_work"
	case strings.HasPrefix(p, "dairy/owner"):
		return "dairy_owner"
	case strings.HasPrefix(p, "dairy"):
		return "dairy"
	case strings.HasPrefix(p, "daily_summary"):
		return "daily_summary"
	case strings.HasPrefix(p, "diary"):
		return "notes"
	case strings.HasPrefix(p, "future_plans"):
		return "future_plans"
	case strings.HasPrefix(p, "land_rtcs"):
		return "rtc"
	case strings.HasPrefix(p, "documents"):
		return "documents"
	case strings.HasPrefix(p, "events"):
		return "event_manage"
	case strings.HasPrefix(p, "feedbacks"):
		return "feedback"
	case strings.HasPrefix(p, "achievers-lobby"):
		return "achievers_lobby"
	case strings.HasPrefix(p, "store/cart"):
		return "buy_sell"
	default:
		return ""
	}
}
