package handler

import (
	"fmt"
	"io"
	"mime/multipart"
	"os"
	"path/filepath"
	"strings"
	"time"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

const (
	maxLobbyVideoBytes   = 80 << 20 // 80 MiB
	lobbyVideoUploadDir  = "achievers-lobby"
)

var lobbyDB *gorm.DB

func SetAchieversLobbyDB(db *gorm.DB) {
	lobbyDB = db
}

type lobbyItemBody struct {
	Kind        string `json:"kind"`
	Status      string `json:"status"`
	Name        string `json:"name"`
	Mobile      string `json:"mobile"`
	Category    string `json:"category"`
	Address     string `json:"address"`
	Title       string `json:"title"`
	Description string `json:"description"`
	VideoURL    string `json:"video_url"`
}

type lobbyCategoryBody struct {
	Kind      string `json:"kind"`
	Name      string `json:"name"`
	NameKn    string `json:"name_kn"`
	SortOrder *int   `json:"sort_order"`
	Status    string `json:"status"`
}

func normalizeLobbyKind(s string) string {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "achiever", "achievers":
		return models.LobbyKindAchiever
	case "innovation", "innovations", "innvation", "innvations":
		return models.LobbyKindInnovation
	default:
		return ""
	}
}

func normalizeLobbyCategoryKind(s string) string {
	k := strings.ToLower(strings.TrimSpace(s))
	if k == models.LobbyCategoryBoth {
		return models.LobbyCategoryBoth
	}
	return normalizeLobbyKind(k)
}

func normalizeLobbyStatus(s string) string {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case models.LobbyStatusPending, models.LobbyStatusActive, models.LobbyStatusRejected:
		return strings.ToLower(strings.TrimSpace(s))
	default:
		return ""
	}
}

func sniffLobbyVideoExt(fh *multipart.FileHeader) (string, bool) {
	name := strings.ToLower(fh.Filename)
	ct := strings.ToLower(fh.Header.Get("Content-Type"))
	switch {
	case strings.HasSuffix(name, ".mp4") || strings.Contains(ct, "video/mp4"):
		return ".mp4", true
	case strings.HasSuffix(name, ".mov") || strings.Contains(ct, "quicktime"):
		return ".mov", true
	case strings.HasSuffix(name, ".webm") || strings.Contains(ct, "webm"):
		return ".webm", true
	case strings.HasSuffix(name, ".m4v"):
		return ".m4v", true
	case strings.HasSuffix(name, ".3gp") || strings.Contains(ct, "3gpp"):
		return ".3gp", true
	default:
		return "", false
	}
}

func saveLobbyVideoFile(file *multipart.FileHeader) (string, error) {
	ext, ok := sniffLobbyVideoExt(file)
	if !ok {
		return "", fmt.Errorf("unsupported video type (mp4, mov, webm, m4v, 3gp)")
	}
	if file.Size > maxLobbyVideoBytes {
		return "", fmt.Errorf("video exceeds %d MB", maxLobbyVideoBytes/(1<<20))
	}
	base := filepath.Join("uploads", lobbyVideoUploadDir)
	if err := os.MkdirAll(base, 0755); err != nil {
		return errWrap("mkdir", err)
	}
	name := uuid.NewString() + ext
	dstPath := filepath.Join(base, name)
	src, err := file.Open()
	if err != nil {
		return errWrap("open", err)
	}
	defer src.Close()
	dst, err := os.Create(dstPath)
	if err != nil {
		return errWrap("create", err)
	}
	defer dst.Close()
	if _, err := io.Copy(dst, src); err != nil {
		return errWrap("copy", err)
	}
	return "/" + filepath.ToSlash(filepath.Join("uploads", lobbyVideoUploadDir, name)), nil
}

func errWrap(op string, err error) (string, error) {
	return "", fmt.Errorf("%s: %w", op, err)
}

