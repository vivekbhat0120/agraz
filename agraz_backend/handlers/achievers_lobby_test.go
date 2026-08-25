package handler

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
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

func setupLobbyCRUDApp(t *testing.T) *fiber.App {
	t.Helper()
	dsn := fmt.Sprintf("file:%s?mode=memory&cache=shared",
		strings.ReplaceAll(t.Name(), "/", "_"))
	db, err := gorm.Open(sqlite.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent),
	})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&models.AchieversLobbyItem{}, &models.AchieversLobbyCategory{}); err != nil {
		t.Fatal(err)
	}
	SetAchieversLobbyDB(db)

	app := fiber.New(fiber.Config{BodyLimit: 8 << 20})
	app.Use(func(c *fiber.Ctx) error {
		c.Locals(middleware.CtxTenantID, uint(1))
		return c.Next()
	})
	api := app.Group("/api")
	api.Get("/achievers-lobby/latest", GetLatestAchieversLobbyPublic)
	api.Get("/achievers-lobby/categories", ListAchieversLobbyCategoriesPublic)
	api.Get("/achievers-lobby", ListAchieversLobbyPublic)
	api.Get("/achievers-lobby/:id", GetAchieversLobbyPublic)
	api.Post("/achievers-lobby/upload", UploadAchieversLobbyVideoPublic)
	api.Post("/achievers-lobby/submit", SubmitAchieversLobbyPublic)

	api.Get("/admin/achievers-lobby/categories", AdminListLobbyCategories)
	api.Post("/admin/achievers-lobby/categories", AdminCreateLobbyCategory)
	api.Put("/admin/achievers-lobby/categories/:id", AdminUpdateLobbyCategory)
	api.Delete("/admin/achievers-lobby/categories/:id", AdminDeleteLobbyCategory)
	api.Post("/admin/achievers-lobby/upload", AdminUploadAchieversLobbyVideo)
	api.Get("/admin/achievers-lobby", AdminListAchieversLobby)
	api.Get("/admin/achievers-lobby/:id", AdminGetAchieversLobby)
	api.Post("/admin/achievers-lobby", AdminCreateAchieversLobby)
	api.Put("/admin/achievers-lobby/:id", AdminUpdateAchieversLobby)
	api.Patch("/admin/achievers-lobby/:id/status", AdminSetAchieversLobbyStatus)
	api.Delete("/admin/achievers-lobby/:id", AdminDeleteAchieversLobby)
	return app
}

