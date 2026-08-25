package seeds

import (
	"errors"
	"fmt"
	"log"

	"erp.local/backend/initializers"
	"erp.local/backend/models"
	"github.com/shopspring/decimal"
	"gorm.io/datatypes"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

func SeedAll() {
	EnsureDefaultTenant()
	EnsureMarketplaceMode()
	SeedRoles()
	SeedAdminUser()
	SeedMenus()
	SeedToolsMenus()
	SeedAppContents()
	SeedStorefrontBannerMenu()
	SeedGovFacilities()
	SeedMarketReports()
	SeedIncomeExpenses()
	SeedAchieversLobby()
}

func SeedEcomDefaults() {
	// Create a minimal demo catalog so the shopping cart page works immediately.
	// This is intentionally small; you can expand it later via admin/product CRUD.
	const defaultTenant = uint(1)

	// Category (restore soft-deleted row instead of re-inserting; old slug-only unique index blocks duplicates)
	generalSlug := "general"
	var existingCat models.EcomCategory
	err := initializers.DB.Where("slug = ? AND tenant_id = ?", generalSlug, defaultTenant).First(&existingCat).Error
	if errors.Is(err, gorm.ErrRecordNotFound) {
		var softDeleted models.EcomCategory
		errSoft := initializers.DB.Unscoped().Where("slug = ? AND tenant_id = ?", generalSlug, defaultTenant).First(&softDeleted).Error
		if errSoft == nil {
			if err := initializers.DB.Unscoped().Model(&softDeleted).Update("deleted_at", nil).Error; err != nil {
				log.Printf("ecom seed: restore category %s: %v", generalSlug, err)
			}
		} else if errors.Is(errSoft, gorm.ErrRecordNotFound) {
			cat := models.EcomCategory{
				TenantID: defaultTenant,
				Name:     "General",
				Slug:     generalSlug,
				Status:   "active",
			}
			if err := initializers.DB.Create(&cat).Error; err != nil {
				log.Printf("ecom seed: category %s: %v", generalSlug, err)
			}
		} else {
			log.Printf("ecom seed: category lookup %s: %v", generalSlug, errSoft)
		}
	} else if err != nil {
		log.Printf("ecom seed: category lookup %s: %v", generalSlug, err)
	}

	// Color
	var red models.EcomColor
	if err := initializers.DB.Where("hex_code = ? AND tenant_id = ?", "#ef4444", defaultTenant).First(&red).Error; err != nil {
		c := models.EcomColor{TenantID: defaultTenant, Name: "Red", HexCode: "#ef4444", Status: "active"}
		_ = initializers.DB.Create(&c).Error
	}

	// Product
	var prod models.EcomProduct
	if err := initializers.DB.Where("slug = ? AND tenant_id = ?", "demo-product", defaultTenant).First(&prod).Error; err != nil {
		p := models.EcomProduct{
			TenantID:    defaultTenant,
			Name:        "Demo Product",
			Description: nil,
			Slug:        "demo-product",
			Status:      "active",
			IsFeatured:  false,
			Price:       decimal.NewFromInt(199),
			CompareAtPrice: nil,
			Cost:        decimal.NewFromInt(80),
			Quantity:    0,
			LowStockThreshold: 0,
			SKU:          nil,
			Barcode:     nil,
			Weight:      decimal.NewFromInt(0),
			Dimensions:  datatypes.JSON([]byte("[]")),
			SEOCodeTitle: nil,
			SEODescription: nil,
		}
		_ = initializers.DB.Create(&p).Error
	}

	// Variant
	var color models.EcomColor
	_ = initializers.DB.Where("hex_code = ? AND tenant_id = ?", "#ef4444", defaultTenant).First(&color).Error
	var product models.EcomProduct
	_ = initializers.DB.Where("slug = ? AND tenant_id = ?", "demo-product", defaultTenant).First(&product).Error

	// Ensure at least one in-stock variant exists.
	var variant models.EcomVariant
	variantSKU := "DEMO-RED-001"
	err = initializers.DB.Where("sku = ?", variantSKU).First(&variant).Error
	if err != nil {
		v := models.EcomVariant{
			ProductID: product.ID,
			ColorID:   color.ID,
			SKU:        variantSKU,
			Barcode:    nil,
			Price:      decimal.NewFromInt(199),
			CompareAtPrice: nil,
			Quantity:  50,
			ImageURL:   nil,
			Status:     "active",
		}
		_ = initializers.DB.Create(&v).Error
	}
}

func SeedMenus() {
	menus := []models.Menu{
		{MenuName: "Dashboard", URL: "/home", Icon: "LayoutDashboard", SortOrder: 1, IsActive: true, MenuType: "main"},

		{MenuName: "Store & Catalog", URL: "/ecom-admin", Icon: "Store", SortOrder: 2, IsActive: true, MenuType: "main", Children: []models.Menu{
			{MenuName: "Catalog (products)", URL: "/ecom-admin?tab=products", Icon: "Package", SortOrder: 1, IsActive: true, MenuType: "main"},
			{MenuName: "Categories", URL: "/ecom-admin?tab=categories", Icon: "Tags", SortOrder: 2, IsActive: true, MenuType: "main"},
			{MenuName: "Sub-categories", URL: "/ecom-admin?tab=sub-categories", Icon: "Layers", SortOrder: 3, IsActive: true, MenuType: "main"},
			{MenuName: "Colors", URL: "/ecom-admin?tab=colors", Icon: "Palette", SortOrder: 4, IsActive: true, MenuType: "main"},
		}},

		{MenuName: "Marketplace", URL: "/marketplace", Icon: "Share2", SortOrder: 3, IsActive: true, MenuType: "main", Children: []models.Menu{
			{MenuName: "Vendor details", URL: "/vendor-details", Icon: "Store", SortOrder: 1, IsActive: true, MenuType: "main"},
			{MenuName: "Vendor & product mapping", URL: "/vendor-product-mapping", Icon: "Share2", SortOrder: 2, IsActive: true, MenuType: "main"},
			{MenuName: "Vendor & user mapping", URL: "/vendor-user-mapping", Icon: "Users", SortOrder: 3, IsActive: true, MenuType: "main"},
		}},

		// User & Role Management (Admin)
		{MenuName: "User & Roles", URL: "/admin-master", Icon: "ShieldAlert", SortOrder: 4, IsActive: true, MenuType: "main", Children: []models.Menu{
			{MenuName: "User List", URL: "/users", Icon: "Users", SortOrder: 1, IsActive: true, MenuType: "main"},
			{MenuName: "Role Creation", URL: "/rolecreation", Icon: "ShieldPlus", SortOrder: 2, IsActive: true, MenuType: "main"},
			{MenuName: "Existing Roles", URL: "/existingroles", Icon: "Shield", SortOrder: 3, IsActive: true, MenuType: "main"},
			{MenuName: "Role Permissions", URL: "/rolemanagement", Icon: "Lock", SortOrder: 4, IsActive: true, MenuType: "main"},
			{MenuName: "User-Role Map", URL: "/usermanagement", Icon: "Link", SortOrder: 5, IsActive: true, MenuType: "main"},
			{MenuName: "Menu Creation", URL: "/menucreation", Icon: "Menu", SortOrder: 6, IsActive: true, MenuType: "main"},
			{MenuName: "Existing Menus", URL: "/existingmenus", Icon: "List", SortOrder: 7, IsActive: true, MenuType: "main"},
			{MenuName: "Audit Logs", URL: "/auditlogs", Icon: "FileClock", SortOrder: 8, IsActive: true, MenuType: "main"},
		}},
	}

	for _, m := range menus {
		var existing models.Menu
		if err := initializers.DB.Where("menu_name = ? AND url = ?", m.MenuName, m.URL).First(&existing).Error; err != nil {
			if err := initializers.DB.Create(&m).Error; err != nil {
				log.Printf("Failed to seed menu %s: %v", m.MenuName, err)
			} else {
				fmt.Printf("Seeded Menu: %s\n", m.MenuName)
			}
		} else {
			// Update existing to ensure correct MenuType, order, and activity
			initializers.DB.Model(&existing).Updates(models.Menu{
				MenuType:  m.MenuType,
				IsActive:  m.IsActive,
				Icon:      m.Icon,
				SortOrder: m.SortOrder,
			})
		}
	}
}

func SeedRoles() {
	roles := []models.Role{
		{RoleName: "Super Admin", Description: "Has full access to the system"},
		{RoleName: "Admin", Description: "Administrator"},
		{RoleName: "User", Description: "Standard User"},
	}

	for _, r := range roles {
		var count int64
		initializers.DB.Model(&models.Role{}).Where("role_name = ?", r.RoleName).Count(&count)
		if count == 0 {
			if err := initializers.DB.Create(&r).Error; err != nil {
				log.Printf("Failed to seed role %s: %v", r.RoleName, err)
			} else {
				fmt.Printf("Seeded Role: %s\n", r.RoleName)
			}
		}
	}
}

func SeedAdminUser() {
	var count int64
	initializers.DB.Model(&models.User{}).Count(&count)
	if count > 0 {
		return // Users exist, skip
	}

	// Create Super Admin User
	hash, _ := bcrypt.GenerateFromPassword([]byte("admin123"), bcrypt.DefaultCost)

	adminMobile := "9999999999"
	admin := models.User{
		TenantID:      1,
		Firstname:     "System",
		Lastname:      "Admin",
		Email:         "admin@admin.com",
		Password:      string(hash),
		PlainPassword: "admin123",
		Active:        true,
		Approved:      true,
		Usercode:      stringPtr("ADM001"),
		MobileNumber:  &adminMobile,
	}

	if err := initializers.DB.Create(&admin).Error; err != nil {
		log.Printf("Failed to create admin user: %v", err)
		return
	}
	fmt.Printf("Seeded Super Admin User: admin@admin.com / admin123\n")

	// Assign Super Admin Role
	var role models.Role
	if err := initializers.DB.Where("role_name = ?", "Super Admin").First(&role).Error; err == nil {
		mapping := models.UserRoleMapping{
			UserID: admin.ID,
			RoleID: role.ID,
		}
		if err := initializers.DB.Create(&mapping).Error; err != nil {
			log.Printf("Failed to assign role to admin: %v", err)
		} else {
			fmt.Printf("Assigned Super Admin role to user\n")
		}
	}
}

func stringPtr(s string) *string {
	return &s
}
