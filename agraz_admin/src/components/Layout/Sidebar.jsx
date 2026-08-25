import React, { useState, useEffect } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import {
  LayoutDashboard,
  ShieldAlert,
  Users,
  ShieldPlus,
  Shield,
  Lock,
  Link as LinkIcon,
  Menu,
  List,
  FileClock,
  ChevronRight,
  ChevronDown,
  LogOut,
  ClipboardList,
  X,
  Layers,
  Tags,
  Palette,
  Package,
  Store,
  Share2,
  Image,
  Images,
  Landmark,
  BarChart3,
  MessageSquare,
  Activity,
  FileText,
  Building2,
  Map,
  Milk,
  FolderOpen,
  CalendarDays,
  Trophy,
} from "lucide-react";
import "./Sidebar.css";

import { getMyMenus } from "../../api/api";
import { logoutAndRedirect } from "../../lib/authStorage";

const iconMap = {
  LayoutDashboard: <LayoutDashboard size={18} strokeWidth={1.75} />,
  ShieldAlert: <ShieldAlert size={18} strokeWidth={1.75} />,
  Users: <Users size={18} strokeWidth={1.75} />,
  ShieldPlus: <ShieldPlus size={18} strokeWidth={1.75} />,
  Shield: <Shield size={18} strokeWidth={1.75} />,
  Lock: <Lock size={18} strokeWidth={1.75} />,
  Link: <LinkIcon size={18} strokeWidth={1.75} />,
  Menu: <Menu size={18} strokeWidth={1.75} />,
  List: <List size={18} strokeWidth={1.75} />,
  FileClock: <FileClock size={18} strokeWidth={1.75} />,
  ClipboardList: <ClipboardList size={18} strokeWidth={1.75} />,
  LogOut: <LogOut size={18} strokeWidth={1.75} />,
  Layers: <Layers size={18} strokeWidth={1.75} />,
  Tags: <Tags size={18} strokeWidth={1.75} />,
  Palette: <Palette size={18} strokeWidth={1.75} />,
  Package: <Package size={18} strokeWidth={1.75} />,
  Store: <Store size={18} strokeWidth={1.75} />,
  Share2: <Share2 size={18} strokeWidth={1.75} />,
  Image: <Image size={18} strokeWidth={1.75} />,
  Images: <Images size={18} strokeWidth={1.75} />,
  Landmark: <Landmark size={18} strokeWidth={1.75} />,
  BarChart3: <BarChart3 size={18} strokeWidth={1.75} />,
  MessageSquare: <MessageSquare size={18} strokeWidth={1.75} />,
  Activity: <Activity size={18} strokeWidth={1.75} />,
  FileText: <FileText size={18} strokeWidth={1.75} />,
  Building2: <Building2 size={18} strokeWidth={1.75} />,
  Map: <Map size={18} strokeWidth={1.75} />,
  Milk: <Milk size={18} strokeWidth={1.75} />,
  FolderOpen: <FolderOpen size={18} strokeWidth={1.75} />,
  CalendarDays: <CalendarDays size={18} strokeWidth={1.75} />,
  Trophy: <Trophy size={18} strokeWidth={1.75} />,
};

/** Normalize menu rows from `/my-menus` (snake_case + occasional PascalCase). */
function normalizeMenuItem(row) {
  if (!row || typeof row !== "object") return null;
  let url = String(row.url ?? row.URL ?? "").trim();
  if (url && !url.startsWith("#") && !/^https?:\/\//i.test(url) && !url.startsWith("/")) {
    url = `/${url}`;
  }
  const menu_name = row.menu_name ?? row.MenuName ?? "Menu";
  const icon = row.icon ?? row.Icon ?? "Menu";
  const raw = row.children ?? row.Children ?? [];
  const children = Array.isArray(raw)
    ? raw.map(normalizeMenuItem).filter(Boolean)
    : [];
  return { ...row, url, menu_name, icon, children };
}

/** Compare path segments only (ignore trailing slash except root). */
function normalizeMenuPath(p) {
  if (!p || p === "/") return "/";
  const t = p.replace(/\/+$/, "");
  return t === "" ? "/" : t;
}

/**
 * Match sidebar `to` against the current location.
 * - Path-only links stay active when the page adds its own query (e.g. ?page=2); same rule for all menus.
 * - Links with ?query require matching params (e.g. e-com ?tab=).
 */
