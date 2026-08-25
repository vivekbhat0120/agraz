package seeds

import (
	"fmt"
	"log"

	"erp.local/backend/initializers"
	"erp.local/backend/models"
)

// SeedAppContents upserts CMS text for labour and income/expense menus.
func SeedAppContents() {
	rows := []models.AppContent{
		{
			MenuKey:  "labour",
			Title:    "Labour Management",
			Body:     "Record daily wages or contract work as payable. Use Payment mode to settle dues. Paid amounts post to Income & Expense under Farming Expense → Labour. Opening balance sets the starting payable for a labourer.",
			Locale:   "en",
			IsActive: true,
		},
		{
			MenuKey:  "income_expense",
			Title:    "Income & Expenditure",
			Body:     "Track farm and living income/expenses. You can select multiple sub-categories; the amount is split into whole rupees (remainder goes to the first). Reports show overall overview with category and subcategory charts.",
			Locale:   "en",
			IsActive: true,
		},
		{
			MenuKey:  "dairy",
			Title:    "Dairy",
			Body:     "Track milk given to a dairy and milk you bought. Receivable is money the dairy still owes you. Entries recorded by a dairy owner against your mobile number appear here automatically.",
			Locale:   "en",
			IsActive: true,
		},
		{
			MenuKey:  "dairy_owner",
			Title:    "Dairy Owner",
			Body:     "Record customers and daily milk collection. When a customer uses the same mobile number in the AgRaz app, the milk you enter shows on their Dairy page — they do not re-enter it.",
			Locale:   "en",
			IsActive: true,
		},
		{
			MenuKey:  "documents",
			Title:    "Documents",
			Body:     "Keep personal papers such as Aadhaar and PAN. Create a folder for each family member, then add documents with photos. You can also upload a document without a folder.",
			Locale:   "en",
			IsActive: true,
		},
		{
			MenuKey:  "feedback",
			Title:    "Feedback",
			Body:     "Share suggestions or issues. You can view your own feedback and all community feedback. Verified items are marked by admin.",
			Locale:   "en",
			IsActive: true,
		},
	}

	for _, row := range rows {
		var existing models.AppContent
		err := initializers.DB.Where("menu_key = ?", row.MenuKey).First(&existing).Error
		if err != nil {
			if err := initializers.DB.Create(&row).Error; err != nil {
				log.Printf("app content seed %s: %v", row.MenuKey, err)
			} else {
				fmt.Printf("Seeded AppContent: %s\n", row.MenuKey)
			}
			continue
		}
		initializers.DB.Model(&existing).Updates(map[string]interface{}{
			"title":     row.Title,
			"body":      row.Body,
			"locale":    row.Locale,
			"is_active": row.IsActive,
		})
	}
}

// SeedToolsMenus adds Feedback, Entry Analytics, Organizations, and App Contents to admin menus.
func SeedToolsMenus() {
	menus := []models.Menu{
		{MenuName: "Tools", URL: "/tools", Icon: "Wrench", SortOrder: 8, IsActive: true, MenuType: "main", Children: []models.Menu{
			{MenuName: "Feedback", URL: "/feedback", Icon: "MessageSquare", SortOrder: 1, IsActive: true, MenuType: "main"},
			{MenuName: "Entry Analytics", URL: "/entry-analytics", Icon: "Activity", SortOrder: 2, IsActive: true, MenuType: "main"},
			{MenuName: "Organizations", URL: "/organizations", Icon: "Building2", SortOrder: 3, IsActive: true, MenuType: "main"},
			{MenuName: "App Contents", URL: "/app-contents", Icon: "FileText", SortOrder: 4, IsActive: true, MenuType: "main"},
			{MenuName: "Dairy", URL: "/dairy", Icon: "Milk", SortOrder: 5, IsActive: true, MenuType: "main"},
			{MenuName: "Documents", URL: "/documents", Icon: "FolderOpen", SortOrder: 6, IsActive: true, MenuType: "main"},
			{MenuName: "Achievers Lobby", URL: "/achievers-lobby", Icon: "Trophy", SortOrder: 8, IsActive: true, MenuType: "main"},
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
			ensureToolsChild(existing.ID, "Organizations", "/organizations", "Building2", 3)
			ensureToolsChild(existing.ID, "Dairy", "/dairy", "Milk", 5)
			ensureToolsChild(existing.ID, "Documents", "/documents", "FolderOpen", 6)
			ensureToolsChild(existing.ID, "Achievers Lobby", "/achievers-lobby", "Trophy", 8)
		}
	}
}

func ensureToolsChild(parentID uint, name, url, icon string, sort int) {
	var existing models.Menu
	if err := initializers.DB.Where("menu_name = ? AND url = ?", name, url).First(&existing).Error; err != nil {
		child := models.Menu{
			MenuName:  name,
			URL:       url,
			Icon:      icon,
			SortOrder: sort,
			IsActive:  true,
			MenuType:  "main",
			ParentID:  &parentID,
		}
		if err := initializers.DB.Create(&child).Error; err != nil {
			log.Printf("Failed to seed %s menu: %v", name, err)
		} else {
			fmt.Printf("Seeded Menu: %s\n", name)
		}
	}
}
