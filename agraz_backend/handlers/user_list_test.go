package handler

import (
	"encoding/json"
	"fmt"
	"io"
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

func setupUserListApp(t *testing.T) *fiber.App {
	t.Helper()
	dsn := fmt.Sprintf("file:%s?mode=memory&cache=shared",
		strings.ReplaceAll(t.Name(), "/", "_"))
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&models.User{}); err != nil {
		t.Fatal(err)
	}
	SetUserDB(db)

	app := fiber.New()
	app.Use(func(c *fiber.Ctx) error {
		c.Locals(middleware.CtxTenantID, uint(1))
		return c.Next()
	})
	app.Get("/users", GetUsers)
	return app
}

func TestGetUsersPaginationReturnsAllPages(t *testing.T) {
	app := setupUserListApp(t)
	for i := 1; i <= 25; i++ {
		u := models.User{
			TenantID:  1,
			Firstname: fmt.Sprintf("User%d", i),
			Lastname:  "Test",
			Email:     fmt.Sprintf("user%d@example.com", i),
			Password:  "x",
			Active:    true,
			Approved:  true,
		}
		if err := userDB.Create(&u).Error; err != nil {
			t.Fatalf("seed user %d: %v", i, err)
		}
	}

	getPage := func(page, limit int) (int, map[string]any) {
		req := httptest.NewRequest("GET", fmt.Sprintf("/users?page=%d&limit=%d", page, limit), nil)
		resp, err := app.Test(req, 5000)
		if err != nil {
			t.Fatal(err)
		}
		defer resp.Body.Close()
		raw, _ := io.ReadAll(resp.Body)
		out := map[string]any{}
		if err := json.Unmarshal(raw, &out); err != nil {
			t.Fatalf("json: %v body=%s", err, raw)
		}
		return resp.StatusCode, out
	}

	status, body := getPage(1, 10)
	if status != 200 {
		t.Fatalf("page 1 status %d body=%v", status, body)
	}
	if int(body["total"].(float64)) != 25 {
		t.Fatalf("total=%v want 25", body["total"])
	}
	if int(body["total_pages"].(float64)) != 3 {
		t.Fatalf("total_pages=%v want 3", body["total_pages"])
	}
	rows, _ := body["data"].([]any)
	if len(rows) != 10 {
		t.Fatalf("page 1 len=%d want 10", len(rows))
	}

	_, body = getPage(2, 10)
	rows, _ = body["data"].([]any)
	if len(rows) != 10 {
		t.Fatalf("page 2 len=%d want 10", len(rows))
	}

	_, body = getPage(3, 10)
	rows, _ = body["data"].([]any)
	if len(rows) != 5 {
		t.Fatalf("page 3 len=%d want 5", len(rows))
	}

	seen := map[string]bool{}
	for p := 1; p <= 3; p++ {
		_, body = getPage(p, 10)
		for _, row := range body["data"].([]any) {
			m := row.(map[string]any)
			seen[m["email"].(string)] = true
		}
	}
	if len(seen) != 25 {
		t.Fatalf("unique emails across pages=%d want 25", len(seen))
	}
}