func applyLobbySearch(q *gorm.DB, term string) *gorm.DB {
	term = strings.TrimSpace(term)
	if term == "" {
		return q
	}
	like := "%" + strings.ToLower(term) + "%"
	return q.Where(
		"LOWER(name) LIKE ? OR LOWER(category) LIKE ? OR LOWER(title) LIKE ? OR LOWER(address) LIKE ?",
		like, like, like, like,
	)
}

func lobbyItemFromBody(body lobbyItemBody, requireVideo bool) (models.AchieversLobbyItem, string) {
	kind := normalizeLobbyKind(body.Kind)
	if kind == "" {
		return models.AchieversLobbyItem{}, "kind must be achiever or innovation"
	}
	name := strings.TrimSpace(body.Name)
	if name == "" {
		return models.AchieversLobbyItem{}, "name is required"
	}
	mobile := strings.TrimSpace(body.Mobile)
	if mobile == "" {
		return models.AchieversLobbyItem{}, "mobile is required"
	}
	category := strings.TrimSpace(body.Category)
	if category == "" {
		return models.AchieversLobbyItem{}, "category is required"
	}
	video := strings.TrimSpace(body.VideoURL)
	if requireVideo && video == "" {
		return models.AchieversLobbyItem{}, "video is required"
	}
	row := models.AchieversLobbyItem{
		Kind:        kind,
		Name:        name,
		Mobile:      mobile,
		Category:    category,
		Address:     strings.TrimSpace(body.Address),
		Title:       strings.TrimSpace(body.Title),
		Description: strings.TrimSpace(body.Description),
		VideoURL:    video,
	}
	return row, ""
}

func parseLobbyFormBody(c *fiber.Ctx) lobbyItemBody {
	return lobbyItemBody{
		Kind:        c.FormValue("kind"),
		Status:      c.FormValue("status"),
		Name:        c.FormValue("name"),
		Mobile:      c.FormValue("mobile"),
		Category:    c.FormValue("category"),
		Address:     c.FormValue("address"),
		Title:       c.FormValue("title"),
		Description: c.FormValue("description"),
		VideoURL:    c.FormValue("video_url"),
	}
}

func maybeSaveLobbyVideo(c *fiber.Ctx) (string, error) {
	file, err := c.FormFile("video")
	if err != nil {
		file, err = c.FormFile("file")
	}
	if err != nil || file == nil {
		return "", nil
	}
	return saveLobbyVideoFile(file)
}

func stampPublished(row *models.AchieversLobbyItem, status string) {
	if status == models.LobbyStatusActive {
		if row.PublishedAt == nil {
			now := time.Now().UTC()
			row.PublishedAt = &now
		}
	}
}

// ---------- Public (Flutter) ----------

