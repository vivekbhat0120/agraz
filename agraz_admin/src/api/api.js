import axios from 'axios';

const resolveApiBaseUrl = () => {
  if (import.meta.env.VITE_API_BASE_URL) {
    return import.meta.env.VITE_API_BASE_URL;
  }
  // Dev: same-origin /api via Vite proxy (works with WSL + Windows browser).
  if (import.meta.env.DEV) {
    return '/api';
  }
  return 'https://agrazllp.com/api';
};

const api = axios.create({
  baseURL: resolveApiBaseUrl(),
});

// Add a request interceptor to include the token in headers
api.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token');
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    const tenantId = import.meta.env.VITE_TENANT_ID || localStorage.getItem('x_tenant_id');
    if (tenantId) {
      config.headers['X-Tenant-ID'] = String(tenantId);
    }
    return config;
  },
  (error) => Promise.reject(error)
);

export const login = async (email, password) => {
  const response = await api.post('/login', { email, password });
  return response.data;
};

export const forgotPassword = async (email) => {
  const response = await api.post('/forgot-password', { email });
  return response.data;
};

export const verifyResetCode = async (email, code) => {
  const response = await api.post('/verify-reset-code', { email, code });
  return response.data;
};

export const resetPasswordWithCode = async (email, code, newPassword, confirmPassword) => {
  const response = await api.post('/reset-password', {
    email,
    code,
    new_password: newPassword,
    confirm_password: confirmPassword,
  });
  return response.data;
};

export const getTenantConfig = async () => {
  const response = await api.get('/tenant/config');
  return response.data;
};

export const getMyMenus = async () => {
  const response = await api.get('/my-menus');
  return response.data;
};

export const getDashboardStats = async () => {
  const response = await api.get('/dashboard/stats');
  return response.data;
};

export const getMe = async () => {
  const response = await api.get('/me');
  return response.data;
};

export const getVendorUsers = async (params = {}) => {
  const response = await api.get('/vendor-users', { params });
  return response.data;
};

// Users
export const getUsers = async (page = 1, limit = 20, opts = {}) => {
  const params = { page, limit };
  if (opts.approval && opts.approval !== 'all') params.approval = opts.approval;
  if (opts.filter) params.filter = opts.filter;
  const response = await api.get('/users', { params });
  return response.data;
};
export const createUser = async (userData) => {
  const response = await api.post('/users', userData);
  return response.data;
};
export const updateUser = async (id, userData) => {
  const response = await api.put(`/users/${id}`, userData);
  return response.data;
};
export const deleteUser = async (id) => {
  const response = await api.delete(`/users/${id}`);
  return response.data;
};

// Roles
export const getRoles = async () => {
  const response = await api.get('/roles');
  return response.data;
};
export const createRole = async (roleData) => {
  const response = await api.post('/roles', roleData);
  return response.data;
};
export const updateRole = async (id, roleData) => {
  const response = await api.put(`/roles/${id}`, roleData);
  return response.data;
};
export const deleteRole = async (id) => {
  const response = await api.delete(`/roles/${id}`);
  return response.data;
};

// Permissions
export const getRolePermissionTree = async (roleId) => {
  const response = await api.get(`/roles/${roleId}/permissions/menu-tree`);
  return response.data;
};
export const updateRolePermissions = async (roleId, permissions) => {
  const response = await api.put(`/roles/${roleId}/permissions`, permissions);
  return response.data;
};

// User-Role Mapping
export const getUserRoles = async (userId) => {
  const response = await api.get(`/user/${userId}`);
  return response.data;
};
export const updateUserRoles = async (userId, roleIds) => {
  const response = await api.put(`/user/${userId}`, { role_ids: roleIds });
  return response.data;
};

// Menus
export const getMenus = async (page = 1, limit = 10, filter = '') => {
  const response = await api.get('/loadMenus', {
    params: { page, limit, filter }
  });
  return response.data;
};
export const getMenuTree = async () => {
  const response = await api.get('/menus/tree');
  return response.data;
};
export const createMenu = async (menuData) => {
  const response = await api.post('/menus', menuData);
  return response.data;
};
export const updateMenu = async (id, menuData) => {
  const response = await api.put(`/menus/${id}`, menuData);
  return response.data;
};
export const deleteMenu = async (id) => {
  const response = await api.delete(`/menus/${id}`);
  return response.data;
};

