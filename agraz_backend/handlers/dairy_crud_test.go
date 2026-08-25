package handler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"erp.local/backend/middleware"
	"erp.local/backend/models"
	"github.com/glebarez/sqlite"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

func setupDairyCRUDApp(t *testing.T, ownerID uint) *fiber.App {
	t.Helper()
	dsn := fmt.Sprintf("file:%s?mode=memory&cache=shared",
		strings.ReplaceAll(t.Name(), "/", "_"))
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&models.DairyEntry{}, &models.DairyCustomer{}); err != nil {
		t.Fatal(err)
	}
	SetDairyDB(db)

	app := fiber.New()
	app.Use(func(c *fiber.Ctx) error {
		c.Locals("user_id", ownerID)
		c.Locals(middleware.CtxOwnerUserID, ownerID)
		return c.Next()
	})
	api := app.Group("/api")
	api.Get("/dairy/summary", GetDairySummary)
	api.Get("/dairy/entries", ListDairyEntries)
	api.Post("/dairy/entries", CreateDairyEntry)
	api.Put("/dairy/entries/:id", UpdateDairyEntry)
	api.Delete("/dairy/entries/:id", DeleteDairyEntry)
	api.Get("/dairy/owner/customers", ListDairyCustomers)
	api.Post("/dairy/owner/customers", CreateDairyCustomer)
	api.Put("/dairy/owner/customers/:id", UpdateDairyCustomer)
	api.Delete("/dairy/owner/customers/:id", DeleteDairyCustomer)
	api.Get("/dairy/owner/summary", GetOwnerDairySummary)
	api.Get("/dairy/owner/entries", ListOwnerDairyEntries)
	api.Post("/dairy/owner/entries", CreateOwnerDairyEntry)
	api.Put("/dairy/owner/entries/:id", UpdateOwnerDairyEntry)
	api.Delete("/dairy/owner/entries/:id", DeleteOwnerDairyEntry)
	return app
}

func dairyReq(t *testing.T, app *fiber.App, method, path string, body any) (int, map[string]any, string) {
	t.Helper()
	var rdr io.Reader
	if body != nil {
		raw, err := json.Marshal(body)
		if err != nil {
			t.Fatal(err)
		}
		rdr = bytes.NewReader(raw)
	}
	req := httptest.NewRequest(method, path, rdr)
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := app.Test(req, 8000)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	out := map[string]any{}
	if len(raw) > 0 {
		_ = json.Unmarshal(raw, &out)
	}
	return resp.StatusCode, out, string(raw)
}

func dairyJSON(t *testing.T, app *fiber.App, method, path string, body any) (int, map[string]any) {
	t.Helper()
	code, out, _ := dairyReq(t, app, method, path, body)
	return code, out
}

func dairyDataID(t *testing.T, body map[string]any) string {
	t.Helper()
	data, _ := body["data"].(map[string]any)
	if data == nil {
		t.Fatalf("missing data: %v", body)
	}
	id := fmt.Sprint(data["id"])
	if id == "" || id == "<nil>" || id == "0" {
		t.Fatalf("missing id: %v", body)
	}
	return id
}

