package handler

import (
	"fmt"
	"strings"
	"time"

	"erp.local/backend/models"
	"github.com/gofiber/fiber/v2"
	"gorm.io/gorm"
)

// personKeyExpr groups labour rows by mobile when present, else by lowercased name.
const laborPersonKeyExpr = `CASE
	WHEN mobile IS NOT NULL AND TRIM(mobile) <> '' THEN 'm:' || TRIM(mobile)
	ELSE 'n:' || LOWER(TRIM(name))
END`

// laborWorkKindSQL matches accrued labour work only.
// Payments, tallies, and opening (account reset) must not be added into hours.
const laborWorkKindSQL = `COALESCE(entry_kind,'payable') = 'payable'`

const laborResetKindSQL = `COALESCE(entry_kind,'payable') IN ('tally','opening')`

func laborPersonKeyExprOn(table string) string {
	if table == "" {
		return laborPersonKeyExpr
	}
	return fmt.Sprintf(`CASE
	WHEN %[1]s.mobile IS NOT NULL AND TRIM(%[1]s.mobile) <> '' THEN 'm:' || TRIM(%[1]s.mobile)
	ELSE 'n:' || LOWER(TRIM(%[1]s.name))
END`, table)
}

func laborResetDistinctSQL() string {
	return fmt.Sprintf(`SELECT DISTINCT ON (%[1]s)
		%[1]s AS person_key,
		id AS reset_id,
		date AS reset_date,
		COALESCE(entry_kind, 'payable') AS reset_kind,
		(wage * hours)::float8 AS reset_amt
	FROM labors
	WHERE user_id = ?
		AND %s
	ORDER BY %[1]s, date DESC, id DESC`, laborPersonKeyExpr, laborResetKindSQL)
}

// laborNetCostSQL is labour credit minus lump-sum payments.
func laborNetCostSQL() string {
	return fmt.Sprintf(
		`COALESCE(SUM(CASE WHEN %s THEN wage * hours ELSE 0 END),0)::float8 - COALESCE(SUM(CASE WHEN entry_kind = 'payment' THEN wage * hours ELSE 0 END),0)::float8`,
		laborWorkKindSQL,
	)
}

type laborAccountReset struct {
	ID   uint      `gorm:"column:id"`
	Date time.Time `gorm:"column:date"`
	Kind string    `gorm:"column:entry_kind"`
	Amt  float64   `gorm:"column:amt"`
}

func findLaborAccountReset(q *gorm.DB) (laborAccountReset, bool) {
	var r laborAccountReset
	err := q.Where(laborResetKindSQL).
		Select(`id, date, COALESCE(entry_kind,'payable') as entry_kind, (wage * hours)::float8 as amt`).
		Order("date DESC, id DESC").
		Limit(1).
		Scan(&r).Error
	if err != nil || r.ID == 0 {
		return r, false
	}
	return r, true
}

func laborSeedFromReset(kind string, amt float64) (payable, paid float64) {
	if normalizeLaborEntryKind(kind) != "opening" {
		return 0, 0
	}
	if amt >= 0 {
		return amt, 0
	}
	return 0, -amt
}

func applyLaborAfterReset(q *gorm.DB, reset laborAccountReset) *gorm.DB {
	loc := reset.Date.Location()
	if loc == nil {
		loc = time.Local
	}
	day := time.Date(reset.Date.Year(), reset.Date.Month(), reset.Date.Day(), 0, 0, 0, 0, loc)
	next := day.AddDate(0, 0, 1)
	return q.Where("date >= ? OR (date >= ? AND date < ? AND id > ?)", next, day, next, reset.ID)
}

