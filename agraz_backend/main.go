package main

import (
	"fmt"
	"log"
	"os"

	handler "erp.local/backend/handlers"
	"erp.local/backend/initializers"
	"erp.local/backend/middleware"
	"erp.local/backend/models"
	"erp.local/backend/seeds"
	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/recover"
)

func init() {

	initializers.LoadEnviromentVariables()
	initializers.ConnectToDb()
	// Ensure e-commerce tables exist on startup.
	// This project uses AutoMigrate only in a separate migration entrypoint today,
	// so we keep e-commerce initialization self-contained for the shopping cart feature.
	_ = initializers.DB.AutoMigrate(
		&models.Tenant{},
		&models.User{},
		&models.PasswordResetCode{},
		&models.UserRoleMapping{},
		&models.ServiceRegistration{},
		&models.Vendor{},
		&models.Labor{},
		&models.LaborRate{},
		&models.LaborExtra{},
		&models.DiaryLabel{},
		&models.DiaryListItem{},
		&models.DiaryEntry{},
		&models.DairyCustomer{},
		&models.DairyEntry{},
		&models.FuturePlan{},
		&models.FuturePlanLine{},
		&models.LaborWorkEntry{},
		&models.LaborShare{},
		&models.IncomeExpense{},
		&models.Organization{},
		&models.OrgLedger{},
		&models.OrgTransaction{},
		&models.AppFeedback{},
		&models.AppContent{},
		&models.EcomCategory{},
		&models.EcomSubCategory{},
		&models.EcomProduct{},
		&models.EcomProductCategory{},
		&models.VendorProductMapping{},
		&models.EcomColor{},
		&models.EcomVariant{},
		&models.EcomProductImage{},
		&models.EcomStockMovement{},
		&models.EcomCart{},
		&models.EcomCartItem{},
		&models.StorefrontBannerSlide{},
		&models.GovDepartment{},
		&models.GovCrop{},
		&models.GovFacility{},
		&models.MarketAgent{},
		&models.MarketAPMC{},
		&models.MarketVariety{},
		&models.MarketDailyPrice{},
		&models.MarketLot{},
		&models.MarketQuantity{},
		&models.LandRtc{},
		&models.DocumentFolder{},
		&models.UserDocument{},
		&models.ManagedEvent{},
		&models.WeatherReport{},
		&models.WeatherDaily{},
		&models.AchieversLobbyCategory{},
		&models.AchieversLobbyItem{},
	)
	seeds.SeedAll()
}

// func welcome(c *fiber.Ctx) error {
// 	return c.SendString("Welcome to app")
// }

