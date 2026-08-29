package handler

import (
	"testing"

	"erp.local/backend/models"
)

func TestNormalizeLaborEntryKind(t *testing.T) {
	cases := map[string]string{
		"":        "payable",
		"paid":    "payment",
		"PAYMENT": "payment",
		"tally":   "tally",
		"opening": "opening",
		"payable": "payable",
	}
	for in, want := range cases {
		got := normalizeLaborEntryKind(in)
		if got != want {
			t.Fatalf("normalizeLaborEntryKind(%q)=%q want %q", in, got, want)
		}
	}
}

func TestIsLaborWorkKind(t *testing.T) {
	work := map[string]bool{
		"":        true,
		"payable": true,
		"opening": false,
		"OPENING": false,
		"payment": false,
		"paid":    false,
		"tally":   false,
	}
	for in, want := range work {
		if got := isLaborWorkKind(in); got != want {
			t.Fatalf("isLaborWorkKind(%q)=%v want %v", in, got, want)
		}
	}
}

func TestLaborScheduleTotalsIgnorePayments(t *testing.T) {
	// Matches the labourer-detail bug: monthly cost was summing payments
	// with work (₹9,225) instead of work only (₹5,225). Remaining payable
	// is work − paid = ₹1,225.
	type row struct {
		kind        string
		wage, hours float64
	}
	rows := []row{
		{"payable", 500, 9.5},
		{"payable", 475, 1},
		{"payment", 4000, 1},
		{"tally", 0, 1},
	}
	var cost, hours float64
	var n int
	var naive float64
	for _, r := range rows {
		amt := r.wage * r.hours
		if normalizeLaborEntryKind(r.kind) != "tally" {
			naive += amt
		}
		if !isLaborWorkKind(r.kind) {
			continue
		}
		cost += amt
		hours += r.hours
		n++
	}
	if cost != 5225 || hours != 10.5 || n != 2 {
		t.Fatalf("work totals cost=%v hours=%v n=%d want 5225 / 10.5 / 2", cost, hours, n)
	}
	if naive != 9225 {
		t.Fatalf("old (buggy) all-but-tally sum=%v want 9225", naive)
	}
	net := cost
	for _, r := range rows {
		if normalizeLaborEntryKind(r.kind) == "payment" {
			net -= r.wage * r.hours
		}
	}
	if net != 1225 {
		t.Fatalf("net credit-debit=%v want 1225", net)
	}
}

func TestValidateLaborTally(t *testing.T) {
	body := laborPayload{
		Name:      "Ramu",
		EntryKind: "tally",
		Narration: "Settled up to today",
		Date:      flexibleTime{},
	}
	// zero date should fail
	if msg := validateLaborPayload(&body); msg == "" {
		t.Fatal("expected date required for tally")
	}
	body.Date.Time = body.Date.Time.AddDate(2026, 0, 0) // still zero-ish; set properly below
	body.Date.UnmarshalJSON([]byte(`"2026-08-16"`))
	if msg := validateLaborPayload(&body); msg != "" {
		t.Fatalf("unexpected tally validation error: %s", msg)
	}
	if body.Wage != 0 || body.Category != "Tally" {
		t.Fatalf("tally defaults wrong: wage=%v cat=%s", body.Wage, body.Category)
	}
}

func TestValidateLaborOpeningAllowsDebit(t *testing.T) {
	body := laborPayload{
		Name:      "Ramu",
		EntryKind: "opening",
		Wage:      -2000,
		Narration: "Extra already paid",
	}
	_ = body.Date.UnmarshalJSON([]byte(`"2026-08-16"`))
	if msg := validateLaborPayload(&body); msg != "" {
		t.Fatalf("debit opening should be allowed: %s", msg)
	}
	if body.EntryKind != "opening" || body.Wage != -2000 {
		t.Fatalf("opening debit mutated: kind=%s wage=%v", body.EntryKind, body.Wage)
	}
}