func TestFarmerDairyEntryCRUD(t *testing.T) {
	app := setupDairyCRUDApp(t, 11)

	code, created := dairyJSON(t, app, http.MethodPost, "/api/dairy/entries", map[string]any{
		"kind":            "milk_given",
		"party_name":      " Gowda Dairy ",
		"party_mobile":    "9876543210",
		"date":            "2026-08-22",
		"shift":           "morning",
		"quantity_liters": 12.5,
		"rate_per_liter":  40,
		"narration":       "morning supply",
	})
	if code != 201 {
		t.Fatalf("create status %d body=%v", code, created)
	}
	data, _ := created["data"].(map[string]any)
	id := dairyDataID(t, created)
	if data["party_name"] != "Gowda Dairy" {
		t.Fatalf("name not trimmed: %v", data["party_name"])
	}
	if data["kind"] != "milk_given" || data["shift"] != "morning" {
		t.Fatalf("fields: %v", data)
	}
	if data["editable"] != true {
		t.Fatalf("farmer row should be editable: %v", data)
	}

	code, listed := dairyJSON(t, app, http.MethodGet, "/api/dairy/entries", nil)
	if code != 200 {
		t.Fatalf("list status %d body=%v", code, listed)
	}
	rows, _ := listed["data"].([]any)
	if len(rows) != 1 {
		t.Fatalf("want 1 row, got %v", listed)
	}

	code, summary := dairyJSON(t, app, http.MethodGet, "/api/dairy/summary", nil)
	if code != 200 {
		t.Fatalf("summary status %d body=%v", code, summary)
	}
	if fmt.Sprint(summary["entry_count"]) != "1" {
		t.Fatalf("summary entry_count: %v", summary)
	}

	code, updated := dairyJSON(t, app, http.MethodPut, "/api/dairy/entries/"+id, map[string]any{
		"kind":            "milk_given",
		"party_name":      "Nandini Dairy",
		"party_mobile":    "9876543210",
		"date":            "2026-08-23",
		"shift":           "evening",
		"quantity_liters": 8,
		"rate_per_liter":  42,
		"narration":       "evening supply",
	})
	if code != 200 {
		t.Fatalf("update status %d body=%v", code, updated)
	}
	data, _ = updated["data"].(map[string]any)
	if data["party_name"] != "Nandini Dairy" || data["shift"] != "evening" {
		t.Fatalf("update fields: %v", data)
	}

	code, listed = dairyJSON(t, app, http.MethodGet, "/api/dairy/entries", nil)
	rows, _ = listed["data"].([]any)
	first, _ := rows[0].(map[string]any)
	if code != 200 || first["party_name"] != "Nandini Dairy" {
		t.Fatalf("list not updated: %v", listed)
	}

	code, deleted := dairyJSON(t, app, http.MethodDelete, "/api/dairy/entries/"+id, nil)
	if code != 200 {
		t.Fatalf("delete status %d body=%v", code, deleted)
	}
	code, listed = dairyJSON(t, app, http.MethodGet, "/api/dairy/entries", nil)
	rows, _ = listed["data"].([]any)
	if code != 200 || len(rows) != 0 {
		t.Fatalf("want empty list after delete, got %v", listed)
	}

	code, missing, _ := dairyReq(t, app, http.MethodDelete, "/api/dairy/entries/"+id, nil)
	if code != 404 {
		t.Fatalf("second delete want 404, got %d %v", code, missing)
	}
}

func TestFarmerDairyEntryValidation(t *testing.T) {
	app := setupDairyCRUDApp(t, 12)

	code, body, raw := dairyReq(t, app, http.MethodPost, "/api/dairy/entries", map[string]any{
		"kind":            "milk_given",
		"party_name":      "  ",
		"quantity_liters": 10,
		"rate_per_liter":  40,
	})
	if code != 400 || !strings.Contains(strings.ToLower(raw+fmt.Sprint(body["error"])+fmt.Sprint(body["message"])), "party_name") {
		t.Fatalf("blank name: %d %v %q", code, body, raw)
	}

	code, body, raw = dairyReq(t, app, http.MethodPost, "/api/dairy/entries", map[string]any{
		"kind":            "milk_given",
		"party_name":      "Gowda",
		"quantity_liters": 0,
		"rate_per_liter":  40,
	})
	if code != 400 || !strings.Contains(strings.ToLower(raw+fmt.Sprint(body["error"])+fmt.Sprint(body["message"])), "quantity") {
		t.Fatalf("zero qty: %d %v %q", code, body, raw)
	}

	code, pay := dairyJSON(t, app, http.MethodPost, "/api/dairy/entries", map[string]any{
		"kind":   "payment_received",
		"party_name": "Gowda",
		"date":   "2026-08-22",
		"amount": 500,
	})
	if code != 201 {
		t.Fatalf("payment create %d %v", code, pay)
	}
	data, _ := pay["data"].(map[string]any)
	if data["kind"] != "payment_received" {
		t.Fatalf("payment kind: %v", data)
	}
}