func main() {
	fmt.Println("Hello welcome, main is runnings")

	// Set DB in handlers
	handler.SetUserDB(initializers.DB)
	handler.SetRolesDB(initializers.DB)
	handler.SetRolesManagementDB(initializers.DB)
	handler.SetMenusDB(initializers.DB)
	handler.SetUserRoleMappingDB(initializers.DB)
	handler.SetEmployeeDB(initializers.DB)
	handler.SetIncomeExpenseDB(initializers.DB)
	handler.SetOrganizationDB(initializers.DB)
	handler.SetFeedbackDB(initializers.DB)
	handler.SetAppContentDB(initializers.DB)
	handler.SetLaborDB(initializers.DB)
	handler.SetLaborRateDB(initializers.DB)
	handler.SetDiaryDB(initializers.DB)
	handler.SetDairyDB(initializers.DB)
	handler.SetFuturePlanDB(initializers.DB)
	handler.SetLaborWorkDB(initializers.DB)
	handler.SetServiceRegistrationDB(initializers.DB)
	handler.SetEcomDB(initializers.DB)
	handler.SetVendorDB(initializers.DB)
	handler.SetStorefrontBannerDB(initializers.DB)
	handler.SetGovDB(initializers.DB)
	handler.SetMarketDB(initializers.DB)
	handler.SetLandRtcDB(initializers.DB)
	handler.SetDocumentDB(initializers.DB)
	handler.SetEventDB(initializers.DB)
	handler.SetWeatherDB(initializers.DB)
	handler.SetAchieversLobbyDB(initializers.DB)
	handler.StartWeatherScheduler()

	// set up fiber (large body limit for multi-image uploads)
	app := fiber.New(fiber.Config{
		BodyLimit: 128 * 1024 * 1024,
	})
	app.Use(recover.New())

	app.Use(cors.New(cors.Config{
		AllowOrigins: "*",
		AllowMethods: "GET,POST,PUT,PATCH,DELETE,OPTIONS,HEAD",
		AllowHeaders: "Origin, Content-Type, Accept, Authorization, X-Tenant-ID",
	}))

	app.Static("/uploads", "./uploads")

	api := app.Group("/api")
	api.Use(middleware.TenantResolver(initializers.DB))

	// Public Routes
	api.Get("/tenant/config", handler.GetTenantConfig)
	api.Post("/login", handler.Login)
	api.Post("/login/", handler.Login)

	// Agraz / Flutter mobile (public JSON API; same DB as admin)
	api.Post("/mobile/register", handler.MobileRegisterUser)
	api.Post("/forgot-password", handler.ForgotPassword)
	api.Post("/verify-reset-code", handler.VerifyResetCode)
	api.Post("/reset-password", handler.ResetPasswordWithCode)
	api.Post("/mobile/forgot-password", handler.ForgotPassword)
	api.Post("/mobile/verify-reset-code", handler.VerifyResetCode)
	api.Post("/mobile/reset-password", handler.ResetPasswordWithCode)
	api.Get("/mobile/users/by-phone/:phone", handler.GetUserByMobilePublic)
	api.Post("/register-business", handler.RegisterBusinessPublic)
	api.Get("/services", handler.ListApprovedServicesPublic)

	// Public storefront catalog (no JWT; same data admin manages)
	api.Get("/store/categories", handler.GetStoreCategories)
	api.Get("/store/sub-categories", handler.GetStoreSubCategories)
	api.Get("/store/colors", handler.GetStoreColors)
	api.Get("/store/products", handler.GetStoreProducts)
	api.Get("/store/products/:id", handler.GetStoreProductByID)
	api.Get("/store/vendors", handler.GetStoreVendors)
	api.Get("/store/banners", handler.GetStoreBannersPublic)

	// Government facilities (public browse for Flutter)
	api.Get("/gov/departments", handler.GetGovDepartments)
	api.Get("/gov/crops", handler.GetGovCrops)
	api.Get("/gov/categories", handler.GetGovCategories)
	api.Get("/gov/facilities", handler.GetGovFacilities)
	api.Get("/gov/facilities/:id", handler.GetGovFacility)

	// Market reports (public browse / filters for Flutter app)
	api.Get("/market/agents", handler.GetMarketAgentsPublic)
	api.Get("/market/apmcs", handler.GetMarketAPMCsPublic)
	api.Get("/market/varieties", handler.GetMarketVarietiesPublic)
	api.Get("/market/taluks", handler.GetMarketTaluksPublic)
	api.Get("/market/daily-prices", handler.GetMarketDailyPricesPublic)
	api.Get("/market/lots", handler.GetMarketLotsPublic)
	api.Get("/market/quantities", handler.GetMarketQuantitiesPublic)
	api.Get("/market/analytics", handler.GetMarketAnalyticsPublic)

	// Weather report (public read; scrape runs every 8 hours in-process + cron)
	api.Get("/weather", handler.GetWeatherReportPublic)
	api.Get("/weather/locations", handler.GetWeatherLocationsPublic)
	api.Get("/weather/cron", handler.WeatherCronRefresh)
	api.Post("/weather/cron", handler.WeatherCronRefresh)

	// Achievers Lobby (public browse + anyone can submit a video for approval)
	api.Get("/achievers-lobby/latest", handler.GetLatestAchieversLobbyPublic)
	api.Get("/achievers-lobby/categories", handler.ListAchieversLobbyCategoriesPublic)
	api.Get("/achievers-lobby", handler.ListAchieversLobbyPublic)
	api.Get("/achievers-lobby/:id", handler.GetAchieversLobbyPublic)
	api.Post("/achievers-lobby/upload", handler.UploadAchieversLobbyVideoPublic)
	api.Post("/achievers-lobby/submit", handler.SubmitAchieversLobbyPublic)

	// Use Middleware
	api.Use(middleware.Protected())
	api.Use(middleware.FamilyScope())

	// Authenticated Routes
	api.Get("/me", handler.GetMe)
	api.Put("/me", handler.UpdateMe)
	api.Put("/me/password", handler.ChangeMyPassword)
	api.Get("/my-menus", handler.GetCurrentUserMenuTree)
	api.Get("/dashboard/stats", handler.GetDashboardStats)

	api.Get("/family/features", handler.ListAppFeatures)
	api.Get("/family/members", handler.ListFamilyMembers)
	api.Post("/family/members", handler.CreateFamilyMember)
	api.Put("/family/members/:id", handler.UpdateFamilyMember)
	api.Delete("/family/members/:id", handler.DeleteFamilyMember)

	// Income & expense (per logged-in user)
	api.Get("/income_expense/summary", handler.GetIncomeExpenseSummaryPublic)
	api.Get("/income_expense/reports", handler.GetIncomeExpenseReportsPublic)
	api.Get("/income_expense/balance/:mobile", handler.GetPartyBalancePublic)
	api.Get("/income_expense/mobile/:mobile", handler.GetIncomeExpensesByMobilePublic)
	api.Get("/income_expense", handler.GetIncomeExpenses)
	api.Get("/income_expense/:id", handler.GetIncomeExpense)
	api.Post("/income_expense", handler.CreateIncomeExpenseMobile)
	api.Put("/income_expense/:id", handler.UpdateIncomeExpenseMobile)
	api.Delete("/income_expense/:id", handler.DeleteIncomeExpense)

	// Organizations & ledgers (per logged-in user)
	api.Get("/organizations", handler.ListOrganizations)
	api.Post("/organizations", handler.CreateOrganization)
	api.Put("/organizations/:id", handler.UpdateOrganization)
	api.Delete("/organizations/:id", handler.DeleteOrganization)
	api.Get("/org_ledgers", handler.ListOrgLedgers)
	api.Post("/org_ledgers", handler.CreateOrgLedger)
	api.Put("/org_ledgers/:id", handler.UpdateOrgLedger)
	api.Delete("/org_ledgers/:id", handler.DeleteOrgLedger)
	api.Get("/org_transactions/summary", handler.GetOrgSummary)
	api.Get("/org_transactions/reports", handler.GetOrgReports)
	api.Get("/org_transactions", handler.ListOrgTransactions)
	api.Post("/org_transactions", handler.CreateOrgTransaction)
	api.Delete("/org_transactions/:id", handler.DeleteOrgTransaction)

	// Feedback (auth)
	api.Post("/feedbacks", handler.CreateFeedback)
	api.Get("/feedbacks", handler.ListMyFeedback)
	api.Get("/feedbacks/all", handler.ListAllFeedbackPublic)

	// App content CMS (auth; active list)
	api.Get("/app_contents", handler.ListAppContentsPublic)
	api.Get("/app_contents/:menu_key", handler.GetAppContentByKey)

	// Labor management (per logged-in user)
	api.Get("/labors/people", handler.GetLaborPeoplePublic)
	api.Get("/labors/reports", handler.GetLaborReportsPublic)
	api.Get("/labors/balance", handler.GetLaborBalancePublic)
	api.Put("/labors/bulk-rate", handler.BulkUpdateLaborRate)
	api.Get("/labors", handler.GetLabors)
	api.Post("/labors/batch", handler.CreateLaborsBatch)
	api.Post("/labors", handler.CreateLabor)
	api.Get("/labors/:id", handler.GetLabor)
	api.Put("/labors/:id", handler.UpdateLabor)
	api.Delete("/labors/:id", handler.DeleteLabor)
	api.Get("/labor_rates", handler.GetLaborRates)
	api.Put("/labor_rates", handler.UpsertLaborRates)

	// Notes & lists
	api.Get("/diary/labels", handler.ListDiaryLabels)
	api.Post("/diary/labels", handler.CreateDiaryLabel)
	api.Put("/diary/labels/:id", handler.UpdateDiaryLabel)
	api.Delete("/diary/labels/:id", handler.DeleteDiaryLabel)
	api.Get("/diary/list-items", handler.ListDiaryListItems)
	api.Post("/diary/list-items", handler.CreateDiaryListItem)
	api.Put("/diary/list-items/:id", handler.UpdateDiaryListItem)
	api.Delete("/diary/list-items/:id", handler.DeleteDiaryListItem)
	api.Get("/diary/list_items", handler.ListDiaryListItems)
	api.Post("/diary/list_items", handler.CreateDiaryListItem)
	api.Put("/diary/list_items/:id", handler.UpdateDiaryListItem)
	api.Delete("/diary/list_items/:id", handler.DeleteDiaryListItem)
	api.Get("/diary/entries", handler.ListDiaryEntries)
	api.Post("/diary/entries", handler.CreateDiaryEntry)
	api.Put("/diary/entries/:id", handler.UpdateDiaryEntry)
	api.Delete("/diary/entries/:id", handler.DeleteDiaryEntry)

	// Dairy (milk ledger). Farmer page auto-includes dairy-owner entries by mobile.
	api.Get("/dairy/summary", handler.GetDairySummary)
	api.Get("/dairy/entries", handler.ListDairyEntries)
	api.Post("/dairy/entries", handler.CreateDairyEntry)
	api.Put("/dairy/entries/:id", handler.UpdateDairyEntry)
	api.Delete("/dairy/entries/:id", handler.DeleteDairyEntry)
	api.Get("/dairy/owner/customers", handler.ListDairyCustomers)
	api.Post("/dairy/owner/customers", handler.CreateDairyCustomer)
	api.Put("/dairy/owner/customers/:id", handler.UpdateDairyCustomer)
	api.Delete("/dairy/owner/customers/:id", handler.DeleteDairyCustomer)
	api.Get("/dairy/owner/summary", handler.GetOwnerDairySummary)
	api.Get("/dairy/owner/entries", handler.ListOwnerDairyEntries)
	api.Post("/dairy/owner/entries", handler.CreateOwnerDairyEntry)
	api.Put("/dairy/owner/entries/:id", handler.UpdateOwnerDairyEntry)
	api.Delete("/dairy/owner/entries/:id", handler.DeleteOwnerDairyEntry)

	// Future plans
	api.Get("/future_plans", handler.ListFuturePlans)
	api.Post("/future_plans", handler.CreateFuturePlan)
	api.Get("/future_plans/:id", handler.GetFuturePlan)
	api.Put("/future_plans/:id", handler.UpdateFuturePlan)
	api.Delete("/future_plans/:id", handler.DeleteFuturePlan)

	// Labour self work-entry (receivable / receipt)
	// Reverse labour confirmation (farmer → labourer)
	api.Get("/labor_shares/pending_count", handler.CountPendingLaborShares)
	api.Get("/labor_shares", handler.ListLaborShares)
	api.Post("/labor_shares/:id/accept", handler.AcceptLaborShare)
	api.Post("/labor_shares/:id/reject", handler.RejectLaborShare)

	api.Get("/labor_works/reports", handler.GetLaborWorkReportsPublic)
	api.Get("/labor_works", handler.GetLaborWorks)
	api.Post("/labor_works/batch", handler.CreateLaborWorksBatch)
	api.Post("/labor_works", handler.CreateLaborWork)
	api.Get("/labor_works/:id", handler.GetLaborWork)
	api.Put("/labor_works/:id", handler.UpdateLaborWork)
	api.Delete("/labor_works/:id", handler.DeleteLaborWork)

	// Land RTC / Karnataka land records (per logged-in user)
	api.Post("/land_rtcs/upload", handler.UploadLandRtcDocument)
	api.Get("/land_rtcs", handler.ListMyLandRtcs)
	api.Get("/land_rtcs/:id", handler.GetMyLandRtc)
	api.Post("/land_rtcs", handler.CreateLandRtc)
	api.Put("/land_rtcs/:id", handler.UpdateLandRtc)
	api.Delete("/land_rtcs/:id", handler.DeleteLandRtc)

	// Personal documents (Aadhaar, PAN, etc.) — folders + multi-image papers
	api.Post("/documents/upload", handler.UploadDocumentImages)
	api.Get("/documents/browse", handler.BrowseDocuments)
	api.Post("/documents/folders", handler.CreateDocumentFolder)
	api.Put("/documents/folders/:id", handler.UpdateDocumentFolder)
	api.Delete("/documents/folders/:id", handler.DeleteDocumentFolder)
	api.Get("/documents/:id", handler.GetUserDocument)
	api.Post("/documents", handler.CreateUserDocument)
	api.Put("/documents/:id", handler.UpdateUserDocument)
	api.Delete("/documents/:id", handler.DeleteUserDocument)

	// Event manage (birthdays, insurance renewals, etc.)
	api.Get("/events", handler.ListEvents)
	api.Post("/events", handler.CreateEvent)
	api.Put("/events/:id", handler.UpdateEvent)
	api.Delete("/events/:id", handler.DeleteEvent)

	// Users
	api.Get("/vendor-users", handler.GetVendorUsers)
	api.Post("/users", handler.CreateUser)
	api.Get("/users", handler.GetUsers)
	api.Get("/users/:id", handler.GetUser)
	api.Put("/users/:id", handler.UpdateUser)
	api.Delete("/users/:id", handler.DeleteUser)
	api.Put("/users/restore/:id", handler.RestoreUser)
	api.Delete("/users/force/:id", handler.ForceDeleteUser)
	api.Post("/users/import", handler.ImportUsers)

	// Menus
	api.Get("/loadMenus", handler.GetAllMenus)
	api.Get("/menus/tree", handler.GetMenuTree)
	api.Get("/menus/:id", handler.GetMenuByID)
	api.Post("/menus", handler.CreateMenu)
	api.Put("/menus/:id", handler.UpdateMenu)
	api.Delete("/menus/:id", handler.DeleteMenu)
	api.Patch("/menus/reorder", handler.ReorderMenus)

	// Roles
	api.Get("/roles", handler.GetAllRoles)
	api.Get("/roles/:id", handler.GetRoleByID)
	api.Post("/roles", handler.CreateRole)
	api.Put("/roles/:id", handler.UpdateRole)
	api.Delete("/roles/:id", handler.DeleteRole)

	// Role permissions
	api.Get("/roles/:id/permissions", handler.GetRolePermissions)
	api.Get("/roles/:id/permissions/menu-tree", handler.GetRoleMenuTreeWithPermissions)
	api.Put("/roles/:id/permissions", handler.UpdateRolePermissions)
	api.Delete("/roles/:id/permissions", handler.ResetRolePermissions)

	// User-Role mapping
	api.Get("/user/:user_id", handler.GetUserRoles)
	api.Post("/user/:user_id/role/:role_id", handler.AssignRoleToUser)
	api.Delete("/user/:user_id/role/:role_id", handler.RemoveRoleFromUser)
	api.Get("/role/:role_id/users", handler.GetUsersByRole)
	api.Put("/user/:user_id", handler.UpdateUserRoles)

	// Employees
	api.Get("/employees", handler.GetEmployees)
	api.Get("/employees/:id", handler.GetEmployee)
	api.Post("/employees", handler.CreateEmployee)
	api.Put("/employees/:id", handler.UpdateEmployee)
	api.Delete("/employees/:id", handler.DeleteEmployee)

	// Income & expenses
	api.Get("/income-expenses", handler.GetIncomeExpenses)
	api.Get("/income-expenses/:id", handler.GetIncomeExpense)
	api.Post("/income-expenses", handler.CreateIncomeExpense)
	api.Put("/income-expenses/:id", handler.UpdateIncomeExpense)
	api.Delete("/income-expenses/:id", handler.DeleteIncomeExpense)

	// Service registrations (static paths before :id)
	api.Get("/service-registrations", handler.GetServiceRegistrations)
	api.Post("/service-registrations/images", handler.UploadServiceRegistrationImages)
	api.Post("/service-registrations/:id/provider-photo", handler.UploadServiceProviderPhoto)
	api.Post("/service-registrations/:id/custom-service-image", handler.UploadCustomServiceImage)
	api.Get("/service-registrations/:id", handler.GetServiceRegistration)
	api.Post("/service-registrations", handler.CreateServiceRegistration)
	api.Put("/service-registrations/:id", handler.UpdateServiceRegistration)
	api.Delete("/service-registrations/:id/images", handler.RemoveServiceRegistrationImage)
	api.Delete("/service-registrations/:id", handler.DeleteServiceRegistration)

	// Vendors (static paths before :id)
	api.Get("/vendor-product-mappings", handler.GetVendorProductMappings)
	api.Post("/vendor-product-mappings", handler.CreateVendorProductMapping)
	api.Put("/vendor-product-mappings/:id", handler.UpdateVendorProductMapping)
	api.Delete("/vendor-product-mappings/:id", handler.DeleteVendorProductMapping)

	api.Get("/vendors", handler.GetVendors)
	api.Post("/vendors", handler.CreateVendor)
	api.Put("/vendors/:id/product-mappings", handler.ReplaceVendorProductMappings)
	api.Get("/vendors/:id", handler.GetVendor)
	api.Put("/vendors/:id", handler.UpdateVendor)
	api.Delete("/vendors/:id", handler.DeleteVendor)

	// Store cart (requires login — storefront uses local cart)
	api.Get("/store/cart", handler.GetStoreCart)
	api.Post("/store/cart/items", handler.AddStoreCartItem)
	api.Put("/store/cart/items/:variant_id", handler.UpdateStoreCartItem)
	api.Delete("/store/cart/items/:variant_id", handler.DeleteStoreCartItem)

	// Admin e-commerce (catalog management)
	api.Get("/admin/ecom/categories", handler.AdminGetCategories)
	api.Get("/admin/ecom/categories/:id", handler.AdminGetCategory)
	api.Post("/admin/ecom/categories", handler.AdminCreateCategory)
	api.Put("/admin/ecom/categories/:id", handler.AdminUpdateCategory)
	api.Delete("/admin/ecom/categories/:id", handler.AdminDeleteCategory)

	api.Get("/admin/ecom/sub-categories", handler.AdminGetSubCategories)
	api.Get("/admin/ecom/sub-categories/:id", handler.AdminGetSubCategory)
	api.Post("/admin/ecom/sub-categories", handler.AdminCreateSubCategory)
	api.Put("/admin/ecom/sub-categories/:id", handler.AdminUpdateSubCategory)
	api.Delete("/admin/ecom/sub-categories/:id", handler.AdminDeleteSubCategory)

	api.Get("/admin/ecom/colors", handler.AdminGetColors)
	api.Get("/admin/ecom/colors/:id", handler.AdminGetColor)
	api.Post("/admin/ecom/colors", handler.AdminCreateColor)
	api.Put("/admin/ecom/colors/:id", handler.AdminUpdateColor)
	api.Delete("/admin/ecom/colors/:id", handler.AdminDeleteColor)

	api.Get("/admin/ecom/products", handler.AdminGetProducts)
	api.Get("/admin/ecom/products/:id", handler.AdminGetProduct)
	api.Post("/admin/ecom/products", handler.AdminCreateProduct)
	api.Put("/admin/ecom/products/:id", handler.AdminUpdateProduct)
	api.Delete("/admin/ecom/products/:id", handler.AdminDeleteProduct)

	// Admin e-commerce image upload (expects already-cropped image)
	api.Post("/admin/ecom/images/upload", handler.UploadAdminEcomImage)

	api.Get("/admin/storefront/banners", handler.AdminListStorefrontBanners)
	api.Post("/admin/storefront/banners", handler.AdminCreateStorefrontBanner)
	api.Put("/admin/storefront/banners/reorder", handler.AdminReorderStorefrontBanners)
	api.Put("/admin/storefront/banners/:id", handler.AdminUpdateStorefrontBanner)
	api.Delete("/admin/storefront/banners/:id", handler.AdminDeleteStorefrontBanner)

	// Admin government facilities
	api.Get("/admin/gov/departments", handler.AdminGetGovDepartments)
	api.Post("/admin/gov/departments", handler.AdminCreateGovDepartment)
	api.Put("/admin/gov/departments/:id", handler.AdminUpdateGovDepartment)
	api.Delete("/admin/gov/departments/:id", handler.AdminDeleteGovDepartment)

	api.Get("/admin/gov/crops", handler.AdminGetGovCrops)
	api.Post("/admin/gov/crops", handler.AdminCreateGovCrop)
	api.Put("/admin/gov/crops/:id", handler.AdminUpdateGovCrop)
	api.Delete("/admin/gov/crops/:id", handler.AdminDeleteGovCrop)

	api.Get("/admin/gov/facilities", handler.AdminGetGovFacilities)
	api.Get("/admin/gov/facilities/:id", handler.AdminGetGovFacility)
	api.Post("/admin/gov/facilities", handler.AdminCreateGovFacility)
	api.Put("/admin/gov/facilities/:id", handler.AdminUpdateGovFacility)
	api.Delete("/admin/gov/facilities/:id", handler.AdminDeleteGovFacility)
	api.Post("/admin/gov/facilities/upload", handler.UploadGovFacilityApplication)

	// Admin market reports
	api.Get("/admin/market/agents", handler.AdminListMarketAgents)
	api.Post("/admin/market/agents", handler.AdminCreateMarketAgent)
	api.Put("/admin/market/agents/:id", handler.AdminUpdateMarketAgent)
	api.Delete("/admin/market/agents/:id", handler.AdminDeleteMarketAgent)

	api.Get("/admin/market/apmcs", handler.AdminListMarketAPMCs)
	api.Post("/admin/market/apmcs", handler.AdminCreateMarketAPMC)
	api.Put("/admin/market/apmcs/:id", handler.AdminUpdateMarketAPMC)
	api.Delete("/admin/market/apmcs/:id", handler.AdminDeleteMarketAPMC)

	api.Get("/admin/market/varieties", handler.AdminListMarketVarieties)
	api.Post("/admin/market/varieties", handler.AdminCreateMarketVariety)
	api.Put("/admin/market/varieties/:id", handler.AdminUpdateMarketVariety)
	api.Delete("/admin/market/varieties/:id", handler.AdminDeleteMarketVariety)

	api.Get("/admin/market/daily-prices", handler.AdminListMarketDailyPrices)
	api.Post("/admin/market/daily-prices", handler.AdminCreateMarketDailyPrice)
	api.Put("/admin/market/daily-prices/:id", handler.AdminUpdateMarketDailyPrice)
	api.Delete("/admin/market/daily-prices/:id", handler.AdminDeleteMarketDailyPrice)

	api.Get("/admin/market/lots", handler.AdminListMarketLots)
	api.Post("/admin/market/lots", handler.AdminCreateMarketLot)
	api.Put("/admin/market/lots/:id", handler.AdminUpdateMarketLot)
	api.Delete("/admin/market/lots/:id", handler.AdminDeleteMarketLot)

	api.Get("/admin/market/quantities", handler.AdminListMarketQuantities)
	api.Post("/admin/market/quantities", handler.AdminCreateMarketQuantity)
	api.Put("/admin/market/quantities/:id", handler.AdminUpdateMarketQuantity)
	api.Delete("/admin/market/quantities/:id", handler.AdminDeleteMarketQuantity)

	api.Get("/admin/market/analytics", handler.GetMarketAnalyticsAdmin)

	// Admin feedback
	api.Get("/admin/feedbacks", handler.AdminListFeedback)
	api.Patch("/admin/feedbacks/:id/verify", handler.AdminSetFeedbackVerified)

	// Admin app content CMS
	api.Get("/admin/app_contents", handler.AdminListAppContents)
	api.Post("/admin/app_contents", handler.AdminCreateAppContent)
	api.Put("/admin/app_contents/:id", handler.AdminUpdateAppContent)
	api.Delete("/admin/app_contents/:id", handler.AdminDeleteAppContent)

	// Admin entry analytics
	api.Get("/admin/entry-analytics", handler.AdminEntryAnalytics)
	api.Get("/admin/entry-analytics/entries", handler.AdminEntryAnalyticsEntries)

	// Admin organizations
	api.Get("/admin/organizations", handler.AdminListOrganizations)
	api.Get("/admin/org_ledgers", handler.AdminListOrgLedgers)
	api.Get("/admin/org_transactions", handler.AdminListOrgTransactions)

	// Admin land RTC / entry menu
	api.Post("/admin/land_rtcs/upload", handler.AdminUploadLandRtcDocument)
	api.Get("/admin/land_rtcs", handler.AdminListLandRtcs)
	api.Get("/admin/land_rtcs/:id", handler.AdminGetLandRtc)
	api.Post("/admin/land_rtcs", handler.AdminCreateLandRtc)
	api.Put("/admin/land_rtcs/:id", handler.AdminUpdateLandRtc)
	api.Delete("/admin/land_rtcs/:id", handler.AdminDeleteLandRtc)

	api.Post("/admin/documents/upload", handler.AdminUploadDocumentImages)
	api.Get("/admin/documents/browse", handler.AdminBrowseDocuments)
	api.Post("/admin/documents/folders", handler.AdminCreateDocumentFolder)
	api.Put("/admin/documents/folders/:id", handler.AdminUpdateDocumentFolder)
	api.Delete("/admin/documents/folders/:id", handler.AdminDeleteDocumentFolder)
	api.Get("/admin/documents/:id", handler.AdminGetUserDocument)
	api.Post("/admin/documents", handler.AdminCreateUserDocument)
	api.Put("/admin/documents/:id", handler.AdminUpdateUserDocument)
	api.Delete("/admin/documents/:id", handler.AdminDeleteUserDocument)

	api.Get("/admin/dairy/summary", handler.AdminGetDairySummary)
	api.Get("/admin/dairy/customers", handler.AdminListDairyCustomers)
	api.Post("/admin/dairy/customers", handler.AdminCreateDairyCustomer)
	api.Put("/admin/dairy/customers/:id", handler.AdminUpdateDairyCustomer)
	api.Delete("/admin/dairy/customers/:id", handler.AdminDeleteDairyCustomer)
	api.Get("/admin/dairy/entries", handler.AdminListDairyEntries)
	api.Post("/admin/dairy/entries", handler.AdminCreateDairyEntry)
	api.Put("/admin/dairy/entries/:id", handler.AdminUpdateDairyEntry)
	api.Delete("/admin/dairy/entries/:id", handler.AdminDeleteDairyEntry)

	api.Get("/admin/events", handler.AdminListEvents)
	api.Post("/admin/events", handler.AdminCreateEvent)
	api.Put("/admin/events/:id", handler.AdminUpdateEvent)
	api.Delete("/admin/events/:id", handler.AdminDeleteEvent)

	api.Post("/admin/weather/refresh", handler.AdminRefreshWeather)

	api.Get("/admin/achievers-lobby/categories", handler.AdminListLobbyCategories)
	api.Post("/admin/achievers-lobby/categories", handler.AdminCreateLobbyCategory)
	api.Put("/admin/achievers-lobby/categories/:id", handler.AdminUpdateLobbyCategory)
	api.Delete("/admin/achievers-lobby/categories/:id", handler.AdminDeleteLobbyCategory)
	api.Post("/admin/achievers-lobby/upload", handler.AdminUploadAchieversLobbyVideo)
	api.Get("/admin/achievers-lobby", handler.AdminListAchieversLobby)
	api.Get("/admin/achievers-lobby/:id", handler.AdminGetAchieversLobby)
	api.Post("/admin/achievers-lobby", handler.AdminCreateAchieversLobby)
	api.Put("/admin/achievers-lobby/:id", handler.AdminUpdateAchieversLobby)
	api.Patch("/admin/achievers-lobby/:id/status", handler.AdminSetAchieversLobbyStatus)
	api.Delete("/admin/achievers-lobby/:id", handler.AdminDeleteAchieversLobby)

	// start server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8000"
	}
	addr := fmt.Sprintf(":%s", port)
	log.Printf("Listening on %s", addr)
	log.Fatal(app.Listen(addr))
}