// Service registrations
export const getServiceRegistrations = async (params = {}) => {
  const response = await api.get('/service-registrations', { params });
  return response.data;
};

export const getServiceRegistration = async (id) => {
  const response = await api.get(`/service-registrations/${id}`);
  return response.data;
};

export const updateServiceRegistration = async (id, data) => {
  const response = await api.put(`/service-registrations/${id}`, data);
  return response.data;
};

export const deleteServiceRegistration = async (id) => {
  const response = await api.delete(`/service-registrations/${id}`);
  return response.data;
};

/** Public service registration (same endpoint as the AgRaz app). No login required. */
export const registerBusinessPublic = async (payload) => {
  const response = await api.post('/register-business', payload);
  return response.data;
};

// Vendors
export const getVendors = async (params = {}) => {
  const response = await api.get('/vendors', { params });
  return response.data;
};

export const getVendor = async (id) => {
  const response = await api.get(`/vendors/${id}`);
  return response.data;
};

export const createVendor = async (data) => {
  const response = await api.post('/vendors', data);
  return response.data;
};

export const updateVendor = async (id, data) => {
  const response = await api.put(`/vendors/${id}`, data);
  return response.data;
};

export const deleteVendor = async (id) => {
  const response = await api.delete(`/vendors/${id}`);
  return response.data;
};

// Vendor ↔ product mappings
export const getVendorProductMappings = async (params = {}) => {
  const response = await api.get('/vendor-product-mappings', { params });
  return response.data;
};

export const createVendorProductMapping = async (data) => {
  const response = await api.post('/vendor-product-mappings', data);
  return response.data;
};

export const updateVendorProductMapping = async (id, data) => {
  const response = await api.put(`/vendor-product-mappings/${id}`, data);
  return response.data;
};

export const deleteVendorProductMapping = async (id) => {
  const response = await api.delete(`/vendor-product-mappings/${id}`);
  return response.data;
};

/** Replace all product lines for one vendor */
export const replaceVendorProductMappings = async (vendorId, body) => {
  const response = await api.put(`/vendors/${vendorId}/product-mappings`, body);
  return response.data;
};

// Admin e-commerce
export const getAdminCategories = async (params = {}) => {
  const response = await api.get("/admin/ecom/categories", { params });
  return response.data;
};

export const getAdminCategory = async (id) => {
  const response = await api.get(`/admin/ecom/categories/${id}`);
  return response.data;
};

export const createAdminCategory = async (data) => {
  const response = await api.post("/admin/ecom/categories", data);
  return response.data;
};

export const updateAdminCategory = async (id, data) => {
  const response = await api.put(`/admin/ecom/categories/${id}`, data);
  return response.data;
};

export const deleteAdminCategory = async (id) => {
  const response = await api.delete(`/admin/ecom/categories/${id}`);
  return response.data;
};

export const getAdminSubCategories = async (params = {}) => {
  const response = await api.get("/admin/ecom/sub-categories", { params });
  return response.data;
};

export const getAdminSubCategory = async (id) => {
  const response = await api.get(`/admin/ecom/sub-categories/${id}`);
  return response.data;
};

export const createAdminSubCategory = async (data) => {
  const response = await api.post("/admin/ecom/sub-categories", data);
  return response.data;
};

export const updateAdminSubCategory = async (id, data) => {
  const response = await api.put(`/admin/ecom/sub-categories/${id}`, data);
  return response.data;
};

export const deleteAdminSubCategory = async (id) => {
  const response = await api.delete(`/admin/ecom/sub-categories/${id}`);
  return response.data;
};

export const getAdminColors = async (params = {}) => {
  const response = await api.get("/admin/ecom/colors", { params });
  return response.data;
};

export const getAdminColor = async (id) => {
  const response = await api.get(`/admin/ecom/colors/${id}`);
  return response.data;
};

export const createAdminColor = async (data) => {
  const response = await api.post("/admin/ecom/colors", data);
  return response.data;
};

export const updateAdminColor = async (id, data) => {
  const response = await api.put(`/admin/ecom/colors/${id}`, data);
  return response.data;
};

