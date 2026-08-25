import React from "react";
import { BrowserRouter as Router, Routes, Route, Navigate } from "react-router-dom";
import Layout from "./components/Layout/Layout";
import Dashboard from "./pages/Dashboard";
import RolePermissions from "./pages/RolePermissions";
import UserList from "./pages/UserList";
import RoleManagement from "./pages/RoleManagement";
import UserRoleMap from "./pages/UserRoleMap";
import MenuManagement from "./pages/MenuManagement";
import ServiceRegistrations from "./pages/ServiceRegistrations";
import VendorDetails from "./pages/VendorDetails";
import VendorProductMapping from "./pages/VendorProductMapping";
import VendorUserMapping from "./pages/VendorUserMapping";
import EcomAdmin from "./pages/EcomAdmin";
import StorefrontHero from "./pages/StorefrontHero";
import GovFacilities from "./pages/GovFacilities";
import MarketReports from "./pages/MarketReports";
import FeedbackAdmin from "./pages/FeedbackAdmin";
import EntryAnalytics from "./pages/EntryAnalytics";
import AppContentAdmin from "./pages/AppContentAdmin";
import OrganizationsAdmin from "./pages/OrganizationsAdmin";
import Login from "./pages/Login";
import PublicServiceRegister from "./pages/PublicServiceRegister";
import RtcEntryAdmin from "./pages/RtcEntryAdmin";
import DairyAdmin from "./pages/DairyAdmin";
import DocumentsAdmin from "./pages/DocumentsAdmin";
import EventsAdmin from "./pages/EventsAdmin";
import AchieversLobbyAdmin from "./pages/AchieversLobbyAdmin";
import { logoutAndRedirect } from "./lib/authStorage";
import "./App.css";

const routerBasename = (import.meta.env.BASE_URL || "/").replace(/\/$/, "");

// Protected Route Wrapper
const ProtectedRoute = ({ children }) => {
  const token = localStorage.getItem('token');
  const user = localStorage.getItem('user');
  
  // Stronger check for token validity
  if (!token || token === 'undefined' || !user || user === 'undefined') {
    return <Navigate to="/login" replace />;
  }
  
  return <Layout>{children}</Layout>;
};

// Simple Component placeholders
const Placeholder = ({ title }) => (
  <div className="app-placeholder">
    <h2>{title}</h2>
    <p>This is the {title} page content. More features coming soon!</p>
  </div>
);

function App() {
  return (
    <Router basename={routerBasename && routerBasename !== "/" ? routerBasename : undefined}>
      <Routes>
        {/* Public Routes — no login */}
        <Route path="/login" element={<Login />} />
        <Route path="/register-service" element={<PublicServiceRegister />} />
        
        {/* Protected Routes */}
        <Route path="/" element={<Navigate to="/home" replace />} />
        
        <Route path="/home" element={
          <ProtectedRoute><Dashboard /></ProtectedRoute>
        } />
        
        <Route path="/users" element={
          <ProtectedRoute><UserList /></ProtectedRoute>
        } />
        
        <Route path="/rolecreation" element={
          <ProtectedRoute><RoleManagement /></ProtectedRoute>
        } />
        
        <Route path="/existingroles" element={
          <ProtectedRoute><RoleManagement /></ProtectedRoute>
        } />
        
        <Route path="/rolemanagement" element={
          <ProtectedRoute><RolePermissions /></ProtectedRoute>
        } />
        
        <Route path="/usermanagement" element={
          <ProtectedRoute><UserRoleMap /></ProtectedRoute>
        } />
        
        <Route path="/menucreation" element={
          <ProtectedRoute><MenuManagement /></ProtectedRoute>
        } />
        
        <Route path="/existingmenus" element={
          <ProtectedRoute><MenuManagement /></ProtectedRoute>
        } />

        <Route path="/service-registrations" element={
          <ProtectedRoute><ServiceRegistrations /></ProtectedRoute>
        } />

        <Route path="/vendor-details" element={
          <ProtectedRoute><VendorDetails /></ProtectedRoute>
        } />

        <Route path="/vendor-product-mapping" element={
          <ProtectedRoute><VendorProductMapping /></ProtectedRoute>
        } />

        <Route path="/vendor-user-mapping" element={
          <ProtectedRoute><VendorUserMapping /></ProtectedRoute>
        } />

        <Route path="/ecom-admin" element={
          <ProtectedRoute><EcomAdmin /></ProtectedRoute>
        } />

        <Route path="/storefront-hero" element={
          <ProtectedRoute><StorefrontHero /></ProtectedRoute>
        } />

        <Route path="/gov-facilities" element={
          <ProtectedRoute><GovFacilities /></ProtectedRoute>
        } />

        <Route path="/market-reports" element={
          <ProtectedRoute><MarketReports /></ProtectedRoute>
        } />

        <Route path="/feedback" element={
          <ProtectedRoute><FeedbackAdmin /></ProtectedRoute>
        } />

        <Route path="/entry-analytics" element={
          <ProtectedRoute><EntryAnalytics /></ProtectedRoute>
        } />

        <Route path="/organizations" element={
          <ProtectedRoute><OrganizationsAdmin /></ProtectedRoute>
        } />

        <Route path="/app-contents" element={
          <ProtectedRoute><AppContentAdmin /></ProtectedRoute>
        } />

        <Route path="/rtc-entry" element={
          <ProtectedRoute><RtcEntryAdmin /></ProtectedRoute>
        } />

        <Route path="/dairy" element={
          <ProtectedRoute><DairyAdmin /></ProtectedRoute>
        } />

        <Route path="/documents" element={
          <ProtectedRoute><DocumentsAdmin /></ProtectedRoute>
        } />

        <Route path="/events" element={
          <ProtectedRoute><EventsAdmin /></ProtectedRoute>
        } />

        <Route path="/achievers-lobby" element={
          <ProtectedRoute><AchieversLobbyAdmin /></ProtectedRoute>
        } />
        
        <Route path="/auditlogs" element={
          <ProtectedRoute><Placeholder title="Audit Logs" /></ProtectedRoute>
        } />
        
        <Route path="/profile" element={
          <ProtectedRoute><Placeholder title="My Profile" /></ProtectedRoute>
        } />
        
        <Route path="/logout" element={<LogoutAction />} />
        
        {/* Catch all */}
        <Route path="*" element={<Navigate to="/login" />} />
      </Routes>
    </Router>
  );
}

const LogoutAction = () => {
  React.useLayoutEffect(() => {
    logoutAndRedirect();
  }, []);
  return null;
};

export default App;
