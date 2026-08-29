package handler

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"erp.local/backend/middleware"
	"erp.local/backend/models"
	"github.com/glebarez/sqlite"
	"github.com/gofiber/fiber/v2"
	"github.com/shopspring/decimal"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func TestDailySummaryWindowDefaultsToToday(t *testing.T) {
	now := time.Date(2026, 8, 26, 15, 4, 0, 0, time.UTC)
	fromDay, toDay, from, toEx := dailySummaryWindow("", "", now)
	if fromDay.Format("2006-01-02") != "2026-08-26" || toDay.Format("2006-01-02") != "2026-08-26" {
		t.Fatalf("default days %s %s", fromDay, toDay)
	}
	if !from.Equal(fromDay) || !toEx.Equal(fromDay.Add(24*time.Hour)) {
		t.Fatalf("window from=%s toEx=%s", from, toEx)
	}
}

func TestDailySummaryWindowSwapsIfToBeforeFrom(t *testing.T) {
	now := time.Date(2026, 8, 26, 0, 0, 0, 0, time.UTC)
	fromDay, toDay, _, _ := dailySummaryWindow("2026-08-28", "2026-08-20", now)
	if fromDay.Format("2006-01-02") != "2026-08-20" || toDay.Format("2006-01-02") != "2026-08-28" {
		t.Fatalf("swapped days %s %s", fromDay, toDay)
	}
}

func setupDailySummaryApp(t *testing.T, ownerID uint, disabled []string) *fiber.App {
	t.Helper()
	db, err := gorm.Open(sqlite.Open("file:daily-summary-"+t.Name()+"?mode=memory&cache=shared"), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(
		&models.IncomeExpense{},
		&models.Labor{},
		&models.LaborExtra{},
		&models.DiaryEntry{},
	); err != nil {
		t.Fatal(err)
	}
	SetIncomeExpenseDB(db)
	SetLaborDB(db)
	SetDiaryDB(db)
	organizationDB = nil
	laborWorkDB = nil
	dairyDB = nil
	futurePlanDB = nil
	eventDB = nil
	landRtcDB = nil
	documentDB = nil
	userDB = nil

	app := fiber.New()
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("user_id", ownerID)
		c.Locals(middleware.CtxOwnerUserID, ownerID)
		c.Locals(middleware.CtxDisabledFeatures, disabled)
		return c.Next()
	})
	app.Get("/api/daily_summary", GetDailySummary)
	return app
}

func TestGetDailySummaryAggregatesRange(t *testing.T) {
	const uid uint = 42
	app := setupDailySummaryApp(t, uid, nil)
	day := time.Date(2026, 8, 26, 8, 0, 0, 0, time.UTC)
	outside := day.AddDate(0, 0, -2)

	if err := incomeExpenseDB.Create(&models.IncomeExpense{
		UserID: uid, Type: "Income", Category: "Crop", SubCategory: "Sale",
		Amount: decimal.NewFromInt(1000), Mobile: "9876543210", Date: day,
		Name: "Buyer", TransactionMode: "Cash",
	}).Error; err != nil {
		t.Fatal(err)
	}
	if err := incomeExpenseDB.Create(&models.IncomeExpense{
		UserID: uid, Type: "Expense", Category: "Seeds", SubCategory: "Paddy",
		Amount: decimal.NewFromInt(250), Mobile: "9876543210", Date: day,
		Name: "Shop", TransactionMode: "Cash",
	}).Error; err != nil {
		t.Fatal(err)
	}
	if err := incomeExpenseDB.Create(&models.IncomeExpense{
		UserID: uid, Type: "Expense", Category: "Old", SubCategory: "Skip",
		Amount: decimal.NewFromInt(99), Mobile: "9876543210", Date: outside,
		Name: "Old", TransactionMode: "Cash",
	}).Error; err != nil {
		t.Fatal(err)
	}
	if err := incomeExpenseDB.Create(&models.IncomeExpense{
		UserID: 99, Type: "Income", Category: "Other", SubCategory: "User",
		Amount: decimal.NewFromInt(5000), Mobile: "111", Date: day,
		Name: "Other", TransactionMode: "Cash",
	}).Error; err != nil {
		t.Fatal(err)
	}
	if err := laborDB.Create(&models.Labor{
		UserID: uid, Name: "Ramu", Wage: decimal.NewFromInt(400),
		Hours: decimal.NewFromInt(1), Shift: "fullday", Category: "Plucking",
		Date: day, EntryKind: "payable",
	}).Error; err != nil {
		t.Fatal(err)
	}

	req := httptest.NewRequest(http.MethodGet, "/api/daily_summary?from=2026-08-26&to=2026-08-26", nil)
	resp, err := app.Test(req, 5000)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 200 {
		t.Fatalf("status %d body %s", resp.StatusCode, raw)
	}
	var body map[string]any
	if err := json.Unmarshal(raw, &body); err != nil {
		t.Fatal(err)
	}
	if body["from"] != "2026-08-26" || body["to"] != "2026-08-26" {
		t.Fatalf("range %v %v", body["from"], body["to"])
	}
	if int(body["entry_count"].(float64)) != 3 {
		t.Fatalf("entry_count=%v body=%s", body["entry_count"], raw)
	}
	if body["opening_balance"].(float64) != -99 {
		t.Fatalf("opening_balance=%v want -99", body["opening_balance"])
	}
	if body["credit"].(float64) != 1000 {
		t.Fatalf("credit=%v want 1000", body["credit"])
	}
	if body["debit"].(float64) != 650 {
		t.Fatalf("debit=%v want 650 (250 I&E + 400 labour)", body["debit"])
	}
	if body["closing_balance"].(float64) != 251 {
		t.Fatalf("closing_balance=%v want 251", body["closing_balance"])
	}
}

func TestGetDailySummaryHonoursDisabledFeature(t *testing.T) {
	const uid uint = 7
	app := setupDailySummaryApp(t, uid, []string{"labour"})
	day := time.Date(2026, 8, 26, 0, 0, 0, 0, time.UTC)
	if err := laborDB.Create(&models.Labor{
		UserID: uid, Name: "Ramu", Wage: decimal.NewFromInt(400),
		Hours: decimal.NewFromInt(1), Shift: "fullday", Category: "Plucking",
		Date: day, EntryKind: "payable",
	}).Error; err != nil {
		t.Fatal(err)
	}
	if err := incomeExpenseDB.Create(&models.IncomeExpense{
		UserID: uid, Type: "Income", Category: "Crop", SubCategory: "Sale",
		Amount: decimal.NewFromInt(10), Mobile: "1", Date: day,
		Name: "A", TransactionMode: "Cash",
	}).Error; err != nil {
		t.Fatal(err)
	}

	req := httptest.NewRequest(http.MethodGet, "/api/daily_summary?from=2026-08-26&to=2026-08-26", nil)
	resp, err := app.Test(req, 5000)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	var body map[string]any
	if err := json.Unmarshal(raw, &body); err != nil {
		t.Fatal(err)
	}
	if int(body["entry_count"].(float64)) != 1 {
		t.Fatalf("expected only I&E, got %v %s", body["entry_count"], raw)
	}
}
