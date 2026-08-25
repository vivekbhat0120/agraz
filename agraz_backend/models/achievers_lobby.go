package models

import "time"

const (
	LobbyKindAchiever    = "achiever"
	LobbyKindInnovation  = "innovation"
	LobbyStatusPending   = "pending"
	LobbyStatusActive    = "active"
	LobbyStatusRejected  = "rejected"
	LobbyCategoryBoth    = "both"
)

// AchieversLobbyCategory is a filter used on Achievers / Innovations tabs.
type AchieversLobbyCategory struct {
	ID        uint      `gorm:"primaryKey;autoIncrement" json:"id"`
	TenantID  uint      `gorm:"not null;default:1;index" json:"tenant_id"`
	Kind      string    `gorm:"type:varchar(20);not null;index" json:"kind"` // achiever | innovation | both
	Name      string    `gorm:"type:varchar(120);not null" json:"name"`
	NameKn    string    `gorm:"type:varchar(120);not null;default:''" json:"name_kn"`
	SortOrder int       `gorm:"not null;default:0" json:"sort_order"`
	Status    string    `gorm:"type:varchar(20);not null;default:active;index" json:"status"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

func (AchieversLobbyCategory) TableName() string { return "achievers_lobby_categories" }

// AchieversLobbyItem is a user- or admin-submitted video for Achievers Lobby.
type AchieversLobbyItem struct {
	ID          uint       `gorm:"primaryKey;autoIncrement" json:"id"`
	TenantID    uint       `gorm:"not null;default:1;index" json:"tenant_id"`
	Kind        string     `gorm:"type:varchar(20);not null;index" json:"kind"` // achiever | innovation
	Status      string     `gorm:"type:varchar(20);not null;default:pending;index" json:"status"`
	Name        string     `gorm:"type:varchar(255);not null" json:"name"`
	Mobile      string     `gorm:"type:varchar(20);not null;default:''" json:"mobile"`
	Category    string     `gorm:"type:varchar(120);not null;index" json:"category"`
	Address     string     `gorm:"type:varchar(500);not null;default:''" json:"address"`
	Title       string     `gorm:"type:varchar(255);not null;default:''" json:"title"`
	Description string     `gorm:"type:text;not null;default:''" json:"description"`
	VideoURL    string     `gorm:"type:varchar(1024);not null" json:"video_url"`
	SubmittedBy *uint      `gorm:"index" json:"submitted_by,omitempty"`
	PublishedAt *time.Time `json:"published_at,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
	UpdatedAt   time.Time  `json:"updated_at"`
}

func (AchieversLobbyItem) TableName() string { return "achievers_lobby_items" }