// GetLaborPeoplePublic handles GET /api/labors/people
// Distinct labourers with totals; optional q search on name/mobile.
func GetLaborPeoplePublic(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	q := strings.TrimSpace(c.Query("q"))
	limit := c.QueryInt("limit", 100)
	if limit < 1 {
		limit = 100
	}
	if limit > 500 {
		limit = 500
	}

	type row struct {
		PersonKey    string    `gorm:"column:person_key" json:"person_key"`
		Name         string    `gorm:"column:name" json:"name"`
		Mobile       *string   `gorm:"column:mobile" json:"mobile,omitempty"`
		Gender       string    `gorm:"column:gender" json:"gender"`
		EntryCount   int64     `gorm:"column:entry_count" json:"entry_count"`
		TotalCost    float64   `gorm:"column:total_cost" json:"total_cost"`
		TotalHours   float64   `gorm:"column:total_hours" json:"total_hours"`
		TotalPayable float64   `gorm:"column:total_payable" json:"total_payable"`
		TotalPaid    float64   `gorm:"column:total_paid" json:"total_paid"`
		LastDate     time.Time `gorm:"column:last_date" json:"last_date"`
		LastCategory string    `gorm:"column:last_category" json:"last_category"`
		LastLocation string    `gorm:"column:last_location" json:"last_location"`
	}

	pk := laborPersonKeyExprOn("labors")
	afterReset := `(r.reset_id IS NULL OR labors.date::date > r.reset_date::date OR (labors.date::date = r.reset_date::date AND labors.id > r.reset_id))`
	work := `COALESCE(labors.entry_kind,'payable') = 'payable'`
	pay := `labors.entry_kind = 'payment'`
	dbq := laborDB.Table("labors").
		Where("labors.user_id = ?", uid).
		Joins(fmt.Sprintf("LEFT JOIN (%s) r ON r.person_key = %s", laborResetDistinctSQL(), pk), uid).
		Select(fmt.Sprintf(`
			%s as person_key,
			MAX(labors.name) as name,
			MAX(labors.mobile) as mobile,
			MAX(labors.gender) as gender,
			COUNT(*) FILTER (WHERE (%s) AND (%s)) as entry_count,
			COALESCE(SUM(CASE WHEN (%s) AND (%s) THEN labors.hours ELSE 0 END),0)::float8 as total_hours,
			COALESCE(SUM(CASE WHEN (%s) AND (%s) THEN labors.wage * labors.hours ELSE 0 END),0)::float8
				+ COALESCE(MAX(CASE WHEN r.reset_kind = 'opening' AND r.reset_amt > 0 THEN r.reset_amt ELSE 0 END),0) as total_payable,
			COALESCE(SUM(CASE WHEN (%s) AND (%s) THEN labors.wage * labors.hours ELSE 0 END),0)::float8
				+ COALESCE(MAX(CASE WHEN r.reset_kind = 'opening' AND r.reset_amt < 0 THEN -r.reset_amt ELSE 0 END),0) as total_paid,
			MAX(labors.date) as last_date,
			(ARRAY_AGG(labors.category ORDER BY labors.date DESC))[1] as last_category,
			(ARRAY_AGG(labors.location ORDER BY labors.date DESC))[1] as last_location
		`, pk, work, afterReset, work, afterReset, work, afterReset, pay, afterReset)).
		Group(pk)

	if q != "" {
		like := "%" + q + "%"
		dbq = dbq.Having(
			"MAX(labors.name) ILIKE ? OR COALESCE(MAX(labors.mobile),'') ILIKE ?",
			like, like,
		)
	}

	var rows []row
	if err := dbq.Order("last_date DESC").Limit(limit).Scan(&rows).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	out := make([]fiber.Map, 0, len(rows))
	for _, r := range rows {
		net := r.TotalPayable - r.TotalPaid
		item := fiber.Map{
			"person_key":    r.PersonKey,
			"name":          r.Name,
			"gender":        r.Gender,
			"entry_count":   r.EntryCount,
			"total_cost":    net,
			"total_hours":   r.TotalHours,
			"total_payable": r.TotalPayable,
			"total_paid":    r.TotalPaid,
			"balance":       net,
			"last_date":     r.LastDate,
			"last_category": r.LastCategory,
			"last_location": r.LastLocation,
		}
		if r.Mobile != nil && strings.TrimSpace(*r.Mobile) != "" {
			item["mobile"] = strings.TrimSpace(*r.Mobile)
		}
		out = append(out, item)
	}
	return c.JSON(fiber.Map{"data": out, "total": len(out)})
}