// ListAchieversLobbyPublic GET /api/achievers-lobby?kind=&category=&q=&page=&limit=
func ListAchieversLobbyPublic(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 20)
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 20
	}
	q := lobbyDB.Model(&models.AchieversLobbyItem{}).
		Where("tenant_id = ? AND status = ?", tid, models.LobbyStatusActive)
	if kind := normalizeLobbyKind(c.Query("kind")); kind != "" {
		q = q.Where("kind = ?", kind)
	}
	if cat := strings.TrimSpace(c.Query("category")); cat != "" {
		q = q.Where("LOWER(category) = ?", strings.ToLower(cat))
	}
	q = applyLobbySearch(q, c.Query("q"))
	if name := strings.TrimSpace(c.Query("name")); name != "" {
		like := "%" + strings.ToLower(name) + "%"
		q = q.Where("LOWER(name) LIKE ?", like)
	}

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return c.JSON(fiber.Map{"data": []models.AchieversLobbyItem{}, "total": 0, "page": page, "limit": limit})
	}
	var rows []models.AchieversLobbyItem
	if err := q.Order("COALESCE(published_at, created_at) DESC, id DESC").
		Limit(limit).Offset((page - 1) * limit).Find(&rows).Error; err != nil {
		return c.JSON(fiber.Map{"data": []models.AchieversLobbyItem{}, "total": 0, "page": page, "limit": limit})
	}
	if rows == nil {
		rows = []models.AchieversLobbyItem{}
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

// GetLatestAchieversLobbyPublic GET /api/achievers-lobby/latest?kind=
func GetLatestAchieversLobbyPublic(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	q := lobbyDB.Model(&models.AchieversLobbyItem{}).
		Where("tenant_id = ? AND status = ?", tid, models.LobbyStatusActive)
	if kind := normalizeLobbyKind(c.Query("kind")); kind != "" {
		q = q.Where("kind = ?", kind)
	}
	var row models.AchieversLobbyItem
	if err := q.Order("COALESCE(published_at, created_at) DESC, id DESC").First(&row).Error; err != nil {
		return c.JSON(fiber.Map{"data": nil})
	}
	return c.JSON(fiber.Map{"data": row})
}

// ListAchieversLobbyCategoriesPublic GET /api/achievers-lobby/categories?kind=
func ListAchieversLobbyCategoriesPublic(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	q := lobbyDB.Model(&models.AchieversLobbyCategory{}).
		Where("tenant_id = ? AND status = ?", tid, "active")
	if kind := normalizeLobbyKind(c.Query("kind")); kind != "" {
		q = q.Where("kind IN ?", []string{kind, models.LobbyCategoryBoth})
	}
	var rows []models.AchieversLobbyCategory
	if err := q.Order("sort_order ASC, name ASC").Find(&rows).Error; err != nil {
		return c.JSON(fiber.Map{"data": []models.AchieversLobbyCategory{}})
	}
	if rows == nil {
		rows = []models.AchieversLobbyCategory{}
	}
	return c.JSON(fiber.Map{"data": rows})
}

// GetAchieversLobbyPublic GET /api/achievers-lobby/:id
func GetAchieversLobbyPublic(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	var row models.AchieversLobbyItem
	if err := lobbyDB.Where("id = ? AND tenant_id = ? AND status = ?", id, tid, models.LobbyStatusActive).
		First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	return c.JSON(fiber.Map{"data": row})
}

// UploadAchieversLobbyVideoPublic POST /api/achievers-lobby/upload
func UploadAchieversLobbyVideoPublic(c *fiber.Ctx) error {
	file, err := c.FormFile("video")
	if err != nil {
		file, err = c.FormFile("file")
	}
	if err != nil || file == nil {
		return c.Status(400).JSON(fiber.Map{"error": "video file is required"})
	}
	url, err := saveLobbyVideoFile(file)
	if err != nil {
		return c.Status(400).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"url": url})
}

// SubmitAchieversLobbyPublic POST /api/achievers-lobby/submit
func SubmitAchieversLobbyPublic(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	ct := strings.ToLower(c.Get("Content-Type"))
	var body lobbyItemBody
	if strings.Contains(ct, "multipart/form-data") {
		body = parseLobbyFormBody(c)
		if url, err := maybeSaveLobbyVideo(c); err != nil {
			return c.Status(400).JSON(fiber.Map{"error": err.Error()})
		} else if url != "" {
			body.VideoURL = url
		}
	} else if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	row, msg := lobbyItemFromBody(body, true)
	if msg != "" {
		return c.Status(400).JSON(fiber.Map{"error": msg})
	}
	row.TenantID = tid
	row.Status = models.LobbyStatusPending
	if err := lobbyDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to submit", "details": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"data": row})
}

// ---------- Admin ----------

func AdminListAchieversLobby(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	page := c.QueryInt("page", 1)
	limit := c.QueryInt("limit", 20)
	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 200 {
		limit = 20
	}
	q := lobbyDB.Model(&models.AchieversLobbyItem{}).Where("tenant_id = ?", tid)
	status := strings.ToLower(strings.TrimSpace(c.Query("status", "all")))
	switch status {
	case models.LobbyStatusPending, models.LobbyStatusActive, models.LobbyStatusRejected:
		q = q.Where("status = ?", status)
	case "all", "":
	default:
		return c.Status(400).JSON(fiber.Map{"error": "status must be pending, active, rejected, or all"})
	}
	if kind := normalizeLobbyKind(c.Query("kind")); kind != "" {
		q = q.Where("kind = ?", kind)
	}
	if cat := strings.TrimSpace(c.Query("category")); cat != "" {
		q = q.Where("LOWER(category) = ?", strings.ToLower(cat))
	}
	q = applyLobbySearch(q, c.Query("q"))

	var total int64
	if err := q.Count(&total).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	var rows []models.AchieversLobbyItem
	if err := q.Order("CASE status WHEN 'pending' THEN 0 WHEN 'active' THEN 1 ELSE 2 END, id DESC").
		Limit(limit).Offset((page - 1) * limit).Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if rows == nil {
		rows = []models.AchieversLobbyItem{}
	}
	return c.JSON(fiber.Map{"data": rows, "total": total, "page": page, "limit": limit})
}

