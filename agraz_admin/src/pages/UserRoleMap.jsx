import React, { useState, useEffect, useCallback } from 'react';
import {
  Link as LinkIcon,
  Search,
  Shield,
  ChevronRight,
  ChevronLeft,
  CheckCircle2,
  Loader2,
  Save,
  AlertCircle
} from 'lucide-react';
import { getUsers, getRoles, getUserRoles, updateUserRoles } from '../api/api';
import './UserRoleMap.css';

const PAGE_SIZE = 20;

const UserRoleMap = () => {
  const [users, setUsers] = useState([]);
  const [roles, setRoles] = useState([]);
  const [selectedUser, setSelectedUser] = useState(null);
  const [selectedRoleIds, setSelectedRoleIds] = useState([]);
  const [loading, setLoading] = useState(true);
  const [rolesLoading, setRolesLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [searchInput, setSearchInput] = useState('');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [total, setTotal] = useState(0);
  const [message, setMessage] = useState(null);

  useEffect(() => {
    const t = setTimeout(() => setSearch(searchInput.trim()), 300);
    return () => clearTimeout(t);
  }, [searchInput]);

  useEffect(() => {
    setPage(1);
  }, [search]);

  useEffect(() => {
    (async () => {
      try {
        const rolesResponse = await getRoles();
        setRoles(rolesResponse.data || []);
      } catch (err) {
        console.error("Error fetching roles:", err);
      }
    })();
  }, []);

  const fetchUsersPage = useCallback(async () => {
    setLoading(true);
    try {
      const usersResponse = await getUsers(page, PAGE_SIZE, {
        filter: search || undefined,
      });
      const rows = usersResponse.data || [];
      const count = Number(usersResponse.total) || 0;
      setUsers(rows);
      setTotal(count);
      setTotalPages(Math.max(1, Number(usersResponse.total_pages) || Math.ceil(count / PAGE_SIZE) || 1));
    } catch (err) {
      console.error("Error fetching users:", err);
    } finally {
      setLoading(false);
    }
  }, [page, search]);

  useEffect(() => {
    fetchUsersPage();
  }, [fetchUsersPage]);

  const handleUserSelect = async (user) => {
    setSelectedUser(user);
    setRolesLoading(true);
    setMessage(null);
    try {
      const userRoles = await getUserRoles(user.id);
      const roleIds = (userRoles || []).map(r => r.id || r.role_id);
      setSelectedRoleIds(roleIds);
    } catch (err) {
      console.error("Error fetching user roles:", err);
      setSelectedRoleIds([]);
    } finally {
      setRolesLoading(false);
    }
  };

  useEffect(() => {
    if (!selectedUser && users.length > 0) {
      handleUserSelect(users[0]);
    }
  }, [users, selectedUser]);

  const toggleRole = (roleId) => {
    setSelectedRoleIds(prev =>
      prev.includes(roleId)
        ? prev.filter(id => id !== roleId)
        : [...prev, roleId]
    );
  };

  const handleSave = async () => {
    if (!selectedUser) return;
    setSaving(true);
    try {
      await updateUserRoles(selectedUser.id, selectedRoleIds);
      setMessage({ type: 'success', text: 'Assignments updated successfully!' });
      setTimeout(() => setMessage(null), 3000);
    } catch (err) {
      console.error("Error updating assignments:", err);
      setMessage({ type: 'error', text: 'Failed to update assignments.' });
    } finally {
      setSaving(false);
    }
  };

  const initials = (user) =>
    `${(user.firstname || '?').charAt(0)}${(user.lastname || '').charAt(0)}`;

  return (
    <div className="user-role-map-page">
      <div className="page-header">
        <div className="title-area">
          <LinkIcon className="header-icon" />
          <div>
            <h1>User-Role Mapping</h1>
            <p>Assign and manage organizational roles for each user</p>
          </div>
        </div>
        <div className="header-actions">
           {message && (
             <div className={`status-msg ${message.type}`}>
               {message.type === 'success' ? <CheckCircle2 size={16} /> : <AlertCircle size={16} />}
               <span>{message.text}</span>
             </div>
           )}
           <button
             className="primary-btn"
             onClick={handleSave}
             disabled={saving || !selectedUser}
           >
             {saving ? <Loader2 size={18} className="spinner" /> : <Save size={18} />}
             Save Changes
           </button>
        </div>
      </div>

      <div className="mapping-container">
        <div className="user-selection-panel">
          <div className="search-box">
            <Search size={18} />
            <input
              type="text"
              placeholder="Search name, email or phone..."
              value={searchInput}
              onChange={(e) => setSearchInput(e.target.value)}
            />
          </div>
          <div className="user-scroll-list">
            {loading ? (
              <div className="panel-loader"><Loader2 className="spinner" /></div>
            ) : users.length === 0 ? (
              <div className="empty-panel">No users matching search.</div>
            ) : (
              users.map(user => (
                <div
                  key={user.id}
                  className={`user-list-item ${selectedUser?.id === user.id ? 'active' : ''}`}
                  onClick={() => handleUserSelect(user)}
                >
                  <div className="user-avatar">
                    {initials(user)}
                  </div>
                  <div className="user-details">
                    <span className="name">{user.firstname} {user.lastname}</span>
                    <span className="email">{user.mobile_number || user.email}</span>
                  </div>
                  <ChevronRight size={16} className="chevron" />
                </div>
              ))
            )}
          </div>
          <div className="user-panel-pagination">
            <span>{total} users · page {page}/{totalPages}</span>
            <div className="pagination-btns">
              <button type="button" disabled={page <= 1} onClick={() => setPage((p) => Math.max(1, p - 1))}>
                <ChevronLeft size={16} />
              </button>
              <button type="button" disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>
                <ChevronRight size={16} />
              </button>
            </div>
          </div>
        </div>

        <div className="role-assignment-panel">
          <div className="panel-header">
            <h3>Assign Roles to: <span className="highlight">{selectedUser ? `${selectedUser.firstname} ${selectedUser.lastname}` : '...'}</span></h3>
            <p className="subtitle">Select the roles this user should possess</p>
          </div>

          <div className="roles-checklist">
            {rolesLoading ? (
              <div className="panel-loader"><Loader2 className="spinner" size={32} /></div>
            ) : roles.length === 0 ? (
              <div className="empty-panel">No roles defined in the system.</div>
            ) : (
              <div className="roles-grid">
                {roles.map(role => (
                  <div
                    key={role.id}
                    className={`role-check-card ${selectedRoleIds.includes(role.id) ? 'checked' : ''}`}
                    onClick={() => toggleRole(role.id)}
                  >
                    <div className="check-indicator">
                      <Shield size={20} />
                      {selectedRoleIds.includes(role.id) && (
                        <div className="check-mark">
                          <CheckCircle2 size={16} />
                        </div>
                      )}
                    </div>
                    <div className="role-info">
                      <h4>{role.role_name}</h4>
                      <p>{role.description || "No description provided."}</p>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default UserRoleMap;