func TestOwnerDairyCustomerAndEntryCRUD(t *testing.T) {
	app := setupDairyCRUDApp(t, 21)

	code, cust := dairyJSON(t, app, http.MethodPost, "/api/dairy/owner/customers", map[string]any{
		"name":         " Ramu ",
		"village":      "Hebbal",
		"default_rate": 38,
	})
	if code != 201 {
		t.Fatalf("customer create %d %v", code, cust)
	}
	cid := dairyDataID(t, cust)
	data, _ := cust["data"].(map[string]any)
	if data["name"] != "Ramu" {
		t.Fatalf("customer name: %v", data["name"])
	}

	code, listed := dairyJSON(t, app, http.MethodGet, "/api/dairy/owner/customers", nil)
	if code != 200 {
		t.Fatalf("customer list %d %v", code, listed)
	}
	crows, _ := listed["data"].([]any)
	if len(crows) != 1 {
		t.Fatalf("want 1 customer, got %v", listed)
	}

	code, cust = dairyJSON(t, app, http.MethodPut, "/api/dairy/owner/customers/"+cid, map[string]any{
		"name":         "Ramu Gowda",
		"village":      "Hebbal",
		"default_rate": 40,
	})
	if code != 200 {
		t.Fatalf("customer update %d %v", code, cust)
	}

	code, created := dairyJSON(t, app, http.MethodPost, "/api/dairy/owner/entries", map[string]any{
		"owner_kind":      "collected",
		"party_name":      "Ramu Gowda",
		"date":            "2026-08-22",
		"shift":           "morning",
		"quantity_liters": 20,
		"rate_per_liter":  40,
		"narration":       "can 1",
	})
	if code != 201 {
		t.Fatalf("owner entry create %d %v", code, created)
	}
	eid := dairyDataID(t, created)
	edata, _ := created["data"].(map[string]any)
	if edata["kind"] != "milk_bought" && edata["owner_kind"] != "collected" {
		t.Fatalf("owner collected mapping: %v", edata)
	}

	code, listed = dairyJSON(t, app, http.MethodGet, "/api/dairy/owner/entries", nil)
	if code != 200 {
		t.Fatalf("owner list %d %v", code, listed)
	}
	erows, _ := listed["data"].([]any)
	if len(erows) != 1 {
		t.Fatalf("want 1 owner entry, got %v", listed)
	}

	code, updated := dairyJSON(t, app, http.MethodPut, "/api/dairy/owner/entries/"+eid, map[string]any{
		"owner_kind":      "collected",
		"party_name":      "Ramu Gowda",
		"date":            "2026-08-22",
		"shift":           "evening",
		"quantity_liters": 18,
		"rate_per_liter":  41,
	})
	if code != 200 {
		t.Fatalf("owner update %d %v", code, updated)
	}

	code, _ = dairyJSON(t, app, http.MethodDelete, "/api/dairy/owner/entries/"+eid, nil)
	if code != 200 {
		t.Fatalf("owner delete %d", code)
	}
	code, listed = dairyJSON(t, app, http.MethodGet, "/api/dairy/owner/entries", nil)
	erows, _ = listed["data"].([]any)
	if code != 200 || len(erows) != 0 {
		t.Fatalf("owner list after delete: %v", listed)
	}

	code, _ = dairyJSON(t, app, http.MethodDelete, "/api/dairy/owner/customers/"+cid, nil)
	if code != 200 {
		t.Fatalf("customer delete %d", code)
	}
	code, listed = dairyJSON(t, app, http.MethodGet, "/api/dairy/owner/customers", nil)
	crows, _ = listed["data"].([]any)
	if code != 200 || len(crows) != 0 {
		t.Fatalf("customer list after delete: %v", listed)
	}
}
