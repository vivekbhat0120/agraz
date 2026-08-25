import React, { useState, useEffect, useCallback } from "react";
import { Users, Loader2, Store, Save } from "lucide-react";
import { getUsers, getVendors, getVendorUsers, updateUser } from "../api/api";
import "./ServiceRegistrations.css";

const VendorUserMapping = () => {
  const [mapped, setMapped] = useState([]);
  const [users, setUsers] = useState([]);
  const [vendors, setVendors] = useState([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [userId, setUserId] = useState("");
  const [vendorId, setVendorId] = useState("");

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [mRes, uRes, vRes] = await Promise.all([
        getVendorUsers({ page: 1, limit: 200 }),
        getUsers(1, 500),
        getVendors({ page: 1, limit: 200 }),
      ]);
      setMapped(mRes.data || []);
      setUsers(uRes.data || []);
      setVendors(vRes.data || []);
    } catch (e) {
      console.error(e);
      setMapped([]);
      setUsers([]);
      setVendors([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const handleSave = async (e) => {
    e.preventDefault();
    const uid = Number(userId);
    const vid = Number(vendorId);
    if (!uid || !vid) {
      alert("Select both a user and a vendor.");
      return;
    }
    setSaving(true);
    try {
      await updateUser(uid, { vendor_id: vid });
      setUserId("");
      setVendorId("");
      await load();
    } catch (err) {
      alert(err.response?.data?.error || err.message || "Save failed");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="service-reg-page">
      <div className="page-header">
        <div className="title-area">
          <Users className="header-icon" />
          <div>
            <h1>Vendor &amp; user mapping</h1>
            <p>Link a login account to a vendor. Vendor users only see their own products and dashboard data.</p>
          </div>
        </div>
      </div>

      {loading ? (
        <div className="sr-loader">
          <Loader2 className="spinner" size={36} />
          <p>Loading…</p>
        </div>
      ) : (
        <div className="sr-list-card">
          <div style={{ padding: "1.25rem 1.5rem" }}>
            <form onSubmit={handleSave} className="sr-form sr-form-compact">
              <div className="sr-form-grid sr-form-grid-2">
                <div className="form-group">
                  <label>User *</label>
                  <select value={userId} onChange={(e) => setUserId(e.target.value)} required>
                    <option value="">— Select user —</option>
                    {users.map((u) => (
                      <option key={u.id} value={String(u.id)}>
                        #{u.id} · {u.firstname} {u.lastname} ({u.email})
                      </option>
                    ))}
                  </select>
                </div>
                <div className="form-group">
                  <label>
                    <Store size={14} style={{ display: "inline", verticalAlign: "middle", marginRight: 6 }} />
                    Vendor *
                  </label>
                  <select value={vendorId} onChange={(e) => setVendorId(e.target.value)} required>
                    <option value="">— Select vendor —</option>
                    {vendors.map((v) => (
                      <option key={v.id} value={String(v.id)}>
                        #{v.id} · {v.business_name}
                      </option>
                    ))}
                  </select>
                </div>
              </div>
              <div style={{ marginTop: "1rem" }}>
                <button type="submit" className="primary-btn" disabled={saving}>
                  {saving ? <Loader2 size={18} className="spinner" /> : <><Save size={16} /> Save mapping</>}
                </button>
              </div>
            </form>

            <section className="sr-form-section" style={{ marginTop: "2rem" }}>
              <h4>Mapped vendor users</h4>
              {mapped.length === 0 ? (
                <div className="sr-empty">No vendor users mapped yet.</div>
              ) : (
                <div className="mapping-table-wrap">
                  <table className="mapping-table">
                    <thead>
                      <tr>
                        <th>User</th>
                        <th>Email</th>
                        <th>Vendor</th>
                      </tr>
                    </thead>
                    <tbody>
                      {mapped.map((row) => (
                        <tr key={row.id}>
                          <td>
                            {row.firstname} {row.lastname}
                          </td>
                          <td>{row.email}</td>
                          <td>{row.vendor_name || `#${row.vendor_id}`}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}
            </section>
          </div>
        </div>
      )}

      <style>{`
        .mapping-table-wrap { overflow-x: auto; border: 1px solid var(--border); border-radius: var(--radius-md); }
        .mapping-table { width: 100%; border-collapse: collapse; font-size: 0.875rem; }
        .mapping-table th, .mapping-table td { padding: 0.65rem 0.75rem; text-align: left; border-bottom: 1px solid var(--border); }
        .mapping-table th { background: var(--bg-main); color: var(--text-muted); font-weight: 600; }
        .mapping-table td select { width: 100%; padding: 0.45rem 0.5rem; border-radius: var(--radius-sm); border: 1px solid var(--border); }
      `}</style>
    </div>
  );
};

export default VendorUserMapping;
