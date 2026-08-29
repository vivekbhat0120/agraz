package handler

import (
	"fmt"
	"sort"
	"strings"
	"time"

	"erp.local/backend/middleware"
	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"github.com/shopspring/decimal"
	"gorm.io/gorm"
)

const dailySummaryMaxEntries = 1500

type dailySummaryEntry struct {
	Module        string    `json:"module"`
	ModuleLabel   string    `json:"module_label"`
	CategoryKey   string    `json:"category_key"`
	CategoryLabel string    `json:"category_label"`
	ID            uint      `json:"id"`
	Date          time.Time `json:"date"`
	Title         string    `json:"title"`
	Subtitle      string    `json:"subtitle"`
	Amount        float64   `json:"amount"`
	Side          string    `json:"side"`
	Kind          string    `json:"kind"`
}

type dailySummaryCategory struct {
	Key    string  `json:"key"`
	Label  string  `json:"label"`
	Module string  `json:"module"`
	Count  int     `json:"count"`
	Credit float64 `json:"credit"`
	Debit  float64 `json:"debit"`
	Amount float64 `json:"amount"`
	In     float64 `json:"in_amount"`
	Out    float64 `json:"out_amount"`
}

type dailyWindow struct {
	fromDay     time.Time
	toDay       time.Time
	from        time.Time
	toExclusive time.Time
	hasFrom     bool
	hasTo       bool
}

type dailySummaryAcc struct {
	keepEntries bool
	entries     []dailySummaryEntry
	categories  map[string]*dailySummaryCategory
	order       []string
	credit      float64
	debit       float64
}

func newDailySummaryAcc(keepEntries bool) *dailySummaryAcc {
	return &dailySummaryAcc{
		keepEntries: keepEntries,
		entries:     make([]dailySummaryEntry, 0, 64),
		categories:  map[string]*dailySummaryCategory{},
	}
}

func (a *dailySummaryAcc) add(e dailySummaryEntry) {
	if e.CategoryKey == "" {
		e.CategoryKey = e.Module
	}
	if e.CategoryLabel == "" {
		e.CategoryLabel = e.ModuleLabel
	}
	if a.keepEntries {
		a.entries = append(a.entries, e)
	}
	m := a.categories[e.CategoryKey]
	if m == nil {
		m = &dailySummaryCategory{
			Key:    e.CategoryKey,
			Label:  e.CategoryLabel,
			Module: e.Module,
		}
		a.categories[e.CategoryKey] = m
		a.order = append(a.order, e.CategoryKey)
	}
	m.Count++
	m.Amount += e.Amount
	switch e.Side {
	case "in":
		m.Credit += e.Amount
		m.In += e.Amount
		a.credit += e.Amount
	case "out":
		m.Debit += e.Amount
		m.Out += e.Amount
		a.debit += e.Amount
	}
}

func (a *dailySummaryAcc) net() float64 {
	return a.credit - a.debit
}

func dailySummaryWindow(fromQ, toQ string, now time.Time) (fromDay, toDay, from, toExclusive time.Time) {
	fromDay = time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	toDay = fromDay
	if t, ok := parseOptionalTime(fromQ); ok {
		fromDay = time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
	}
	if t, ok := parseOptionalTime(toQ); ok {
		toDay = time.Date(t.Year(), t.Month(), t.Day(), 0, 0, 0, 0, time.UTC)
	}
	if toDay.Before(fromDay) {
		fromDay, toDay = toDay, fromDay
	}
	from = fromDay
	toExclusive = toDay.Add(24 * time.Hour)
	return
}

func applyDateWindow(q *gorm.DB, col string, w dailyWindow) *gorm.DB {
	if w.hasFrom {
		q = q.Where(col+" >= ?", w.from)
	}
	if w.hasTo {
		q = q.Where(col+" < ?", w.toExclusive)
	}
	return q
}

func periodWindow(fromDay, toDay, from, toExclusive time.Time) dailyWindow {
	return dailyWindow{
		fromDay: fromDay, toDay: toDay, from: from, toExclusive: toExclusive,
		hasFrom: true, hasTo: true,
	}
}

func openingWindow(fromDay time.Time) dailyWindow {
	return dailyWindow{
		fromDay:     time.Time{},
		toDay:       fromDay.AddDate(0, 0, -1),
		from:        time.Time{},
		toExclusive: fromDay,
		hasFrom:     false,
		hasTo:       true,
	}
}