// GetLaborBalancePublic handles GET /api/labors/balance?name=&mobile=
// Returns payable/paid/balance/receivable for one labourer.
func GetLaborBalancePublic(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	name := strings.TrimSpace(c.Query("name"))
	mobile := strings.TrimSpace(c.Query("mobile"))
	if name == "" && mobile == "" {
		return c.Status(400).JSON(fiber.Map{"error": "name or mobile is required"})
	}

	base := scopeByUserID(laborDB.Model(&models.Labor{}), uid)
	base = applyLaborPersonFilter(base, mobile, name)

	sumsQ := base.Session(&gorm.Session{})
	reset, hasReset := findLaborAccountReset(base.Session(&gorm.Session{}))
	seedPayable, seedPaid := 0.0, 0.0
	if hasReset {
		seedPayable, seedPaid = laborSeedFromReset(reset.Kind, reset.Amt)
		sumsQ = applyLaborAfterReset(sumsQ, reset)
	}

	type row struct {
		Payable float64 `gorm:"column:payable"`
		Paid    float64 `gorm:"column:paid"`
	}
	var r row
	if err := sumsQ.Select(fmt.Sprintf(`
		COALESCE(SUM(CASE WHEN %s THEN wage * hours ELSE 0 END),0)::float8 as payable,
		COALESCE(SUM(CASE WHEN entry_kind = 'payment' THEN wage * hours ELSE 0 END),0)::float8 as paid
	`, laborWorkKindSQL)).Scan(&r).Error; err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	balance := (seedPayable + r.Payable) - (seedPaid + r.Paid)
	payableShown := balance
	if payableShown < 0 {
		payableShown = 0
	}
	receivable := 0.0
	if balance < 0 {
		receivable = -balance
	}
	return c.JSON(fiber.Map{
		"payable":    payableShown,
		"paid":       seedPaid + r.Paid,
		"balance":    balance,
		"receivable": receivable,
	})
}

// GetLaborReportsPublic handles GET /api/labors/reports
// Labour-wise (or overall) monthly/weekly/category schedule summary.
// Query: year, month, months, mobile, name, category, work_type
func GetLaborReportsPublic(c *fiber.Ctx) error {
	uid, err := requireUserID(c)
	if err != nil {
		return err
	}
	now := time.Now()
	year := c.QueryInt("year", now.Year())
	month := c.QueryInt("month", int(now.Month()))
	trendMonths := c.QueryInt("months", 6)
	if trendMonths < 1 {
		trendMonths = 6
	}
	if trendMonths > 24 {
		trendMonths = 24
	}
	if month < 1 || month > 12 {
		return c.Status(400).JSON(fiber.Map{"error": "month must be 1-12"})
	}

	mobile := strings.TrimSpace(c.Query("mobile"))
	name := strings.TrimSpace(c.Query("name"))
	category := strings.TrimSpace(c.Query("category"))
	workType := strings.TrimSpace(c.Query("work_type"))

	base := scopeByUserID(laborDB.Model(&models.Labor{}), uid)
	base = applyLaborPersonFilter(base, mobile, name)
	if category != "" {
		base = base.Where("category ILIKE ?", "%"+category+"%")
	}
	if workType != "" {
		base = base.Where("work_type = ?", workType)
	}

	monthStart := time.Date(year, time.Month(month), 1, 0, 0, 0, 0, time.Local)
	monthEnd := monthStart.AddDate(0, 1, 0)
	trendStart := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.Local).
		AddDate(0, -(trendMonths - 1), 0)

	summary, err := laborAggSummary(base.Session(&gorm.Session{}))
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	monthSummary, err := laborAggSummary(
		base.Session(&gorm.Session{}).Where("date >= ? AND date < ?", monthStart, monthEnd),
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	monthly, err := laborMonthlySchedule(base.Session(&gorm.Session{}), trendStart, now)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	weekly, err := laborWeeklySchedule(base.Session(&gorm.Session{}), monthStart, monthEnd)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	byCategory, err := laborCategoryBreakdown(
		base.Session(&gorm.Session{}).Where("date >= ? AND date < ?", monthStart, monthEnd),
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}
	byShift, err := laborShiftBreakdown(
		base.Session(&gorm.Session{}).Where("date >= ? AND date < ?", monthStart, monthEnd),
	)
	if err != nil {
		return c.Status(500).JSON(fiber.Map{"error": err.Error()})
	}

	profile := fiber.Map{}
	if mobile != "" || name != "" {
		profile = laborPersonProfile(base.Session(&gorm.Session{}), mobile, name)
	}

	return c.JSON(fiber.Map{
		"year":          year,
		"month":         month,
		"month_label":   monthStart.Format("January 2006"),
		"mobile":        mobile,
		"name":          name,
		"profile":       profile,
		"summary":       summary,
		"month_summary": monthSummary,
		"monthly":       monthly,
		"weekly":        weekly,
		"by_category":   byCategory,
		"by_shift":      byShift,
	})
}

