package models

import (
	"time"

	"github.com/shopspring/decimal"
)

// Labor maps to public.labors — daily labour entries from the Agraz mobile app.
// EntryKind: payable (work), payment (settlement), opening (account reset / opening
// balance from that date; negative wage = payment/debit opening), tally (reset to zero).
type Labor struct {
	ID              uint            `gorm:"primaryKey;autoIncrement" json:"id"`
	UserID          uint            `gorm:"not null;index;default:0" json:"user_id"`
	Name            string          `gorm:"type:varchar(255);not null" json:"name"`
	Wage            decimal.Decimal `gorm:"type:numeric(15,2);not null" json:"wage"` // rate or amount
	Hours           decimal.Decimal `gorm:"type:numeric(10,2);not null" json:"hours"` // days/hour (1 for payment/opening)
	NumberOfLabours int             `gorm:"not null;default:1" json:"number_of_labours"`
	Shift           string          `gorm:"type:varchar(50);not null" json:"shift"`
	Category        string          `gorm:"type:varchar(100);not null" json:"category"`
	Gender          string          `gorm:"type:varchar(20);not null;default:''" json:"gender"`
	WorkType        string          `gorm:"type:varchar(50);not null;default:''" json:"work_type"`
	LabourHead      string          `gorm:"type:varchar(255);not null;default:''" json:"labour_head"`
	Location        string          `gorm:"type:varchar(255);not null;default:''" json:"location"`
	Narration       string          `gorm:"type:text;not null;default:''" json:"narration"`
	Date            time.Time       `gorm:"not null" json:"date"`
	Mobile          *string         `gorm:"type:varchar(15)" json:"mobile,omitempty"`
	// EntryKind: payable | payment | opening | tally
	EntryKind string `gorm:"type:varchar(20);not null;default:'payable';index" json:"entry_kind"`
	// Linked income/expense row when payment (or paid portion) posts to I&E.
	IncomeExpenseID *uint `gorm:"index" json:"income_expense_id,omitempty"`
	// Optional rent/food/bonus extras (one row per labour entry).
	Extra     *LaborExtra `gorm:"foreignKey:LaborID" json:"extra,omitempty"`
	CreatedAt time.Time   `json:"created_at"`
	UpdatedAt time.Time   `json:"updated_at"`
}

func (Labor) TableName() string {
	return "labors"
}