export const deleteAdminColor = async (id) => {
  const response = await api.delete(`/admin/ecom/colors/${id}`);
  return response.data;
};

export const getAdminProducts = async (params = {}) => {
  const response = await api.get("/admin/ecom/products", { params });
  return response.data;
};

export const getAdminProduct = async (id) => {
  const response = await api.get(`/admin/ecom/products/${id}`);
  return response.data;
};

export const createAdminProduct = async (data) => {
  const response = await api.post("/admin/ecom/products", data);
  return response.data;
};

export const updateAdminProduct = async (id, data) => {
  const response = await api.put(`/admin/ecom/products/${id}`, data);
  return response.data;
};

export const deleteAdminProduct = async (id) => {
  const response = await api.delete(`/admin/ecom/products/${id}`);
  return response.data;
};

export const listAdminStorefrontBanners = async (slot = "home") => {
  const response = await api.get("/admin/storefront/banners", { params: { slot } });
  return response.data;
};

export const createAdminStorefrontBanner = async (data) => {
  const response = await api.post("/admin/storefront/banners", data);
  return response.data;
};

export const updateAdminStorefrontBanner = async (id, data) => {
  const response = await api.put(`/admin/storefront/banners/${id}`, data);
  return response.data;
};

export const deleteAdminStorefrontBanner = async (id) => {
  const response = await api.delete(`/admin/storefront/banners/${id}`);
  return response.data;
};

export const reorderAdminStorefrontBanners = async (body) => {
  const response = await api.put("/admin/storefront/banners/reorder", body);
  return response.data;
};

// Upload (already-cropped) e-commerce image to backend.
// kind: "product" | "variant" | "hero"
// file: Blob/File
export const uploadAdminEcomImage = async ({ kind, file }) => {
  const fd = new FormData();
  fd.append("kind", String(kind));
  fd.append("image", file);
  const response = await api.post("/admin/ecom/images/upload", fd);
  return response.data; // { url }
};

/** Origin for static files (e.g. /uploads/...) — same host as API without /api */
export const getUploadsBaseUrl = () => {
  if (import.meta.env.DEV && !import.meta.env.VITE_API_BASE_URL) {
    return '';
  }
  try {
    return new URL(api.defaults.baseURL).origin;
  } catch {
    return 'http://localhost:8000';
  }
};

/**
 * Multipart upload. Form field "images" (repeatable).
 * Optional registrationId: appends to DB and returns { paths, record }.
 * Without id: staging only, returns { paths }.
 */
export const uploadServiceRegistrationImages = async ({ registrationId, files }) => {
  const fd = new FormData();
  if (registrationId != null && registrationId !== '') {
    fd.append('registration_id', String(registrationId));
  }
  for (const f of files) {
    fd.append('images', f);
  }
  const response = await api.post('/service-registrations/images', fd);
  return response.data;
};

export const removeServiceRegistrationImage = async (registrationId, path) => {
  const response = await api.delete(`/service-registrations/${registrationId}/images`, {
    data: { path },
  });
  return response.data;
};

/** Multipart field "photo" — profile photo for service provider */
export const uploadServiceProviderPhoto = async (registrationId, file) => {
  const fd = new FormData();
  fd.append('photo', file);
  const response = await api.post(`/service-registrations/${registrationId}/provider-photo`, fd);
  return response.data;
};

/** Multipart field "image" — image for a custom service row; merge returned url into custom_services on save */
export const uploadCustomServiceImage = async (registrationId, file) => {
  const fd = new FormData();
  fd.append('image', file);
  const response = await api.post(`/service-registrations/${registrationId}/custom-service-image`, fd);
  return response.data;
};

// Store (catalog + cart)
export const getStoreCategories = async (params = {}) => {
  const response = await api.get("/store/categories", { params });
  return response.data;
};

export const getStoreSubCategories = async (categoryId) => {
  const response = await api.get("/store/sub-categories", {
    params: { category_id: categoryId },
  });
  return response.data;
};

export const getStoreProducts = async (params = {}) => {
  const response = await api.get("/store/products", { params });
  return response.data;
};

export const getStoreProductById = async (id) => {
  const response = await api.get(`/store/products/${id}`);
  return response.data;
};