func applyLaborPersonFilter(q *gorm.DB, mobile, name string) *gorm.DB {
	if mobile != "" {
		return q.Where("mobile = ?", mobile)
	}
	if name != "" {
		return q.Where("LOWER(TRIM(name)) = ?", strings.ToLower(strings.TrimSpace(name)))
	}
	return q
}

type laborSumAgg struct {
	TotalCost    float64 `json:"total_cost"`
	TotalHours   float64 `json:"total_hours"`
	EntryCount   int64   `json:"entry_count"`
	AvgRate      float64 `json:"avg_rate"`
	TotalPayable float64 `json:"total_payable"`
	TotalPaid    float64 `json:"total_paid"`
	Balance      float64 `json:"balance"`
}

func laborAggSummary(q *gorm.DB) (laborSumAgg, error) {
	type row struct {
		TotalCost    float64 `gorm:"column:total_cost"`
		TotalHours   float64 `gorm:"column:total_hours"`
		EntryCount   int64   `gorm:"column:entry_count"`
		AvgRate      float64 `gorm:"column:avg_rate"`
		TotalPayable float64 `gorm:"column:total_payable"`
		TotalPaid    float64 `gorm:"column:total_paid"`
	}
	var r row
	err := q.Select(fmt.Sprintf(`
		%s as total_cost,
		COALESCE(SUM(CASE WHEN %s THEN hours ELSE 0 END),0)::float8 as total_hours,
		COUNT(*) FILTER (WHERE %s) as entry_count,
		COALESCE(AVG(CASE WHEN %s THEN wage END),0)::float8 as avg_rate,
		COALESCE(SUM(CASE WHEN %s THEN wage * hours ELSE 0 END),0)::float8 as total_payable,
		COALESCE(SUM(CASE WHEN entry_kind = 'payment' THEN wage * hours ELSE 0 END),0)::float8 as total_paid
	`, laborNetCostSQL(), laborWorkKindSQL, laborWorkKindSQL, laborWorkKindSQL, laborWorkKindSQL)).Scan(&r).Error
	return laborSumAgg{
		TotalCost:    r.TotalCost,
		TotalHours:   r.TotalHours,
		EntryCount:   r.EntryCount,
		AvgRate:      r.AvgRate,
		TotalPayable: r.TotalPayable,
		TotalPaid:    r.TotalPaid,
		Balance:      r.TotalPayable - r.TotalPaid,
	}, err
}

type laborPeriodRow struct {
	Year       int     `json:"year"`
	Month      int     `json:"month"`
	Label      string  `json:"label"`
	TotalCost  float64 `json:"total_cost"`
	TotalHours float64 `json:"total_hours"`
	Count      int64   `json:"count"`
}

