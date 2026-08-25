package handler

import (
	"encoding/json"
	"strconv"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

// GetCurrentUserMenuTree returns the menu tree for the currently logged-in user
// based on their assigned roles and permissions.
func GetCurrentUserMenuTree(c *fiber.Ctx) error {
	// 1. Get User ID from context (set by auth middleware)
	userID, ok := userIDFromCtx(c)
	if !ok || userID == 0 {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "Unauthorized"})
	}

	var currentUser models.User
	if err := userDB.Select("id", "vendor_id", "tenant_id").First(&currentUser, userID).Error; err != nil {
		return c.Status(fiber.StatusUnauthorized).JSON(fiber.Map{"error": "User not found"})
	}

	// 2. Get all Role IDs assigned to the user
	var roleMappings []models.UserRoleMapping
	if err := userDB.Where("user_id = ?", userID).Find(&roleMappings).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to fetch user roles"})
	}

	roleIDs := make([]uint, 0)
	for _, mapping := range roleMappings {
		roleIDs = append(roleIDs, mapping.RoleID)
	}

	// 3. Fetch permissions for all roles and merge them
	finalPermissions := make(map[string]map[string]bool)
	isSuperAdmin := false

	if len(roleIDs) > 0 {
		// Check if user is Super Admin
		var roles []models.Role
		// Assuming userDB or rolemanageDB points to the same DB instance
		if err := userDB.Where("id IN ?", roleIDs).Find(&roles).Error; err == nil {
			for _, r := range roles {
				if r.RoleName == "Super Admin" || r.RoleName == "Admin" {
					isSuperAdmin = true
					break
				}
			}
		}

		if !isSuperAdmin {
			var roleManagements []models.RoleManagement
			// rolemanageDB is private to handler package, so we can access it
			if err := rolemanageDB.Where("role_id IN ?", roleIDs).Find(&roleManagements).Error; err != nil {
				return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to fetch role permissions"})
			}

			for _, rm := range roleManagements {
				var perms map[string]map[string]bool
				if len(rm.RoleManagementPermissions) > 0 {
					if err := json.Unmarshal(rm.RoleManagementPermissions, &perms); err == nil {
						// Merge permissions
						for menuID, p := range perms {
							if _, exists := finalPermissions[menuID]; !exists {
								finalPermissions[menuID] = make(map[string]bool)
							}
							for action, allowed := range p {
								if allowed {
									finalPermissions[menuID][action] = true
								}
							}
						}
					}
				}
			}
		}
	}

	if currentUser.VendorID != nil && *currentUser.VendorID > 0 && !isSuperAdmin {
		return c.JSON(vendorPortalMenuTree())
	}

	// 4. Fetch all active menus (tree structure)
	var menus []models.Menu
	// menusDB is private to handler package
	if err := menusDB.
		Where("parent_id IS NULL AND is_active = true").
		Preload("Children", func(db *gorm.DB) *gorm.DB {
			return db.Where("is_active = true").Order("sort_order")
		}).
		Order("sort_order").
		Find(&menus).Error; err != nil {
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "Failed to fetch menus"})
	}

	// 5. Annotate and Filter Menus
	// Recursive function to process menu tree
	var processMenu func(m models.Menu) (map[string]interface{}, bool)
	processMenu = func(m models.Menu) (map[string]interface{}, bool) {
		menuIDStr := strconv.FormatUint(uint64(m.ID), 10)

		var perms map[string]bool
		canView := false

		if isSuperAdmin {
			canView = true
			perms = map[string]bool{
				"can_view":   true,
				"can_create": true,
				"can_update": true,
				"can_delete": true,
				"can_all":    true,
			}
		} else {
			// Check permissions
			p, hasPerms := finalPermissions[menuIDStr]
			perms = p

			// Determine valid permissions.
			// If no permissions found, default to NO ACCESS (secure by default)
			// UNLESS functionality requires open access. Assuming we want RBAC:
			if hasPerms {
				if val, ok := perms["can_view"]; ok && val {
					canView = true
				}
			}
		}

		// BUT: If the user is an admin (e.g. role ID 1, usually), maybe bypass?
		// For now, stick to explicit permissions.

		// Special case: If a menu has children that are visible, the parent should likely be visible too?
		// Or strictly follow can_view. Let's follow can_view first, but verify children.

		processedChildren := make([]map[string]interface{}, 0)
		for _, child := range m.Children {
			if childMap, childVisible := processMenu(child); childVisible {
				processedChildren = append(processedChildren, childMap)
			}
		}

		// If I have no view permission AND no visible children, safely hide me.
		// If I have visible children, I should probably be visible as a container?
		// Usually yes.
		if len(processedChildren) > 0 {
			canView = true
		}

		if !canView {
			return nil, false
		}

		// Construct response map
		menuMap := map[string]interface{}{
			"id":          m.ID,
			"menu_name":   m.MenuName,
			"url":         m.URL,
			"icon":        m.Icon,
			"children":    processedChildren,
			"permissions": perms, // Client side can use this to hide/show buttons (Edit/Delete)
		}

		return menuMap, true
	}

	result := make([]map[string]interface{}, 0)
	for _, m := range menus {
		if menuMap, visible := processMenu(m); visible {
			result = append(result, menuMap)
		}
	}

	return c.JSON(result)
}

func vendorPortalMenuTree() []map[string]interface{} {
	perms := map[string]bool{
		"can_view": true, "can_create": true, "can_update": true, "can_delete": false, "can_all": false,
	}
	return []map[string]interface{}{
		{
			"id": 9001, "menu_name": "Dashboard", "url": "/home", "icon": "LayoutDashboard",
			"children": []map[string]interface{}{}, "permissions": perms,
		},
		{
			"id": 9002, "menu_name": "My store", "url": "/marketplace", "icon": "Store",
			"children": []map[string]interface{}{
				{
					"id": 9003, "menu_name": "My products", "url": "/vendor-product-mapping", "icon": "Share2",
					"children": []map[string]interface{}{}, "permissions": perms,
				},
				{
					"id": 9004, "menu_name": "Product catalog", "url": "/ecom-admin?tab=products", "icon": "Package",
					"children": []map[string]interface{}{}, "permissions": perms,
				},
			},
			"permissions": perms,
		},
	}
}