func AdminGetAchieversLobby(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	var row models.AchieversLobbyItem
	if err := lobbyDB.Where("id = ? AND tenant_id = ?", id, tid).First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	return c.JSON(fiber.Map{"data": row})
}

func AdminCreateAchieversLobby(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	ct := strings.ToLower(c.Get("Content-Type"))
	var body lobbyItemBody
	if strings.Contains(ct, "multipart/form-data") {
		body = parseLobbyFormBody(c)
		if url, err := maybeSaveLobbyVideo(c); err != nil {
			return c.Status(400).JSON(fiber.Map{"error": err.Error()})
		} else if url != "" {
			body.VideoURL = url
		}
	} else if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}
	row, msg := lobbyItemFromBody(body, true)
	if msg != "" {
		return c.Status(400).JSON(fiber.Map{"error": msg})
	}
	status := normalizeLobbyStatus(body.Status)
	if status == "" {
		status = models.LobbyStatusActive
	}
	row.TenantID = tid
	row.Status = status
	stampPublished(&row, status)
	if err := lobbyDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to create", "details": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"data": row})
}

func AdminUpdateAchieversLobby(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	var existing models.AchieversLobbyItem
	if err := lobbyDB.Where("id = ? AND tenant_id = ?", id, tid).First(&existing).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	ct := strings.ToLower(c.Get("Content-Type"))
	var body lobbyItemBody
	if strings.Contains(ct, "multipart/form-data") {
		body = parseLobbyFormBody(c)
		if url, err := maybeSaveLobbyVideo(c); err != nil {
			return c.Status(400).JSON(fiber.Map{"error": err.Error()})
		} else if url != "" {
			body.VideoURL = url
		}
	} else if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body", "details": err.Error()})
	}

	if k := normalizeLobbyKind(body.Kind); k != "" {
		existing.Kind = k
	}
	if n := strings.TrimSpace(body.Name); n != "" {
		existing.Name = n
	}
	if m := strings.TrimSpace(body.Mobile); m != "" {
		existing.Mobile = m
	}
	if cat := strings.TrimSpace(body.Category); cat != "" {
		existing.Category = cat
	}
	if body.Address != "" || c.Method() == fiber.MethodPut {
		existing.Address = strings.TrimSpace(body.Address)
	}
	if body.Title != "" || strings.Contains(ct, "application/json") {
		existing.Title = strings.TrimSpace(body.Title)
	}
	if body.Description != "" || strings.Contains(ct, "application/json") {
		existing.Description = strings.TrimSpace(body.Description)
	}
	if v := strings.TrimSpace(body.VideoURL); v != "" {
		existing.VideoURL = v
	}
	if st := normalizeLobbyStatus(body.Status); st != "" {
		existing.Status = st
		stampPublished(&existing, st)
	}
	if err := lobbyDB.Save(&existing).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": "Failed to update", "details": err.Error()})
	}
	return c.JSON(fiber.Map{"data": existing})
}

func AdminDeleteAchieversLobby(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	res := lobbyDB.Where("id = ? AND tenant_id = ?", id, tid).Delete(&models.AchieversLobbyItem{})
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	return c.JSON(fiber.Map{"ok": true})
}