func laborMonthlySchedule(q *gorm.DB, from, to time.Time) ([]laborPeriodRow, error) {
	type row struct {
		Y          int     `gorm:"column:y"`
		M          int     `gorm:"column:m"`
		TotalCost  float64 `gorm:"column:total_cost"`
		TotalHours float64 `gorm:"column:total_hours"`
		Count      int64   `gorm:"column:count"`
	}
	var rows []row
	err := q.Select(fmt.Sprintf(`
		EXTRACT(YEAR FROM date)::int as y,
		EXTRACT(MONTH FROM date)::int as m,
		%s as total_cost,
		COALESCE(SUM(CASE WHEN %s THEN hours ELSE 0 END),0)::float8 as total_hours,
		COUNT(*) FILTER (WHERE %s) as count
	`, laborNetCostSQL(), laborWorkKindSQL, laborWorkKindSQL)).
		Where("date >= ? AND date <= ?", from, to).
		Group("y, m").
		Order("y ASC, m ASC").
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	byKey := map[string]row{}
	for _, r := range rows {
		byKey[fmt.Sprintf("%d-%02d", r.Y, r.M)] = r
	}
	out := make([]laborPeriodRow, 0)
	cur := time.Date(from.Year(), from.Month(), 1, 0, 0, 0, 0, time.Local)
	end := time.Date(to.Year(), to.Month(), 1, 0, 0, 0, 0, time.Local)
	for !cur.After(end) {
		key := fmt.Sprintf("%d-%02d", cur.Year(), int(cur.Month()))
		r := byKey[key]
		out = append(out, laborPeriodRow{
			Year:       cur.Year(),
			Month:      int(cur.Month()),
			Label:      cur.Format("Jan 2006"),
			TotalCost:  r.TotalCost,
			TotalHours: r.TotalHours,
			Count:      r.Count,
		})
		cur = cur.AddDate(0, 1, 0)
	}
	return out, nil
}

type laborWeekRow struct {
	Week       int     `json:"week"`
	WeekStart  string  `json:"week_start"`
	WeekEnd    string  `json:"week_end"`
	Label      string  `json:"label"`
	TotalCost  float64 `json:"total_cost"`
	TotalHours float64 `json:"total_hours"`
	Count      int64   `json:"count"`
}

func laborWeeklySchedule(q *gorm.DB, monthStart, monthEnd time.Time) ([]laborWeekRow, error) {
	type row struct {
		WeekNum    int     `gorm:"column:week_num"`
		TotalCost  float64 `gorm:"column:total_cost"`
		TotalHours float64 `gorm:"column:total_hours"`
		Count      int64   `gorm:"column:count"`
	}
	var rows []row
	err := q.Select(fmt.Sprintf(`
		((EXTRACT(DAY FROM date)::int - 1) / 7) + 1 as week_num,
		%s as total_cost,
		COALESCE(SUM(CASE WHEN %s THEN hours ELSE 0 END),0)::float8 as total_hours,
		COUNT(*) FILTER (WHERE %s) as count
	`, laborNetCostSQL(), laborWorkKindSQL, laborWorkKindSQL)).
		Where("date >= ? AND date < ?", monthStart, monthEnd).
		Group("week_num").
		Order("week_num ASC").
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	byWeek := map[int]row{}
	for _, r := range rows {
		byWeek[r.WeekNum] = r
	}
	lastDay := monthEnd.AddDate(0, 0, -1).Day()
	maxWeek := ((lastDay - 1) / 7) + 1
	out := make([]laborWeekRow, 0, maxWeek)
	for w := 1; w <= maxWeek; w++ {
		startDay := (w-1)*7 + 1
		endDay := w * 7
		if endDay > lastDay {
			endDay = lastDay
		}
		ws := time.Date(monthStart.Year(), monthStart.Month(), startDay, 0, 0, 0, 0, time.Local)
		we := time.Date(monthStart.Year(), monthStart.Month(), endDay, 0, 0, 0, 0, time.Local)
		r := byWeek[w]
		out = append(out, laborWeekRow{
			Week:       w,
			WeekStart:  ws.Format("2006-01-02"),
			WeekEnd:    we.Format("2006-01-02"),
			Label:      fmt.Sprintf("Week %d (%s–%s)", w, ws.Format("2 Jan"), we.Format("2 Jan")),
			TotalCost:  r.TotalCost,
			TotalHours: r.TotalHours,
			Count:      r.Count,
		})
	}
	return out, nil
}

type laborCatRow struct {
	Category   string  `json:"category"`
	TotalCost  float64 `json:"total_cost"`
	TotalHours float64 `json:"total_hours"`
	Count      int64   `json:"count"`
	Pct        float64 `json:"pct"`
}