func lobbyReq(t *testing.T, app *fiber.App, method, path string, body any) (int, map[string]any, string) {
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

func lobbyJSON(t *testing.T, app *fiber.App, method, path string, body any) (int, map[string]any) {
	t.Helper()
	code, out, _ := lobbyReq(t, app, method, path, body)
	return code, out
}

func lobbyData(t *testing.T, body map[string]any) map[string]any {
	t.Helper()
	data, _ := body["data"].(map[string]any)
	if data == nil {
		t.Fatalf("missing data: %v", body)
	}
	return data
}

func lobbyID(t *testing.T, body map[string]any) string {
	t.Helper()
	id := fmt.Sprint(lobbyData(t, body)["id"])
	if id == "" || id == "<nil>" || id == "0" {
		t.Fatalf("missing id: %v", body)
	}
	return id
}

func TestAchieversLobbyPublicSubmitStaysHiddenUntilActive(t *testing.T) {
	app := setupLobbyCRUDApp(t)

	code, created := lobbyJSON(t, app, http.MethodPost, "/api/achievers-lobby/submit", map[string]any{
		"kind":      "achiever",
		"name":      " Ramesh Gowda ",
		"mobile":    "9876543210",
		"category":  "Agriculture",
		"video_url": "/uploads/achievers-lobby/demo.mp4",
		"title":     "Best areca yield",
	})
	if code != 201 {
		t.Fatalf("submit status %d body=%v", code, created)
	}
	data := lobbyData(t, created)
	if data["name"] != "Ramesh Gowda" {
		t.Fatalf("name not trimmed: %v", data["name"])
	}
	if data["status"] != "pending" {
		t.Fatalf("want pending, got %v", data["status"])
	}
	id := lobbyID(t, created)

	code, listed := lobbyJSON(t, app, http.MethodGet, "/api/achievers-lobby?kind=achiever", nil)
	if code != 200 {
		t.Fatalf("public list status %d body=%v", code, listed)
	}
	rows, _ := listed["data"].([]any)
	if len(rows) != 0 {
		t.Fatalf("pending must not appear publicly, got %v", listed)
	}

	code, _ = lobbyJSON(t, app, http.MethodGet, "/api/achievers-lobby/"+id, nil)
	if code != 404 {
		t.Fatalf("pending detail should 404, got %d", code)
	}

	code, activated := lobbyJSON(t, app, http.MethodPatch, "/api/admin/achievers-lobby/"+id+"/status", map[string]any{
		"status": "active",
	})
	if code != 200 {
		t.Fatalf("activate status %d body=%v", code, activated)
	}
	if lobbyData(t, activated)["status"] != "active" {
		t.Fatalf("want active: %v", activated)
	}

	code, listed = lobbyJSON(t, app, http.MethodGet, "/api/achievers-lobby?kind=achiever", nil)
	if code != 200 {
		t.Fatalf("public list after activate %d %v", code, listed)
	}
	rows, _ = listed["data"].([]any)
	if len(rows) != 1 {
		t.Fatalf("want 1 public row, got %v", listed)
	}
}

func TestAchieversLobbyKindTabsAndSearch(t *testing.T) {
	app := setupLobbyCRUDApp(t)

	for _, row := range []map[string]any{
		{"kind": "achiever", "name": "Suma", "mobile": "9000000001", "category": "Dairy", "title": "Milk record", "video_url": "/uploads/achievers-lobby/a.mp4"},
		{"kind": "innovation", "name": "Kiran", "mobile": "9000000002", "category": "Machinery", "title": "New drier", "video_url": "/uploads/achievers-lobby/b.mp4"},
		{"kind": "achiever", "name": "Lakshmi", "mobile": "9000000003", "category": "Education", "title": "School farm", "video_url": "/uploads/achievers-lobby/c.mp4"},
	} {
		code, created := lobbyJSON(t, app, http.MethodPost, "/api/admin/achievers-lobby", row)
		if code != 201 {
			t.Fatalf("admin create %d %v", code, created)
		}
		if lobbyData(t, created)["status"] != "active" {
			t.Fatalf("admin create should be active: %v", created)
		}
	}

	code, listed := lobbyJSON(t, app, http.MethodGet, "/api/achievers-lobby?kind=achiever", nil)
	if code != 200 {
		t.Fatalf("achiever list %d %v", code, listed)
	}
	rows, _ := listed["data"].([]any)
	if len(rows) != 2 {
		t.Fatalf("want 2 achievers, got %v", listed)
	}

	code, listed = lobbyJSON(t, app, http.MethodGet, "/api/achievers-lobby?kind=innovation", nil)
	if code != 200 {
		t.Fatalf("innovation list %d %v", code, listed)
	}
	rows, _ = listed["data"].([]any)
	if len(rows) != 1 {
		t.Fatalf("want 1 innovation, got %v", listed)
	}

	code, listed = lobbyJSON(t, app, http.MethodGet, "/api/achievers-lobby?name=suma", nil)
	if code != 200 {
		t.Fatalf("name search %d %v", code, listed)
	}
	rows, _ = listed["data"].([]any)
	if len(rows) != 1 {
		t.Fatalf("want 1 name match, got %v", listed)
	}

	code, listed = lobbyJSON(t, app, http.MethodGet, "/api/achievers-lobby?category=Machinery", nil)
	if code != 200 {
		t.Fatalf("category search %d %v", code, listed)
	}
	rows, _ = listed["data"].([]any)
	if len(rows) != 1 {
		t.Fatalf("want 1 category match, got %v", listed)
	}

	code, listed = lobbyJSON(t, app, http.MethodGet, "/api/achievers-lobby?q=drier", nil)
	if code != 200 {
		t.Fatalf("q search %d %v", code, listed)
	}
	rows, _ = listed["data"].([]any)
	if len(rows) != 1 {
		t.Fatalf("want 1 q match, got %v", listed)
	}

	code, latest := lobbyJSON(t, app, http.MethodGet, "/api/achievers-lobby/latest", nil)
	if code != 200 {
		t.Fatalf("latest %d %v", code, latest)
	}
	if lobbyData(t, latest)["name"] != "Lakshmi" {
		t.Fatalf("latest should be last created Lakshmi, got %v", latest)
	}

	code, latest = lobbyJSON(t, app, http.MethodGet, "/api/achievers-lobby/latest?kind=innovation", nil)
	if code != 200 {
		t.Fatalf("latest innovation %d %v", code, latest)
	}
	if lobbyData(t, latest)["name"] != "Kiran" {
		t.Fatalf("latest innovation: %v", latest)
	}
}

func TestAchieversLobbyAdminCRUDAndCategories(t *testing.T) {
	app := setupLobbyCRUDApp(t)

	code, cat := lobbyJSON(t, app, http.MethodPost, "/api/admin/achievers-lobby/categories", map[string]any{
		"kind":    "achiever",
		"name":    "Awards",
		"name_kn": "ಪ್ರಶಸ್ತಿ",
	})
	if code != 201 {
		t.Fatalf("create category %d %v", code, cat)
	}
	catID := lobbyID(t, cat)

	code, updated := lobbyJSON(t, app, http.MethodPut, "/api/admin/achievers-lobby/categories/"+catID, map[string]any{
		"name":   "Farm Awards",
		"status": "active",
	})
	if code != 200 {
		t.Fatalf("update category %d %v", code, updated)
	}
	if lobbyData(t, updated)["name"] != "Farm Awards" {
		t.Fatalf("category name: %v", updated)
	}

	code, created := lobbyJSON(t, app, http.MethodPost, "/api/admin/achievers-lobby", map[string]any{
		"kind":        "achiever",
		"name":        "Naveen",
		"mobile":      "9111111111",
		"category":    "Farm Awards",
		"address":     "Sirsi",
		"title":       "State award",
		"description": "Won state farm award",
		"video_url":   "/uploads/achievers-lobby/n.mp4",
		"status":      "pending",
	})
	if code != 201 {
		t.Fatalf("admin create pending %d %v", code, created)
	}
	id := lobbyID(t, created)
	if lobbyData(t, created)["status"] != "pending" {
		t.Fatalf("explicit pending: %v", created)
	}

	code, listed := lobbyJSON(t, app, http.MethodGet, "/api/admin/achievers-lobby?status=pending", nil)
	if code != 200 {
		t.Fatalf("admin pending list %d %v", code, listed)
	}
	rows, _ := listed["data"].([]any)
	if len(rows) != 1 {
		t.Fatalf("want 1 pending, got %v", listed)
	}

	code, saved := lobbyJSON(t, app, http.MethodPut, "/api/admin/achievers-lobby/"+id, map[string]any{
		"kind":        "innovation",
		"name":        "Naveen K",
		"mobile":      "9111111111",
		"category":    "Machinery",
		"address":     "Siddapur",
		"title":       "New tool",
		"description": "Updated",
		"video_url":   "/uploads/achievers-lobby/n2.mp4",
		"status":      "active",
	})
	if code != 200 {
		t.Fatalf("admin update %d %v", code, saved)
	}
	data := lobbyData(t, saved)
	if data["kind"] != "innovation" || data["address"] != "Siddapur" || data["status"] != "active" {
		t.Fatalf("updated fields: %v", data)
	}

	code, got := lobbyJSON(t, app, http.MethodGet, "/api/admin/achievers-lobby/"+id, nil)
	if code != 200 {
		t.Fatalf("admin get %d %v", code, got)
	}

	code, _ = lobbyJSON(t, app, http.MethodDelete, "/api/admin/achievers-lobby/"+id, nil)
	if code != 200 {
		t.Fatalf("delete item status %d", code)
	}
	code, _ = lobbyJSON(t, app, http.MethodGet, "/api/admin/achievers-lobby/"+id, nil)
	if code != 404 {
		t.Fatalf("deleted item should 404")
	}

	code, pubCats := lobbyJSON(t, app, http.MethodGet, "/api/achievers-lobby/categories?kind=achiever", nil)
	if code != 200 {
		t.Fatalf("public cats %d %v", code, pubCats)
	}
	cats, _ := pubCats["data"].([]any)
	if len(cats) != 1 {
		t.Fatalf("want 1 public category, got %v", pubCats)
	}

	code, _ = lobbyJSON(t, app, http.MethodDelete, "/api/admin/achievers-lobby/categories/"+catID, nil)
	if code != 200 {
		t.Fatalf("delete category status %d", code)
	}
}

func TestAchieversLobbyVideoUpload(t *testing.T) {
	app := setupLobbyCRUDApp(t)
	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)
	fw, err := w.CreateFormFile("video", "clip.mp4")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := fw.Write([]byte("fake-mp4-bytes")); err != nil {
		t.Fatal(err)
	}
	if err := w.Close(); err != nil {
		t.Fatal(err)
	}
	req := httptest.NewRequest(http.MethodPost, "/api/achievers-lobby/upload", &buf)
	req.Header.Set("Content-Type", w.FormDataContentType())
	resp, err := app.Test(req, 8000)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != 201 {
		t.Fatalf("upload status %d body=%s", resp.StatusCode, raw)
	}
	out := map[string]any{}
	_ = json.Unmarshal(raw, &out)
	url, _ := out["url"].(string)
	if !strings.HasPrefix(url, "/uploads/achievers-lobby/") || !strings.HasSuffix(url, ".mp4") {
		t.Fatalf("unexpected url %v", out)
	}
}

func TestAchieversLobbySubmitValidation(t *testing.T) {
	app := setupLobbyCRUDApp(t)
	code, body := lobbyJSON(t, app, http.MethodPost, "/api/achievers-lobby/submit", map[string]any{
		"kind": "unknown", "name": "A", "mobile": "1", "category": "X", "video_url": "/x.mp4",
	})
	if code != 400 {
		t.Fatalf("bad kind should 400, got %d %v", code, body)
	}
	code, body = lobbyJSON(t, app, http.MethodPost, "/api/achievers-lobby/submit", map[string]any{
		"kind": "achiever", "name": "A", "mobile": "1", "category": "X",
	})
	if code != 400 {
		t.Fatalf("missing video should 400, got %d %v", code, body)
	}
}