function menuUrlActive(location, to) {
  if (!to || to === "#") return false;
  const str = String(to).trim();
  let pathPart;
  let query = null;
  if (/^https?:\/\//i.test(str)) {
    try {
      const u = new URL(str);
      pathPart = u.pathname;
      query = u.search && u.search.length > 1 ? u.search.slice(1) : null;
    } catch {
      return false;
    }
  } else {
    const qMark = str.indexOf("?");
    pathPart = qMark >= 0 ? str.slice(0, qMark) : str;
    query = qMark >= 0 ? str.slice(qMark + 1) : null;
  }
  const path = normalizeMenuPath(pathPart);
  const locPath = normalizeMenuPath(location.pathname);
  if (locPath !== path) return false;
  if (query == null || query === "") {
    /* Group URL only; real matches use ?tab= children. */
    if (path === "/ecom-admin") return false;
    return true;
  }
  const want = new URLSearchParams(query);
  const cur = new URLSearchParams(location.search);
  if (path === "/ecom-admin" && want.get("tab") === "products") {
    const t = cur.get("tab");
    return t === "products" || t == null || t === "";
  }
  for (const key of want.keys()) {
    if (cur.get(key) !== want.get(key)) return false;
  }
  return true;
}

/** True if this item or any descendant matches the current route (for auto-expand). */
function menuSubtreeActive(location, item) {
  if (menuUrlActive(location, item.url)) return true;
  const ch = item.children || [];
  return ch.some((c) => menuSubtreeActive(location, c));
}

const DEFAULT_ADMIN_NAV = [
  { menu_name: "Dashboard", url: "/home", icon: "LayoutDashboard" },
  {
    menu_name: "Store & Catalog",
    url: "/ecom-admin",
    icon: "Store",
    children: [
      { menu_name: "Catalog (products)", url: "/ecom-admin?tab=products", icon: "Package" },
      { menu_name: "Categories", url: "/ecom-admin?tab=categories", icon: "Tags" },
      { menu_name: "Sub-categories", url: "/ecom-admin?tab=sub-categories", icon: "Layers" },
      { menu_name: "Colors", url: "/ecom-admin?tab=colors", icon: "Palette" },
    ],
  },
  {
    menu_name: "Marketplace",
    url: "/marketplace",
    icon: "Share2",
    children: [
      { menu_name: "Vendor details", url: "/vendor-details", icon: "Store" },
      { menu_name: "Vendor & product mapping", url: "/vendor-product-mapping", icon: "Share2" },
      { menu_name: "Vendor & user mapping", url: "/vendor-user-mapping", icon: "Users" },
    ],
  },
  {
    menu_name: "User & Roles",
    url: "/admin-master",
    icon: "ShieldAlert",
    children: [
      { menu_name: "User List", url: "/users", icon: "Users" },
      { menu_name: "Role Creation", url: "/rolecreation", icon: "ShieldPlus" },
      { menu_name: "Existing Roles", url: "/existingroles", icon: "Shield" },
      { menu_name: "Role Permissions", url: "/rolemanagement", icon: "Lock" },
      { menu_name: "User-Role Map", url: "/usermanagement", icon: "Link" },
      { menu_name: "Menu Creation", url: "/menucreation", icon: "Menu" },
      { menu_name: "Existing Menus", url: "/existingmenus", icon: "List" },
    ],
  },
];

const HARD_CODED_SERVICE_NAV = [
  { menu_name: "Service Registrations", url: "/service-registrations", icon: "ClipboardList" },
  { menu_name: "Government Facilities", url: "/gov-facilities", icon: "Landmark" },
];

/**
 * Fallback Tools links (also seed these in Menu Management /my-menus if using DB menus):
 * - Feedback → /feedback (icon: MessageSquare)
 * - Entry Analytics → /entry-analytics (icon: Activity)
 * - App Contents → /app-contents (icon: FileText)
 */
const HARD_CODED_TOOLS_NAV = [
  { menu_name: "Feedback", url: "/feedback", icon: "MessageSquare" },
  { menu_name: "Entry Analytics", url: "/entry-analytics", icon: "Activity" },
  { menu_name: "Organizations", url: "/organizations", icon: "Building2" },
  { menu_name: "App Contents", url: "/app-contents", icon: "FileText" },
  { menu_name: "RTC Entry", url: "/rtc-entry", icon: "Map" },
  { menu_name: "Dairy", url: "/dairy", icon: "Milk" },
  { menu_name: "Documents", url: "/documents", icon: "FolderOpen" },
  { menu_name: "Event Manage", url: "/events", icon: "CalendarDays" },
  { menu_name: "Achievers Lobby", url: "/achievers-lobby", icon: "Trophy" },
];