func laborCategoryBreakdown(q *gorm.DB) ([]laborCatRow, error) {
	type row struct {
		Category   string  `gorm:"column:category"`
		TotalCost  float64 `gorm:"column:total_cost"`
		TotalHours float64 `gorm:"column:total_hours"`
		Count      int64   `gorm:"column:count"`
	}
	var rows []row
	err := q.Where(laborWorkKindSQL).Select(`
		category,
		COALESCE(SUM(wage * hours),0)::float8 as total_cost,
		COALESCE(SUM(hours),0)::float8 as total_hours,
		COUNT(*) as count
	`).
		Group("category").
		Order("total_cost DESC").
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	var total float64
	for _, r := range rows {
		total += r.TotalCost
	}
	out := make([]laborCatRow, 0, len(rows))
	for _, r := range rows {
		pct := 0.0
		if total > 0 {
			pct = (r.TotalCost / total) * 100
		}
		out = append(out, laborCatRow{
			Category:   r.Category,
			TotalCost:  r.TotalCost,
			TotalHours: r.TotalHours,
			Count:      r.Count,
			Pct:        pct,
		})
	}
	return out, nil
}

type laborShiftRow struct {
	Shift      string  `json:"shift"`
	TotalCost  float64 `json:"total_cost"`
	TotalHours float64 `json:"total_hours"`
	Count      int64   `json:"count"`
}

func laborShiftBreakdown(q *gorm.DB) ([]laborShiftRow, error) {
	type row struct {
		Shift      string  `gorm:"column:shift"`
		TotalCost  float64 `gorm:"column:total_cost"`
		TotalHours float64 `gorm:"column:total_hours"`
		Count      int64   `gorm:"column:count"`
	}
	var rows []row
	err := q.Where(laborWorkKindSQL).Select(`
		shift,
		COALESCE(SUM(wage * hours),0)::float8 as total_cost,
		COALESCE(SUM(hours),0)::float8 as total_hours,
		COUNT(*) as count
	`).
		Group("shift").
		Order("total_cost DESC").
		Scan(&rows).Error
	if err != nil {
		return nil, err
	}
	out := make([]laborShiftRow, 0, len(rows))
	for _, r := range rows {
		out = append(out, laborShiftRow{
			Shift:      r.Shift,
			TotalCost:  r.TotalCost,
			TotalHours: r.TotalHours,
			Count:      r.Count,
		})
	}
	return out, nil
}

func laborPersonProfile(q *gorm.DB, mobile, name string) fiber.Map {
	type row struct {
		Name         string    `gorm:"column:name"`
		Mobile       *string   `gorm:"column:mobile"`
		Gender       string    `gorm:"column:gender"`
		LastDate     time.Time `gorm:"column:last_date"`
		LastCategory string    `gorm:"column:last_category"`
		LastLocation string    `gorm:"column:last_location"`
		LastWorkType string    `gorm:"column:last_work_type"`
		EntryCount   int64     `gorm:"column:entry_count"`
	}
	var r row
	_ = q.Select(`
		MAX(name) as name,
		MAX(mobile) as mobile,
		MAX(gender) as gender,
		MAX(date) as last_date,
		(ARRAY_AGG(category ORDER BY date DESC))[1] as last_category,
		(ARRAY_AGG(location ORDER BY date DESC))[1] as last_location,
		(ARRAY_AGG(work_type ORDER BY date DESC))[1] as last_work_type,
		COUNT(*) as entry_count
	`).Scan(&r).Error

	out := fiber.Map{
		"name":          r.Name,
		"gender":        r.Gender,
		"last_date":     r.LastDate,
		"last_category": r.LastCategory,
		"last_location": r.LastLocation,
		"last_work_type": r.LastWorkType,
		"entry_count":   r.EntryCount,
	}
	if mobile != "" {
		out["mobile"] = mobile
	} else if r.Mobile != nil {
		out["mobile"] = strings.TrimSpace(*r.Mobile)
	}
	if name != "" && r.Name == "" {
		out["name"] = name
	}
	return out
}