func dailySummaryDisabled(c *fiber.Ctx) []string {
	v := c.Locals(middleware.CtxDisabledFeatures)
	if s, ok := v.([]string); ok {
		return s
	}
	return nil
}

func dailyFeatureOn(disabled []string, key string) bool {
	for _, d := range disabled {
		if d == key {
			return false
		}
	}
	return true
}

func joinParts(parts ...string) string {
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		if p != "" {
			out = append(out, p)
		}
	}
	return strings.Join(out, " · ")
}

func decFloat(d decimal.Decimal) float64 {
	return d.InexactFloat64()
}

func clip(s string, n int) string {
	s = strings.TrimSpace(s)
	runes := []rune(s)
	if n <= 0 || len(runes) <= n {
		return s
	}
	return strings.TrimSpace(string(runes[:n])) + "…"
}

func laborEntryAmount(l models.Labor) float64 {
	amt := l.Wage.Mul(l.Hours)
	if l.Extra != nil {
		amt = amt.Add(l.Extra.OthersSum())
	}
	return decFloat(amt)
}

func laborKindLabel(kind string) string {
	switch strings.ToLower(strings.TrimSpace(kind)) {
	case "payment":
		return "Payment"
	case "opening":
		return "Opening"
	case "tally":
		return "Tally"
	default:
		return "Payable"
	}
}

func laborWorkKindLabel(kind string) string {
	switch strings.ToLower(strings.TrimSpace(kind)) {
	case "receipt":
		return "Receipt"
	default:
		return "Receivable"
	}
}

func ptrFloat(v *float64) float64 {
	if v == nil {
		return 0
	}
	return *v
}