export const getStoreCart = async () => {
  const response = await api.get("/store/cart");
  return response.data;
};

export const addCartItem = async (data) => {
  const response = await api.post("/store/cart/items", data);
  return response.data;
};

export const updateCartItem = async (variantId, data) => {
  const response = await api.put(`/store/cart/items/${variantId}`, data);
  return response.data;
};

export const deleteCartItem = async (variantId) => {
  const response = await api.delete(`/store/cart/items/${variantId}`);
  return response.data;
};

// Government facilities (admin)
export const getAdminGovDepartments = async () => {
  const response = await api.get('/admin/gov/departments');
  return response.data;
};
export const createAdminGovDepartment = async (data) => {
  const response = await api.post('/admin/gov/departments', data);
  return response.data;
};
export const updateAdminGovDepartment = async (id, data) => {
  const response = await api.put(`/admin/gov/departments/${id}`, data);
  return response.data;
};
export const deleteAdminGovDepartment = async (id) => {
  const response = await api.delete(`/admin/gov/departments/${id}`);
  return response.data;
};

export const getAdminGovCrops = async () => {
  const response = await api.get('/admin/gov/crops');
  return response.data;
};
export const createAdminGovCrop = async (data) => {
  const response = await api.post('/admin/gov/crops', data);
  return response.data;
};
export const updateAdminGovCrop = async (id, data) => {
  const response = await api.put(`/admin/gov/crops/${id}`, data);
  return response.data;
};
export const deleteAdminGovCrop = async (id) => {
  const response = await api.delete(`/admin/gov/crops/${id}`);
  return response.data;
};

export const getAdminGovFacilities = async (params = {}) => {
  const response = await api.get('/admin/gov/facilities', { params });
  return response.data;
};
export const getAdminGovFacility = async (id) => {
  const response = await api.get(`/admin/gov/facilities/${id}`);
  return response.data;
};
export const createAdminGovFacility = async (data) => {
  const response = await api.post('/admin/gov/facilities', data);
  return response.data;
};
export const updateAdminGovFacility = async (id, data) => {
  const response = await api.put(`/admin/gov/facilities/${id}`, data);
  return response.data;
};
export const deleteAdminGovFacility = async (id) => {
  const response = await api.delete(`/admin/gov/facilities/${id}`);
  return response.data;
};
export const uploadGovFacilityApplication = async (file) => {
  const fd = new FormData();
  fd.append('file', file);
  const response = await api.post('/admin/gov/facilities/upload', fd);
  return response.data;
};

// Market reports
export const getAdminMarketAgents = async () => (await api.get('/admin/market/agents')).data;
export const createAdminMarketAgent = async (data) => (await api.post('/admin/market/agents', data)).data;
export const updateAdminMarketAgent = async (id, data) => (await api.put(`/admin/market/agents/${id}`, data)).data;
export const deleteAdminMarketAgent = async (id) => (await api.delete(`/admin/market/agents/${id}`)).data;

export const getAdminMarketAPMCs = async () => (await api.get('/admin/market/apmcs')).data;
export const createAdminMarketAPMC = async (data) => (await api.post('/admin/market/apmcs', data)).data;
export const updateAdminMarketAPMC = async (id, data) => (await api.put(`/admin/market/apmcs/${id}`, data)).data;
export const deleteAdminMarketAPMC = async (id) => (await api.delete(`/admin/market/apmcs/${id}`)).data;

export const getAdminMarketVarieties = async () => (await api.get('/admin/market/varieties')).data;
export const createAdminMarketVariety = async (data) => (await api.post('/admin/market/varieties', data)).data;
export const updateAdminMarketVariety = async (id, data) => (await api.put(`/admin/market/varieties/${id}`, data)).data;
export const deleteAdminMarketVariety = async (id) => (await api.delete(`/admin/market/varieties/${id}`)).data;

export const getAdminMarketDailyPrices = async (params = {}) => (await api.get('/admin/market/daily-prices', { params })).data;
export const createAdminMarketDailyPrice = async (data) => (await api.post('/admin/market/daily-prices', data)).data;
export const updateAdminMarketDailyPrice = async (id, data) => (await api.put(`/admin/market/daily-prices/${id}`, data)).data;
export const deleteAdminMarketDailyPrice = async (id) => (await api.delete(`/admin/market/daily-prices/${id}`)).data;