const LOGOUT_NAV_ITEM = { menu_name: "Logout", url: "/logout", icon: "LogOut" };

const SidebarItem = ({
  item,
  level = 0,
  isOpen,
  isMobile,
  toggleSidebar,
  expandSidebar,
}) => {
  const navigate = useNavigate();
  const location = useLocation();
  const hasChildren = item.children && item.children.length > 0;
  const subtreeActive = menuSubtreeActive(location, item);
  /** When route is inside this section, user can fold the submenu; reset when route leaves. */
  const [manualFold, setManualFold] = useState(false);

  useEffect(() => {
    if (!subtreeActive) setManualFold(false);
  }, [subtreeActive]);

  const expandedFinal = hasChildren ? subtreeActive && !manualFold : false;

  const padStyle = isOpen || isMobile ? { paddingLeft: `${level * 10 + 14}px` } : undefined;

  const firstChildUrl = () => {
    const first = item.children?.find((c) => c?.url);
    return first?.url || null;
  };

  const handleParentClick = (e) => {
    e.preventDefault();
    const collapsedDesktop = !isOpen && !isMobile;
    const go = firstChildUrl();

    if (collapsedDesktop && typeof expandSidebar === "function") {
      expandSidebar(true);
      if (!subtreeActive && go) {
        navigate(go);
      }
      return;
    }

    if (!subtreeActive) {
      if (go) navigate(go);
      return;
    }

    setManualFold((f) => !f);
  };

  const handleLeafClick = (e) => {
    if (item.url === "/logout") {
      e.preventDefault();
      logoutAndRedirect();
      return;
    }
    if (isMobile) toggleSidebar();
  };

  const rowClass = `sidebar-item ${expandedFinal ? "expanded" : ""}`;
  /** Do not use NavLink `isActive` for ?tab= links on the same pathname — RR can mark every `/ecom-admin?…` row active. */
  const leafActive = !hasChildren && menuUrlActive(location, item.url);

  return (
    <div className={`sidebar-item-container level-${level}`}>
      {hasChildren ? (
        <button
          type="button"
          className={rowClass}
          onClick={handleParentClick}
          style={padStyle}
          aria-expanded={expandedFinal}
        >
          <span className="sidebar-icon">{iconMap[item.icon] || <Menu size={18} strokeWidth={1.75} />}</span>
          {(isOpen || isMobile) && <span className="sidebar-text">{item.menu_name}</span>}
          {(isOpen || isMobile) && (
            <span className="sidebar-chevron">
              {expandedFinal ? <ChevronDown size={14} strokeWidth={2} /> : <ChevronRight size={14} strokeWidth={2} />}
            </span>
          )}
        </button>
      ) : (
        <Link
          to={item.url || "#"}
          className={`sidebar-item${leafActive ? " active" : ""}`}
          aria-current={leafActive ? "page" : undefined}
          onClick={handleLeafClick}
          style={padStyle}
        >
          <span className="sidebar-icon">{iconMap[item.icon] || <Menu size={18} strokeWidth={1.75} />}</span>
          {(isOpen || isMobile) && <span className="sidebar-text">{item.menu_name}</span>}
        </Link>
      )}
      {hasChildren && expandedFinal && (isOpen || isMobile) && (
        <div className="sidebar-children">
          {item.children.map((child, idx) => (
            <SidebarItem
              key={child.id != null ? `c-${child.id}` : `c-${idx}-${child.url || ""}`}
              item={child}
              level={level + 1}
              isOpen={isOpen}
              isMobile={isMobile}
              toggleSidebar={toggleSidebar}
              expandSidebar={expandSidebar}
            />
          ))}
        </div>
      )}
    </div>
  );
};

