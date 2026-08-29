package middleware

import "testing"

func TestFeatureForPathDailySummaryAndDairy(t *testing.T) {
	cases := map[string]string{
		"/api/daily_summary":          "daily_summary",
		"/api/dairy/entries":          "dairy",
		"/api/dairy/owner/entries":    "dairy_owner",
		"/api/dairy/owner/summary":    "dairy_owner",
		"/api/income_expense/summary": "income_expense",
		"/api/diary/entries":          "notes",
	}
	for path, want := range cases {
		if got := featureForPath(path); got != want {
			t.Fatalf("featureForPath(%q)=%q want %q", path, got, want)
		}
	}
}