export const getAdminMarketLots = async (params = {}) => (await api.get('/admin/market/lots', { params })).data;
export const createAdminMarketLot = async (data) => (await api.post('/admin/market/lots', data)).data;
export const updateAdminMarketLot = async (id, data) => (await api.put(`/admin/market/lots/${id}`, data)).data;
export const deleteAdminMarketLot = async (id) => (await api.delete(`/admin/market/lots/${id}`)).data;

export const getAdminMarketQuantities = async (params = {}) => (await api.get('/admin/market/quantities', { params })).data;
export const createAdminMarketQuantity = async (data) => (await api.post('/admin/market/quantities', data)).data;
export const updateAdminMarketQuantity = async (id, data) => (await api.put(`/admin/market/quantities/${id}`, data)).data;
export const deleteAdminMarketQuantity = async (id) => (await api.delete(`/admin/market/quantities/${id}`)).data;

export const getAdminMarketAnalytics = async (params = {}) => (await api.get('/admin/market/analytics', { params })).data;

// Admin feedback
export const getAdminFeedbacks = async (params = {}) => {
  const response = await api.get('/admin/feedbacks', { params });
  return response.data;
};
export const setAdminFeedbackVerified = async (id, verified) => {
  const response = await api.patch(`/admin/feedbacks/${id}/verify`, { verified: Boolean(verified) });
  return response.data;
};

// Admin entry analytics
export const getAdminEntryAnalytics = async (params = {}) => {
  const response = await api.get('/admin/entry-analytics', { params });
  return response.data;
};
export const getAdminEntryAnalyticsEntries = async (params = {}) => {
  const response = await api.get('/admin/entry-analytics/entries', { params });
  return response.data;
};

export const getAdminOrganizations = async (params = {}) => {
  const response = await api.get('/admin/organizations', { params });
  return response.data;
};
export const getAdminOrgLedgers = async (params = {}) => {
  const response = await api.get('/admin/org_ledgers', { params });
  return response.data;
};
export const getAdminOrgTransactions = async (params = {}) => {
  const response = await api.get('/admin/org_transactions', { params });
  return response.data;
};

// Admin app contents (CMS)
export const getAdminAppContents = async (params = {}) => {
  const response = await api.get('/admin/app_contents', { params });
  return response.data;
};
export const createAdminAppContent = async (data) => {
  const response = await api.post('/admin/app_contents', data);
  return response.data;
};
export const updateAdminAppContent = async (id, data) => {
  const response = await api.put(`/admin/app_contents/${id}`, data);
  return response.data;
};
export const deleteAdminAppContent = async (id) => {
  const response = await api.delete(`/admin/app_contents/${id}`);
  return response.data;
};

// Admin land RTC / entry menu
export const getAdminLandRtcs = async (params = {}) => {
  const response = await api.get('/admin/land_rtcs', { params });
  return response.data;
};
export const getAdminLandRtc = async (id) => {
  const response = await api.get(`/admin/land_rtcs/${id}`);
  return response.data;
};
export const createAdminLandRtc = async (data) => {
  const response = await api.post('/admin/land_rtcs', data);
  return response.data;
};
export const updateAdminLandRtc = async (id, data) => {
  const response = await api.put(`/admin/land_rtcs/${id}`, data);
  return response.data;
};
export const deleteAdminLandRtc = async (id) => {
  const response = await api.delete(`/admin/land_rtcs/${id}`);
  return response.data;
};
export const uploadAdminLandRtcDocument = async (file) => {
  const fd = new FormData();
  fd.append('file', file);
  const response = await api.post('/admin/land_rtcs/upload', fd);
  return response.data;
};

// Admin dairy (milk ledger for dairy owners)
export const getAdminDairySummary = async (params = {}) =>
  (await api.get('/admin/dairy/summary', { params })).data;
export const getAdminDairyCustomers = async (params = {}) =>
  (await api.get('/admin/dairy/customers', { params })).data;
export const createAdminDairyCustomer = async (data) =>
  (await api.post('/admin/dairy/customers', data)).data;