const Sidebar = ({ isOpen, isMobile, setMobileOpen, mobileOpen, setOpen }) => {
  const [menus, setMenus] = useState([]);
  const [user] = useState(() => {
    const storedUser = localStorage.getItem("user");
    if (!storedUser || storedUser === "undefined") return null;
    try {
      return JSON.parse(storedUser);
    } catch {
      return null;
    }
  });
  const toggleMobile = () => setMobileOpen(!mobileOpen);

  const firstName = user?.Firstname ?? user?.first_name ?? user?.firstname ?? "";
  const lastName = user?.Lastname ?? user?.last_name ?? user?.lastname ?? "";
  const displayName = (firstName || lastName) ? `${firstName} ${lastName}`.trim() : "User";
  const userInitials = (() => {
    const combined = `${firstName}${lastName}`.trim();
    if (!combined) return "U";
    return `${firstName.charAt(0)}${lastName.charAt(0) || ""}`.toUpperCase();
  })();

  useEffect(() => {
    const fetchMenus = async () => {
      try {
        const token = localStorage.getItem('token');
        if (!token) return;

        const data = await getMyMenus();
        const raw = Array.isArray(data) ? data : data.data || [];
        let normalized = raw.map(normalizeMenuItem).filter(Boolean);
        const hasUserList = (items) =>
          items.some(
            (i) =>
              i.url === "/users" ||
              (Array.isArray(i.children) && i.children.some((c) => c.url === "/users"))
          );
        if (!normalized.length) {
          normalized = DEFAULT_ADMIN_NAV.map(normalizeMenuItem).filter(Boolean);
        } else if (!hasUserList(normalized)) {
          const userGroup = DEFAULT_ADMIN_NAV.find((i) => i.url === "/admin-master");
          if (userGroup) normalized = [...normalized, normalizeMenuItem(userGroup)].filter(Boolean);
        }
        setMenus(normalized);
      } catch (err) {
        console.error("Error fetching menus:", err);
        setMenus(DEFAULT_ADMIN_NAV.map(normalizeMenuItem).filter(Boolean));
        if (err.response?.status === 401) {
          localStorage.removeItem('token');
          localStorage.removeItem('user');
          window.location.href = '/agraz_admin/login';
        }
      }
    };

    fetchMenus();
  }, []);

  return (
    <>
      {isMobile && mobileOpen && (
        <div className="sidebar-overlay" onClick={toggleMobile}></div>
      )}

      <aside className={`sidebar ${isOpen ? "open" : "collapsed"} ${isMobile ? "mobile" : ""} ${mobileOpen ? "mobile-open" : ""}`}>
        <div className="sidebar-header">
          <div className="logo-container">
            <div className="logo-icon">RB</div>
            {(isOpen || isMobile) && (
              <div className="logo-details">
                <h2 className="logo-text">AGRAZ Dashboard</h2>
              </div>
            )}
          </div>
          {isMobile && (
            <button className="mobile-close" onClick={toggleMobile}>
              <X size={20} strokeWidth={2} />
            </button>
          )}
        </div>

        <nav className="sidebar-nav">
          <div className="nav-group">
            {(isOpen || isMobile) && <span className="nav-label">Main Menu</span>}
            {menus.map((item, index) => (
              <SidebarItem
                key={item.id != null ? `dyn-${item.id}` : `dyn-i-${index}-${item.url || item.menu_name || ""}`}
                item={item}
                isOpen={isOpen}
                isMobile={isMobile}
                toggleSidebar={toggleMobile}
                expandSidebar={setOpen}
              />
            ))}
            {HARD_CODED_SERVICE_NAV.map((raw) => {
              const item = normalizeMenuItem(raw);
              if (!item) return null;
              return (
                <SidebarItem
                  key={`static-${item.url}`}
                  item={item}
                  isOpen={isOpen}
                  isMobile={isMobile}
                  toggleSidebar={toggleMobile}
                  expandSidebar={setOpen}
                />
              );
            })}
          </div>

          <div className="nav-group">
            {(isOpen || isMobile) && <span className="nav-label">Tools</span>}
            {HARD_CODED_TOOLS_NAV.map((raw) => {
              const item = normalizeMenuItem(raw);
              if (!item) return null;
              return (
                <SidebarItem
                  key={`tools-${item.url}`}
                  item={item}
                  isOpen={isOpen}
                  isMobile={isMobile}
                  toggleSidebar={toggleMobile}
                  expandSidebar={setOpen}
                />
              );
            })}
          </div>
          
          <div className="nav-group">
            {(isOpen || isMobile) && <span className="nav-label">Settings</span>}
            <SidebarItem
              key="static-logout"
              item={LOGOUT_NAV_ITEM}
              isOpen={isOpen}
              isMobile={isMobile}
              toggleSidebar={toggleMobile}
              expandSidebar={setOpen}
            />
          </div>
        </nav>

        <div className="sidebar-footer">
          {(isOpen || isMobile) && (
            <div className="user-info">
              <div className="avatar">{userInitials}</div>
              <div className="details">
                <span className="name">{displayName}</span>
                <span className="role">{(user?.Roles && user.Roles.length > 0) ? user.Roles[0].RoleName : "Admin"}</span>
              </div>
            </div>
          )}
        </div>
      </aside>
    </>
  );
};


export default Sidebar;