func TestValidateLaborOpeningZeroBecomesTally(t *testing.T) {
	body := laborPayload{
		Name:      "Ramu",
		EntryKind: "opening",
		Wage:      0,
		Narration: "Settled",
	}
	_ = body.Date.UnmarshalJSON([]byte(`"2026-08-16"`))
	if msg := validateLaborPayload(&body); msg != "" {
		t.Fatalf("zero opening should coerce to tally: %s", msg)
	}
	if body.EntryKind != "tally" || body.Wage != 0 {
		t.Fatalf("expected tally, got kind=%s wage=%v", body.EntryKind, body.Wage)
	}
}

func TestLaborSeedFromReset(t *testing.T) {
	p, d := laborSeedFromReset("tally", 0)
	if p != 0 || d != 0 {
		t.Fatalf("tally seed payable=%v paid=%v want 0/0", p, d)
	}
	p, d = laborSeedFromReset("opening", 5000)
	if p != 5000 || d != 0 {
		t.Fatalf("credit opening seed payable=%v paid=%v want 5000/0", p, d)
	}
	p, d = laborSeedFromReset("opening", -2000)
	if p != 0 || d != 2000 {
		t.Fatalf("debit opening seed payable=%v paid=%v want 0/2000", p, d)
	}
}

func TestIsLaborResetKind(t *testing.T) {
	if !isLaborResetKind("tally") || !isLaborResetKind("opening") {
		t.Fatal("tally and opening should reset the account")
	}
	if isLaborResetKind("payable") || isLaborResetKind("payment") {
		t.Fatal("work and payment should not be reset markers")
	}
}

func TestValidateLaborPayable(t *testing.T) {
	body := laborPayload{
		Name:     "Ramu",
		Wage:     500,
		Hours:    1,
		Shift:    "fullday",
		Category: "Plucking",
		Gender:   "Male",
		WorkType: "Daily Wages",
		Location: "Farm",
		Rent:     50,
		Food:     20,
		Bonus:    10,
	}
	_ = body.Date.UnmarshalJSON([]byte(`"2026-08-16"`))
	if msg := validateLaborPayload(&body); msg != "" {
		t.Fatalf("payable validation failed: %s", msg)
	}
}

func TestNormalizeLaborWorkKind(t *testing.T) {
	if normalizeLaborWorkKind("") != "receivable" {
		t.Fatal("default should be receivable")
	}
	if normalizeLaborWorkKind("payment") != "receipt" {
		t.Fatal("payment should map to receipt")
	}
}

func TestLast10Phone(t *testing.T) {
	cases := map[string]string{
		"9876543210":      "9876543210",
		"+91 98765 43210": "9876543210",
		"919876543210":    "9876543210",
		"12345":           "12345",
		"":                "",
	}
	for in, want := range cases {
		if got := last10Phone(in); got != want {
			t.Fatalf("last10Phone(%q)=%q want %q", in, got, want)
		}
	}
}

func TestReverseLaborKind(t *testing.T) {
	if reverseLaborKind("payable") != "receivable" {
		t.Fatal("payable should reverse to receivable")
	}
	if reverseLaborKind("opening") != "receivable" {
		t.Fatal("opening should reverse to receivable")
	}
	if reverseLaborKind("payment") != "receipt" {
		t.Fatal("payment should reverse to receipt")
	}
	if reverseLaborKind("paid") != "receipt" {
		t.Fatal("paid should reverse to receipt")
	}
}

func TestUserDisplayName(t *testing.T) {
	u := models.User{Firstname: "Rama", Lastname: "Gowda"}
	if userDisplayName(u) != "Rama Gowda" {
		t.Fatalf("got %q", userDisplayName(u))
	}
	u = models.User{Email: "a@b.com"}
	if userDisplayName(u) != "a@b.com" {
		t.Fatalf("got %q", userDisplayName(u))
	}
}