func AdminSetAchieversLobbyStatus(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	var payload struct {
		Status string `json:"status"`
	}
	if err := c.BodyParser(&payload); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	status := normalizeLobbyStatus(payload.Status)
	if status == "" {
		return c.Status(400).JSON(fiber.Map{"error": "status must be pending, active, or rejected"})
	}
	var row models.AchieversLobbyItem
	if err := lobbyDB.Where("id = ? AND tenant_id = ?", id, tid).First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	row.Status = status
	stampPublished(&row, status)
	if err := lobbyDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": row})
}

func AdminUploadAchieversLobbyVideo(c *fiber.Ctx) error {
	return UploadAchieversLobbyVideoPublic(c)
}

func AdminListLobbyCategories(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	q := lobbyDB.Model(&models.AchieversLobbyCategory{}).Where("tenant_id = ?", tid)
	if kind := normalizeLobbyCategoryKind(c.Query("kind")); kind != "" && kind != models.LobbyCategoryBoth {
		q = q.Where("kind IN ?", []string{kind, models.LobbyCategoryBoth})
	}
	var rows []models.AchieversLobbyCategory
	if err := q.Order("kind ASC, sort_order ASC, name ASC").Find(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	if rows == nil {
		rows = []models.AchieversLobbyCategory{}
	}
	return c.JSON(fiber.Map{"data": rows})
}

func AdminCreateLobbyCategory(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	var body lobbyCategoryBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	kind := normalizeLobbyCategoryKind(body.Kind)
	if kind == "" {
		return c.Status(400).JSON(fiber.Map{"error": "kind must be achiever, innovation, or both"})
	}
	name := strings.TrimSpace(body.Name)
	if name == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name is required"})
	}
	status := strings.ToLower(strings.TrimSpace(body.Status))
	if status == "" {
		status = "active"
	}
	if status != "active" && status != "inactive" {
		return c.Status(400).JSON(fiber.Map{"error": "status must be active or inactive"})
	}
	sort := 0
	if body.SortOrder != nil {
		sort = *body.SortOrder
	}
	row := models.AchieversLobbyCategory{
		TenantID:  tid,
		Kind:      kind,
		Name:      name,
		NameKn:    strings.TrimSpace(body.NameKn),
		SortOrder: sort,
		Status:    status,
	}
	if err := lobbyDB.Create(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.Status(201).JSON(fiber.Map{"data": row})
}

func AdminUpdateLobbyCategory(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	var row models.AchieversLobbyCategory
	if err := lobbyDB.Where("id = ? AND tenant_id = ?", id, tid).First(&row).Error; err != nil {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	var body lobbyCategoryBody
	if err := c.BodyParser(&body); err != nil {
		return c.Status(400).JSON(fiber.Map{"error": "Invalid request body"})
	}
	if k := normalizeLobbyCategoryKind(body.Kind); k != "" {
		row.Kind = k
	}
	if n := strings.TrimSpace(body.Name); n != "" {
		row.Name = n
	}
	row.NameKn = strings.TrimSpace(body.NameKn)
	if body.SortOrder != nil {
		row.SortOrder = *body.SortOrder
	}
	if st := strings.ToLower(strings.TrimSpace(body.Status)); st != "" {
		if st != "active" && st != "inactive" {
			return c.Status(400).JSON(fiber.Map{"error": "status must be active or inactive"})
		}
		row.Status = st
	}
	if err := lobbyDB.Save(&row).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	return c.JSON(fiber.Map{"data": row})
}

func AdminDeleteLobbyCategory(c *fiber.Ctx) error {
	tid := tenantIDFromCtx(c)
	id, err := c.ParamsInt("id")
	if err != nil || id < 1 {
		return c.Status(400).JSON(fiber.Map{"error": "invalid id"})
	}
	res := lobbyDB.Where("id = ? AND tenant_id = ?", id, tid).Delete(&models.AchieversLobbyCategory{})
	if res.Error != nil {
		return c.Status(500).JSON(fiber.Map{"error": res.Error.Error()})
	}
	if res.RowsAffected == 0 {
		return c.Status(404).JSON(fiber.Map{"error": "not found"})
	}
	return c.JSON(fiber.Map{"ok": true})
}
