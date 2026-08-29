package models

// AppFeature is a toggleable Flutter module the main account holder can
// disable for an individual family sub-member. All features are ON by default.
type AppFeature struct {
	Key   string `json:"key"`
	Label string `json:"label"`
}

// AppFeatures is the canonical list of options shown in the family-access UI.
var AppFeatures = []AppFeature{
	{Key: "income_expense", Label: "Income & Expense"},
	{Key: "organization", Label: "Manage Organization"},
	{Key: "labour", Label: "Labour Management"},
	{Key: "labour_work", Label: "Labour Work Entry"},
	{Key: "dairy", Label: "Dairy"},
	{Key: "dairy_owner", Label: "Dairy Owner"},
	{Key: "notes", Label: "Notes"},
	{Key: "daily_summary", Label: "Daily Summary"},
	{Key: "future_plans", Label: "Future Plans"},
	{Key: "market", Label: "Market Reports"},
	{Key: "weather", Label: "Weather Report"},
	{Key: "services", Label: "General Services"},
	{Key: "buy_sell", Label: "Buy & Sell"},
	{Key: "farmer_education", Label: "Farmer Education"},
	{Key: "achievers_lobby", Label: "Achievers Lobby"},
	{Key: "government", Label: "Government Facilities"},
	{Key: "rtc", Label: "RTC Entry"},
	{Key: "documents", Label: "Documents"},
	{Key: "event_manage", Label: "Event Manage"},
	{Key: "feedback", Label: "Feedback"},
	{Key: "profile", Label: "Profile"},
	{Key: "settings", Label: "Settings"},
}

func IsKnownAppFeature(key string) bool {
	for _, f := range AppFeatures {
		if f.Key == key {
			return true
		}
	}
	return false
}
