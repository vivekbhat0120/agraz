package seeds

import (
	"fmt"
	"log"

	"erp.local/backend/initializers"
	"erp.local/backend/models"
)

func SeedAchieversLobby() {
	type cat struct {
		kind, name, nameKn string
		sort               int
	}
	rows := []cat{
		{"achiever", "Agriculture", "ಕೃಷಿ", 1},
		{"achiever", "Dairy", "ಡೈರಿ", 2},
		{"achiever", "Education", "ಶಿಕ್ಷಣ", 3},
		{"achiever", "Community", "ಸಮುದಾಯ", 4},
		{"achiever", "Sports", "ಕ್ರೀಡೆ", 5},
		{"achiever", "Entrepreneurship", "ಉದ್ಯಮ", 6},
		{"achiever", "Other", "ಇತರೆ", 7},
		{"innovation", "Farming Method", "ಕೃಷಿ ವಿಧಾನ", 1},
		{"innovation", "Machinery", "ಯಂತ್ರೋಪಕರಣ", 2},
		{"innovation", "Processing", "ಸಂಸ್ಕರಣೆ", 3},
		{"innovation", "Irrigation", "ನೀರಾವರಿ", 4},
		{"innovation", "Organic", "ಸಾವಯವ", 5},
		{"innovation", "Digital", "ಡಿಜಿಟಲ್", 6},
		{"innovation", "Other", "ಇತರೆ", 7},
	}
	for _, r := range rows {
		var existing models.AchieversLobbyCategory
		err := initializers.DB.Where(
			"tenant_id = ? AND kind = ? AND name = ?", 1, r.kind, r.name,
		).First(&existing).Error
		if err == nil {
			continue
		}
		row := models.AchieversLobbyCategory{
			TenantID:  1,
			Kind:      r.kind,
			Name:      r.name,
			NameKn:    r.nameKn,
			SortOrder: r.sort,
			Status:    "active",
		}
		if err := initializers.DB.Create(&row).Error; err != nil {
			log.Printf("achievers lobby category seed %s/%s: %v", r.kind, r.name, err)
		} else {
			fmt.Printf("Seeded AchieversLobbyCategory: %s / %s\n", r.kind, r.name)
		}
	}
}