export const updateAdminDairyCustomer = async (id, data) =>
  (await api.put(`/admin/dairy/customers/${id}`, data)).data;
export const deleteAdminDairyCustomer = async (id, params = {}) =>
  (await api.delete(`/admin/dairy/customers/${id}`, { params })).data;
export const getAdminDairyEntries = async (params = {}) =>
  (await api.get('/admin/dairy/entries', { params })).data;
export const createAdminDairyEntry = async (data) =>
  (await api.post('/admin/dairy/entries', data)).data;
export const updateAdminDairyEntry = async (id, data) =>
  (await api.put(`/admin/dairy/entries/${id}`, data)).data;
export const deleteAdminDairyEntry = async (id, params = {}) =>
  (await api.delete(`/admin/dairy/entries/${id}`, { params })).data;

// Admin personal documents (folders + multi-image papers)
export const getAdminDocumentsBrowse = async (params = {}) =>
  (await api.get('/admin/documents/browse', { params })).data;
export const createAdminDocumentFolder = async (data) =>
  (await api.post('/admin/documents/folders', data)).data;
export const updateAdminDocumentFolder = async (id, data) =>
  (await api.put(`/admin/documents/folders/${id}`, data)).data;
export const deleteAdminDocumentFolder = async (id, params = {}) =>
  (await api.delete(`/admin/documents/folders/${id}`, { params })).data;
export const getAdminUserDocument = async (id, params = {}) =>
  (await api.get(`/admin/documents/${id}`, { params })).data;
export const createAdminUserDocument = async (data) =>
  (await api.post('/admin/documents', data)).data;
export const updateAdminUserDocument = async (id, data) =>
  (await api.put(`/admin/documents/${id}`, data)).data;
export const deleteAdminUserDocument = async (id, params = {}) =>
  (await api.delete(`/admin/documents/${id}`, { params })).data;
export const uploadAdminDocumentImages = async (files) => {
  const fd = new FormData();
  const list = Array.isArray(files) ? files : [files];
  for (const f of list) {
    if (f) fd.append('file', f);
  }
  const response = await api.post('/admin/documents/upload', fd);
  return response.data;
};

// Admin event manage (birthdays, insurance renewals)
export const getAdminEvents = async (params = {}) =>
  (await api.get('/admin/events', { params })).data;
export const createAdminEvent = async (data) =>
  (await api.post('/admin/events', data)).data;
export const updateAdminEvent = async (id, data) =>
  (await api.put(`/admin/events/${id}`, data)).data;
export const deleteAdminEvent = async (id, params = {}) =>
  (await api.delete(`/admin/events/${id}`, { params })).data;

// Admin Achievers Lobby
export const getAdminAchieversLobby = async (params = {}) =>
  (await api.get("/admin/achievers-lobby", { params })).data;
export const getAdminAchieversLobbyItem = async (id) =>
  (await api.get(`/admin/achievers-lobby/${id}`)).data;
export const createAdminAchieversLobby = async (data) =>
  (await api.post("/admin/achievers-lobby", data)).data;
export const updateAdminAchieversLobby = async (id, data) =>
  (await api.put(`/admin/achievers-lobby/${id}`, data)).data;
export const deleteAdminAchieversLobby = async (id) =>
  (await api.delete(`/admin/achievers-lobby/${id}`)).data;
export const setAdminAchieversLobbyStatus = async (id, status) =>
  (await api.patch(`/admin/achievers-lobby/${id}/status`, { status })).data;
export const uploadAdminAchieversLobbyVideo = async (file) => {
  const fd = new FormData();
  fd.append("video", file);
  const response = await api.post("/admin/achievers-lobby/upload", fd, {
    timeout: 180000,
  });
  return response.data;
};
export const getAdminLobbyCategories = async (params = {}) =>
  (await api.get("/admin/achievers-lobby/categories", { params })).data;
export const createAdminLobbyCategory = async (data) =>
  (await api.post("/admin/achievers-lobby/categories", data)).data;
export const updateAdminLobbyCategory = async (id, data) =>
  (await api.put(`/admin/achievers-lobby/categories/${id}`, data)).data;
export const deleteAdminLobbyCategory = async (id) =>
  (await api.delete(`/admin/achievers-lobby/categories/${id}`)).data;

export default api;