func derefStr(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func collectIncomeExpense(uid uint, w dailyWindow, acc *dailySummaryAcc) {
	if incomeExpenseDB == nil {
		return
	}
	var rows []models.IncomeExpense
	q := scopeByUserID(incomeExpenseDB.Model(&models.IncomeExpense{}), uid)
	if err := applyDateWindow(q, "date", w).
		Order("date DESC, id DESC").Find(&rows).Error; err != nil {
		return
	}
	for _, r := range rows {
		side := "out"
		if strings.EqualFold(r.Type, "Income") {
			side = "in"
		}
		cat := strings.TrimSpace(r.Category)
		if cat == "" {
			cat = "Income & Expense"
		}
		acc.add(dailySummaryEntry{
			Module:        "income_expense",
			ModuleLabel:   "Income & Expense",
			CategoryKey:   "income_expense:" + strings.ToLower(cat),
			CategoryLabel: cat,
			ID:            r.ID,
			Date:          r.Date,
			Title:         joinParts(r.Type, r.Category, r.SubCategory),
			Subtitle:      joinParts(r.Name, r.TransactionMode, derefStr(r.Narration)),
			Amount:        decFloat(r.Amount),
			Side:          side,
			Kind:          r.Type,
		})
	}
}

func collectOrgTransactions(uid uint, w dailyWindow, acc *dailySummaryAcc) {
	if organizationDB == nil {
		return
	}
	var rows []models.OrgTransaction
	q := scopeByUserID(organizationDB.Model(&models.OrgTransaction{}), uid)
	if err := applyDateWindow(q, "date", w).
		Preload("Organization").Preload("Ledger").
		Order("date DESC, id DESC").Find(&rows).Error; err != nil {
		return
	}
	for _, r := range rows {
		side := "out"
		if strings.EqualFold(r.Type, "Income") {
			side = "in"
		}
		orgName, ledName := "", ""
		if r.Organization != nil {
			orgName = r.Organization.Name
		}
		if r.Ledger != nil {
			ledName = r.Ledger.Name
		}
		acc.add(dailySummaryEntry{
			Module:      "organization",
			ModuleLabel: "Manage Organization",
			ID:          r.ID,
			Date:        r.Date,
			Title:       joinParts(r.Type, ledName),
			Subtitle:    joinParts(orgName, r.TransactionMode, derefStr(r.Narration)),
			Amount:      r.Amount,
			Side:        side,
			Kind:        r.Type,
		})
	}
}

func collectLabors(uid uint, w dailyWindow, acc *dailySummaryAcc) {
	if laborDB == nil {
		return
	}
	var rows []models.Labor
	q := scopeByUserID(laborDB.Model(&models.Labor{}), uid)
	if err := applyDateWindow(q, "date", w).
		Preload("Extra").Order("date DESC, id DESC").Find(&rows).Error; err != nil {
		return
	}
	for _, r := range rows {
		kind := laborKindLabel(r.EntryKind)
		side := "out"
		if r.EntryKind == "tally" || r.EntryKind == "opening" {
			side = "none"
		}
		acc.add(dailySummaryEntry{
			Module:      "labour",
			ModuleLabel: "Labour Management",
			ID:          r.ID,
			Date:        r.Date,
			Title:       joinParts(kind, r.Name, r.Category),
			Subtitle:    joinParts(r.Shift, r.Location, r.Narration),
			Amount:      laborEntryAmount(r),
			Side:        side,
			Kind:        kind,
		})
	}
}

func collectLaborWorks(uid uint, w dailyWindow, acc *dailySummaryAcc) {
	if laborWorkDB == nil {
		return
	}
	var rows []models.LaborWorkEntry
	q := scopeByUserID(laborWorkDB.Model(&models.LaborWorkEntry{}), uid)
	if err := applyDateWindow(q, "date", w).
		Order("date DESC, id DESC").Find(&rows).Error; err != nil {
		return
	}
	for _, r := range rows {
		kind := laborWorkKindLabel(r.EntryKind)
		side := "in"
		acc.add(dailySummaryEntry{
			Module:      "labour_work",
			ModuleLabel: "Labour Work Entry",
			ID:          r.ID,
			Date:        r.Date,
			Title:       joinParts(kind, r.Name, r.Category),
			Subtitle:    joinParts(r.Shift, r.Location, r.Narration),
			Amount:      decFloat(r.Wage.Mul(r.Hours)),
			Side:        side,
			Kind:        kind,
		})
	}
}

func dairyEntrySide(kind string) string {
	switch kind {
	case dairyKindGiven, dairyKindPayRecv:
		return "in"
	case dairyKindBought, dairyKindPayMade:
		return "out"
	default:
		return "none"
	}
}

func collectDairyFarmer(uid uint, w dailyWindow, acc *dailySummaryAcc) {
	if dairyDB == nil {
		return
	}
	rows, err := loadFarmerDairyRows(uid, w.fromDay, w.toDay, w.hasFrom, w.hasTo, "", "", "")
	if err != nil {
		var fallback []models.DairyEntry
		q := dairyDB.Model(&models.DairyEntry{}).Where("user_id = ? AND origin = ?", uid, dairyOriginFarmer)
		q = filterDairyEntries(q, w.fromDay, w.toDay, w.hasFrom, w.hasTo, "", "", "")
		if q.Order("date DESC, id DESC").Find(&fallback).Error != nil {
			return
		}
		rows = fallback
	}
	for _, r := range rows {
		kind := r.Kind
		party := r.PartyName
		if r.Origin == dairyOriginDairy && r.UserID != uid {
			kind = reverseDairyKind(kind)
			if n := dairyUserName(r.UserID); n != "" {
				party = n
			}
		}
		qty := strings.TrimRight(strings.TrimRight(r.QuantityLiters.StringFixed(3), "0"), ".")
		acc.add(dailySummaryEntry{
			Module:      "dairy",
			ModuleLabel: "Dairy",
			ID:          r.ID,
			Date:        r.Date,
			Title:       joinParts(dairyKindLabel(kind), party),
			Subtitle:    joinParts(r.Shift, qty+" L", r.Narration),
			Amount:      decFloat(r.Amount),
			Side:        dairyEntrySide(kind),
			Kind:        dairyKindLabel(kind),
		})
	}
}

func collectDairyOwner(uid uint, w dailyWindow, acc *dailySummaryAcc) {
	if dairyDB == nil {
		return
	}
	var rows []models.DairyEntry
	q := dairyDB.Model(&models.DairyEntry{}).Where("user_id = ? AND origin = ?", uid, dairyOriginDairy)
	q = filterDairyEntries(q, w.fromDay, w.toDay, w.hasFrom, w.hasTo, "", "", "")
	if err := q.Order("date DESC, id DESC").Find(&rows).Error; err != nil {
		return
	}
	for _, r := range rows {
		qty := strings.TrimRight(strings.TrimRight(r.QuantityLiters.StringFixed(3), "0"), ".")
		acc.add(dailySummaryEntry{
			Module:      "dairy_owner",
			ModuleLabel: "Dairy Owner",
			ID:          r.ID,
			Date:        r.Date,
			Title:       joinParts(dairyKindLabel(r.Kind), r.PartyName),
			Subtitle:    joinParts(r.Shift, qty+" L", r.Narration),
			Amount:      decFloat(r.Amount),
			Side:        dairyEntrySide(r.Kind),
			Kind:        dairyKindLabel(r.Kind),
		})
	}
}

func collectDiary(uid uint, w dailyWindow, acc *dailySummaryAcc) {
	if diaryDB == nil {
		return
	}
	var rows []models.DiaryEntry
	q := scopeByUserID(diaryDB.Model(&models.DiaryEntry{}), uid)
	if err := applyDateWindow(q, "date", w).
		Preload("Label").Order("date DESC, id DESC").Find(&rows).Error; err != nil {
		return
	}
	for _, r := range rows {
		label := ""
		if r.Label != nil {
			label = r.Label.Name
		}
		kind := "Note"
		if r.Kind == "list" {
			kind = "List"
		}
		title := strings.TrimSpace(r.Title)
		if title == "" {
			title = clip(r.Content, 80)
		}
		if title == "" {
			title = kind
		}
		side := "none"
		amt := ptrFloat(r.Amount)
		if amt != 0 {
			side = "out"
		}
		acc.add(dailySummaryEntry{
			Module:      "notes",
			ModuleLabel: "Notes",
			ID:          r.ID,
			Date:        r.Date,
			Title:       joinParts(kind, title),
			Subtitle:    joinParts(label, clip(r.Content, 80)),
			Amount:      amt,
			Side:        side,
			Kind:        kind,
		})
	}
}

func collectFuturePlans(uid uint, w dailyWindow, acc *dailySummaryAcc) {
	if futurePlanDB == nil {
		return
	}
	var rows []models.FuturePlan
	q := scopeByUserID(futurePlanDB.Model(&models.FuturePlan{}), uid)
	if err := applyDateWindow(q, "entry_date", w).
		Preload("Lines").Order("entry_date DESC, id DESC").Find(&rows).Error; err != nil {
		return
	}
	for _, r := range rows {
		est := decimal.Zero
		for _, line := range r.Lines {
			est = est.Add(line.EstimateCost)
		}
		acc.add(dailySummaryEntry{
			Module:      "future_plans",
			ModuleLabel: "Future Plans",
			ID:          r.ID,
			Date:        r.EntryDate,
			Title:       r.PlanName,
			Subtitle:    joinParts(r.Status, fmt.Sprintf("%d lines", r.LineCount)),
			Amount:      decFloat(est),
			Side:        "out",
			Kind:        r.Status,
		})
	}
}

func collectEvents(uid uint, w dailyWindow, acc *dailySummaryAcc) {
	if eventDB == nil {
		return
	}
	var rows []models.ManagedEvent
	q := scopeByUserID(eventDB.Model(&models.ManagedEvent{}), uid)
	if err := applyDateWindow(q, "event_date", w).
		Order("event_date DESC, id DESC").Find(&rows).Error; err != nil {
		return
	}
	for _, r := range rows {
		acc.add(dailySummaryEntry{
			Module:      "event_manage",
			ModuleLabel: "Event Manage",
			ID:          r.ID,
			Date:        r.EventDate,
			Title:       r.Name,
			Subtitle:    joinParts(r.Recurrence, r.NotifyTime),
			Side:        "none",
			Kind:        "Event",
		})
	}
}

func collectLandRtcs(uid uint, w dailyWindow, acc *dailySummaryAcc) {
	if landRtcDB == nil {
		return
	}
	var rows []models.LandRtc
	q := scopeByUserID(landRtcDB.Model(&models.LandRtc{}), uid)
	if err := applyDateWindow(q, "created_at", w).
		Order("created_at DESC, id DESC").Find(&rows).Error; err != nil {
		return
	}
	for _, r := range rows {
		acc.add(dailySummaryEntry{
			Module:      "rtc",
			ModuleLabel: "RTC Entry",
			ID:          r.ID,
			Date:        r.CreatedAt,
			Title:       joinParts("RTC", r.SurveyNumber, r.Hissa),
			Subtitle:    joinParts(r.Taluk, r.Hobli, r.Details),
			Side:        "none",
			Kind:        "RTC",
		})
	}
}

func collectDocuments(uid uint, w dailyWindow, acc *dailySummaryAcc) {
	if documentDB == nil {
		return
	}
	var rows []models.UserDocument
	q := scopeByUserID(documentDB.Model(&models.UserDocument{}), uid)
	if err := applyDateWindow(q, "created_at", w).
		Order("created_at DESC, id DESC").Find(&rows).Error; err != nil {
		return
	}
	for _, r := range rows {
		acc.add(dailySummaryEntry{
			Module:      "documents",
			ModuleLabel: "Documents",
			ID:          r.ID,
			Date:        r.CreatedAt,
			Title:       r.Name,
			Subtitle:    "Document",
			Side:        "none",
			Kind:        "Document",
		})
	}
}

func collectDailySummary(uid uint, w dailyWindow, disabled []string, acc *dailySummaryAcc) {
	if dailyFeatureOn(disabled, "income_expense") {
		collectIncomeExpense(uid, w, acc)
	}
	if dailyFeatureOn(disabled, "organization") {
		collectOrgTransactions(uid, w, acc)
	}
	if dailyFeatureOn(disabled, "labour") {
		collectLabors(uid, w, acc)
	}
	if dailyFeatureOn(disabled, "labour_work") {
		collectLaborWorks(uid, w, acc)
	}
	if dailyFeatureOn(disabled, "dairy") {
		collectDairyFarmer(uid, w, acc)
	}
	if dailyFeatureOn(disabled, "dairy_owner") {
		collectDairyOwner(uid, w, acc)
	}
	if dailyFeatureOn(disabled, "notes") {
		collectDiary(uid, w, acc)
	}
	if dailyFeatureOn(disabled, "future_plans") {
		collectFuturePlans(uid, w, acc)
	}
	if dailyFeatureOn(disabled, "event_manage") {
		collectEvents(uid, w, acc)
	}
	if dailyFeatureOn(disabled, "rtc") {
		collectLandRtcs(uid, w, acc)
	}
	if dailyFeatureOn(disabled, "documents") {
		collectDocuments(uid, w, acc)
	}
}

// GetDailySummary handles GET /api/daily_summary?from=&to=
// Inclusive calendar dates, defaulting both to today. Returns opening balance
// (before from), per-category credit/debit for the period, and closing balance.
func GetDailySummary(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	fromDay, toDay, from, toExclusive := dailySummaryWindow(c.Query("from"), c.Query("to"), time.Now())
	disabled := dailySummaryDisabled(c)

	openAcc := newDailySummaryAcc(false)
	collectDailySummary(uid, openingWindow(fromDay), disabled, openAcc)
	opening := openAcc.net()

	acc := newDailySummaryAcc(true)
	collectDailySummary(uid, periodWindow(fromDay, toDay, from, toExclusive), disabled, acc)

	sort.SliceStable(acc.entries, func(i, j int) bool {
		if !acc.entries[i].Date.Equal(acc.entries[j].Date) {
			return acc.entries[i].Date.After(acc.entries[j].Date)
		}
		if acc.entries[i].CategoryKey != acc.entries[j].CategoryKey {
			return acc.entries[i].CategoryKey < acc.entries[j].CategoryKey
		}
		return acc.entries[i].ID > acc.entries[j].ID
	})

	truncated := false
	entries := acc.entries
	if len(entries) > dailySummaryMaxEntries {
		entries = entries[:dailySummaryMaxEntries]
		truncated = true
	}

	categories := make([]dailySummaryCategory, 0, len(acc.order))
	for _, key := range acc.order {
		if m := acc.categories[key]; m != nil {
			categories = append(categories, *m)
		}
	}

	return c.JSON(fiber.Map{
		"from":            fromDay.Format("2006-01-02"),
		"to":              toDay.Format("2006-01-02"),
		"entry_count":     len(acc.entries),
		"truncated":       truncated,
		"opening_balance": opening,
		"credit":          acc.credit,
		"debit":           acc.debit,
		"income":          acc.credit,
		"expense":         acc.debit,
		"net":             acc.net(),
		"closing_balance": opening + acc.net(),
		"categories":      categories,
		"modules":         categories,
		"entries":         entries,
	})
}
