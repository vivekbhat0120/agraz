import React, { useCallback, useEffect, useState } from "react";
import {
  Trophy,
  Loader2,
  Plus,
  Pencil,
  Trash2,
  X,
  ChevronLeft,
  ChevronRight,
  Check,
  Upload,
} from "lucide-react";
import {
  getAdminAchieversLobby,
  createAdminAchieversLobby,
  updateAdminAchieversLobby,
  deleteAdminAchieversLobby,
  setAdminAchieversLobbyStatus,
  uploadAdminAchieversLobbyVideo,
  getAdminLobbyCategories,
  createAdminLobbyCategory,
  updateAdminLobbyCategory,
  deleteAdminLobbyCategory,
  getUploadsBaseUrl,
} from "../api/api";
import "./ServiceRegistrations.css";
import "./UserList.css";

const limit = 20;
const STATUS_TABS = [
  { id: "pending", label: "Pending" },
  { id: "active", label: "Active" },
  { id: "rejected", label: "Rejected" },
  { id: "all", label: "All" },
];
const KIND_TABS = [
  { id: "", label: "All kinds" },
  { id: "achiever", label: "Achievers" },
  { id: "innovation", label: "Innovations" },
];

function fmtDate(v) {
  if (!v) return "—";
  const d = new Date(v);
  if (Number.isNaN(d.getTime())) return String(v).slice(0, 16);
  return d.toLocaleString("en-IN", { dateStyle: "medium", timeStyle: "short" });
}

function mediaUrl(path) {
  if (!path) return "";
  if (/^https?:\/\//i.test(path)) return path;
  const base = getUploadsBaseUrl();
  return path.startsWith("/") ? `${base}${path}` : `${base}/${path}`;
}

const emptyItem = () => ({
  kind: "achiever",
  status: "active",
  name: "",
  mobile: "",
  category: "",
  address: "",
  title: "",
  description: "",
  video_url: "",
});

const emptyCat = () => ({
  kind: "achiever",
  name: "",
  name_kn: "",
  sort_order: 0,
  status: "active",
});

const inputStyle = {
  display: "block",
  width: "100%",
  marginTop: 6,
  padding: "0.6rem 0.75rem",
  borderRadius: 8,
  border: "1px solid var(--border)",
};
const th = { textAlign: "left", padding: "0.75rem 1rem" };
const td = { padding: "0.7rem 1rem", verticalAlign: "top" };

const AchieversLobbyAdmin = () => {
  const [view, setView] = useState("videos");
  const [status, setStatus] = useState("pending");
  const [kind, setKind] = useState("");
  const [q, setQ] = useState("");
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [categories, setCategories] = useState([]);
  const [modalOpen, setModalOpen] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState(emptyItem());
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState("");
  const [busyId, setBusyId] = useState(null);
  const [catModal, setCatModal] = useState(false);
  const [catEditingId, setCatEditingId] = useState(null);
  const [catForm, setCatForm] = useState(emptyCat());
  const [catSaving, setCatSaving] = useState(false);

  const fetchRows = useCallback(async () => {
    setLoading(true);
    try {
      const data = await getAdminAchieversLobby({
        page,
        limit,
        status,
        kind: kind || undefined,
        q: q.trim() || undefined,
      });
      setRows(data.data || []);
      setTotal(data.total ?? 0);
    } catch (e) {
      console.error(e);
      setRows([]);
      setTotal(0);
    } finally {
      setLoading(false);
    }
  }, [page, status, kind, q]);

  const fetchCats = useCallback(async () => {
    try {
      const data = await getAdminLobbyCategories();
      setCategories(data.data || []);
    } catch (e) {
      console.error(e);
      setCategories([]);
    }
  }, []);

  useEffect(() => {
    setPage(1);
  }, [status, kind, q]);

  useEffect(() => {
    fetchRows();
  }, [fetchRows]);

  useEffect(() => {
    fetchCats();
  }, [fetchCats]);

  const totalPages = Math.max(1, Math.ceil(total / limit) || 1);
  const kindCats = categories.filter(
    (c) =>
      c.status === "active" &&
      (c.kind === form.kind || c.kind === "both")
  );

  const openCreate = () => {
    setEditingId(null);
    setError("");
    setForm(emptyItem());
    setModalOpen(true);
  };

  const openEdit = (row) => {
    setEditingId(row.id);
    setError("");
    setForm({
      kind: row.kind || "achiever",
      status: row.status || "pending",
      name: row.name || "",
      mobile: row.mobile || "",
      category: row.category || "",
      address: row.address || "",
      title: row.title || "",
      description: row.description || "",
      video_url: row.video_url || "",
    });
    setModalOpen(true);
  };

  const onUpload = async (e) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    setUploading(true);
    setError("");
    try {
      const data = await uploadAdminAchieversLobbyVideo(file);
      setForm((f) => ({ ...f, video_url: data.url || "" }));
    } catch (err) {
      setError(err?.response?.data?.error || "Video upload failed");
    } finally {
      setUploading(false);
    }
  };

  const onSave = async (e) => {
    e.preventDefault();
    if (!form.name.trim()) {
      setError("Name is required");
      return;
    }
    if (!form.mobile.trim()) {
      setError("Mobile number is required");
      return;
    }
    if (!form.category.trim()) {
      setError("Category is required");
      return;
    }
    if (!form.video_url.trim()) {
      setError("Upload a video or paste a video URL");
      return;
    }
    setSaving(true);
    setError("");
    const payload = {
      kind: form.kind,
      status: form.status,
      name: form.name.trim(),
      mobile: form.mobile.trim(),
      category: form.category.trim(),
      address: form.address.trim(),
      title: form.title.trim(),
      description: form.description.trim(),
      video_url: form.video_url.trim(),
    };
    try {
      if (editingId) await updateAdminAchieversLobby(editingId, payload);
      else await createAdminAchieversLobby(payload);
      setModalOpen(false);
      await fetchRows();
    } catch (err) {
      setError(err?.response?.data?.error || "Save failed");
    } finally {
      setSaving(false);
    }
  };

  const onDelete = async (row) => {
    if (!window.confirm(`Delete "${row.name}"? This cannot be undone.`)) return;
    try {
      await deleteAdminAchieversLobby(row.id);
      await fetchRows();
    } catch (err) {
      alert(err?.response?.data?.error || "Delete failed");
    }
  };

  const onStatus = async (row, next) => {
    setBusyId(row.id);
    try {
      const updated = await setAdminAchieversLobbyStatus(row.id, next);
      setRows((prev) => prev.map((r) => (r.id === row.id ? { ...r, ...updated.data } : r)));
      await fetchRows();
    } catch (err) {
      alert(err?.response?.data?.error || "Failed to update status");
    } finally {
      setBusyId(null);
    }
  };

  const openCatCreate = () => {
    setCatEditingId(null);
    setCatForm(emptyCat());
    setError("");
    setCatModal(true);
  };

  const openCatEdit = (row) => {
    setCatEditingId(row.id);
    setCatForm({
      kind: row.kind || "achiever",
      name: row.name || "",
      name_kn: row.name_kn || "",
      sort_order: row.sort_order ?? 0,
      status: row.status || "active",
    });
    setError("");
    setCatModal(true);
  };

  const onSaveCat = async (e) => {
    e.preventDefault();
    if (!catForm.name.trim()) {
      setError("Category name is required");
      return;
    }
    setCatSaving(true);
    setError("");
    const payload = {
      kind: catForm.kind,
      name: catForm.name.trim(),
      name_kn: catForm.name_kn.trim(),
      sort_order: Number(catForm.sort_order) || 0,
      status: catForm.status,
    };
    try {
      if (catEditingId) await updateAdminLobbyCategory(catEditingId, payload);
      else await createAdminLobbyCategory(payload);
      setCatModal(false);
      await fetchCats();
    } catch (err) {
      setError(err?.response?.data?.error || "Save failed");
    } finally {
      setCatSaving(false);
    }
  };

  const onDeleteCat = async (row) => {
    if (!window.confirm(`Delete category "${row.name}"?`)) return;
    try {
      await deleteAdminLobbyCategory(row.id);
      await fetchCats();
    } catch (err) {
      alert(err?.response?.data?.error || "Delete failed");
    }
  };

  return (
    <div className="service-reg-page">
      <div className="sr-toolbar">
        <div>
          <h1 style={{ display: "flex", alignItems: "center", gap: "0.5rem", margin: 0 }}>
            <Trophy size={22} /> Achievers Lobby
          </h1>
          <p style={{ margin: "0.35rem 0 0", color: "var(--text-muted)", fontSize: "0.9rem" }}>
            Review video submissions. Active items appear in the app Achievers and Innovations tabs.
          </p>
        </div>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          <button
            type="button"
            className={`sr-btn ${view === "videos" ? "sr-btn-primary" : "sr-btn-ghost"}`}
            onClick={() => setView("videos")}
          >
            Videos
          </button>
          <button
            type="button"
            className={`sr-btn ${view === "categories" ? "sr-btn-primary" : "sr-btn-ghost"}`}
            onClick={() => setView("categories")}
          >
            Categories
          </button>
          {view === "videos" ? (
            <button type="button" className="sr-btn sr-btn-primary" onClick={openCreate}>
              <Plus size={16} /> Add video
            </button>
          ) : (
            <button type="button" className="sr-btn sr-btn-primary" onClick={openCatCreate}>
              <Plus size={16} /> Add category
            </button>
          )}
        </div>
      </div>

      {view === "videos" ? (
        <>
          <div className="sr-filter-tabs">
            {STATUS_TABS.map((f) => (
              <button
                key={f.id}
                type="button"
                className={`sr-filter-tab ${status === f.id ? "active" : ""}`}
                onClick={() => setStatus(f.id)}
              >
                {f.label}
              </button>
            ))}
          </div>
          <div style={{ display: "flex", gap: 12, flexWrap: "wrap", alignItems: "center" }}>
            <div className="sr-filter-tabs">
              {KIND_TABS.map((f) => (
                <button
                  key={f.id || "all"}
                  type="button"
                  className={`sr-filter-tab ${kind === f.id ? "active" : ""}`}
                  onClick={() => setKind(f.id)}
                >
                  {f.label}
                </button>
              ))}
            </div>
            <div className="sr-search">
              <input
                type="search"
                placeholder="Search name, category, title…"
                value={q}
                onChange={(e) => setQ(e.target.value)}
              />
            </div>
          </div>

          <div className="sr-list-card">
            <div className="sr-list-header">
              <span className="sr-count">{total} video{total === 1 ? "" : "s"}</span>
              <div className="sr-pagination">
                <span>
                  Page {page} / {totalPages}
                </span>
                <div className="sr-page-btns">
                  <button
                    type="button"
                    className="sr-btn sr-btn-ghost"
                    disabled={page <= 1 || loading}
                    onClick={() => setPage((p) => Math.max(1, p - 1))}
                  >
                    <ChevronLeft size={16} />
                  </button>
                  <button
                    type="button"
                    className="sr-btn sr-btn-ghost"
                    disabled={page >= totalPages || loading}
                    onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
                  >
                    <ChevronRight size={16} />
                  </button>
                </div>
              </div>
            </div>
            {loading ? (
              <div className="sr-empty" style={{ padding: "2rem", display: "flex", justifyContent: "center" }}>
                <Loader2 className="spinner" size={28} />
              </div>
            ) : (
              <div className="sr-table-wrap" style={{ overflowX: "auto" }}>
                <table className="sr-table" style={{ width: "100%", borderCollapse: "collapse", fontSize: "0.875rem" }}>
                  <thead>
                    <tr>
                      <th style={th}>Name</th>
                      <th style={th}>Kind</th>
                      <th style={th}>Category</th>
                      <th style={th}>Mobile</th>
                      <th style={th}>Address</th>
                      <th style={th}>Status</th>
                      <th style={th}>Submitted</th>
                      <th style={{ ...th, textAlign: "center" }}>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {rows.length === 0 ? (
                      <tr>
                        <td colSpan={8}>
                          <div className="sr-empty" style={{ padding: "1.5rem" }}>No videos yet</div>
                        </td>
                      </tr>
                    ) : (
                      rows.map((row) => (
                        <tr key={row.id}>
                          <td style={td}>
                            <strong>{row.name}</strong>
                            {row.title ? <div style={{ color: "var(--text-muted)", fontSize: "0.8rem" }}>{row.title}</div> : null}
                          </td>
                          <td style={td}>{row.kind === "innovation" ? "Innovation" : "Achiever"}</td>
                          <td style={td}>{row.category}</td>
                          <td style={td}>{row.mobile || "—"}</td>
                          <td style={td}>{row.address || "—"}</td>
                          <td style={td}>{row.status}</td>
                          <td style={td}>{fmtDate(row.created_at)}</td>
                          <td style={{ ...td, textAlign: "center", whiteSpace: "nowrap" }}>
                            {row.status !== "active" && (
                              <button
                                type="button"
                                className="sr-btn sr-btn-ghost"
                                title="Activate"
                                disabled={busyId === row.id}
                                onClick={() => onStatus(row, "active")}
                              >
                                {busyId === row.id ? <Loader2 className="spinner" size={16} /> : <Check size={16} />}
                              </button>
                            )}
                            {row.status !== "rejected" && (
                              <button
                                type="button"
                                className="sr-btn sr-btn-ghost"
                                title="Reject"
                                disabled={busyId === row.id}
                                onClick={() => onStatus(row, "rejected")}
                              >
                                <X size={16} />
                              </button>
                            )}
                            <button type="button" className="sr-btn sr-btn-ghost" onClick={() => openEdit(row)}>
                              <Pencil size={16} />
                            </button>
                            <button type="button" className="sr-btn sr-btn-ghost" onClick={() => onDelete(row)}>
                              <Trash2 size={16} />
                            </button>
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </>
      ) : (
        <div className="sr-list-card">
          <div className="sr-table-wrap" style={{ overflowX: "auto" }}>
            <table className="sr-table" style={{ width: "100%", borderCollapse: "collapse", fontSize: "0.875rem" }}>
              <thead>
                <tr>
                  <th style={th}>Name</th>
                  <th style={th}>Kannada</th>
                  <th style={th}>Kind</th>
                  <th style={th}>Order</th>
                  <th style={th}>Status</th>
                  <th style={{ ...th, textAlign: "center" }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {categories.length === 0 ? (
                  <tr>
                    <td colSpan={6}>
                      <div className="sr-empty" style={{ padding: "1.5rem" }}>No categories yet</div>
                    </td>
                  </tr>
                ) : (
                  categories.map((row) => (
                    <tr key={row.id}>
                      <td style={td}><strong>{row.name}</strong></td>
                      <td style={td}>{row.name_kn || "—"}</td>
                      <td style={td}>{row.kind}</td>
                      <td style={td}>{row.sort_order}</td>
                      <td style={td}>{row.status}</td>
                      <td style={{ ...td, textAlign: "center" }}>
                        <button type="button" className="sr-btn sr-btn-ghost" onClick={() => openCatEdit(row)}>
                          <Pencil size={16} />
                        </button>
                        <button type="button" className="sr-btn sr-btn-ghost" onClick={() => onDeleteCat(row)}>
                          <Trash2 size={16} />
                        </button>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {modalOpen && (
        <div className="modal-overlay" onClick={() => !saving && setModalOpen(false)}>
          <div className="modal-content sr-modal" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 560 }}>
            <div className="modal-header sr-modal-header">
              <h2>{editingId ? "Edit video" : "Add video"}</h2>
              <button type="button" className="sr-btn sr-btn-ghost" onClick={() => setModalOpen(false)}>
                <X size={18} />
              </button>
            </div>
            <form onSubmit={onSave} style={{ display: "grid", gap: 12, padding: "0 1.25rem 1.25rem" }}>
              {error && (
                <div style={{ color: "#b91c1c", fontSize: "0.875rem" }}>{error}</div>
              )}
              <label>
                Tab
                <select
                  value={form.kind}
                  onChange={(e) => setForm((f) => ({ ...f, kind: e.target.value, category: "" }))}
                  style={inputStyle}
                >
                  <option value="achiever">Achiever</option>
                  <option value="innovation">Innovation</option>
                </select>
              </label>
              <label>
                Status
                <select
                  value={form.status}
                  onChange={(e) => setForm((f) => ({ ...f, status: e.target.value }))}
                  style={inputStyle}
                >
                  <option value="pending">Pending</option>
                  <option value="active">Active</option>
                  <option value="rejected">Rejected</option>
                </select>
              </label>
              <label>
                Name *
                <input
                  value={form.name}
                  onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
                  style={inputStyle}
                />
              </label>
              <label>
                Mobile *
                <input
                  value={form.mobile}
                  onChange={(e) => setForm((f) => ({ ...f, mobile: e.target.value }))}
                  style={inputStyle}
                />
              </label>
              <label>
                Category *
                <input
                  list="lobby-cats"
                  value={form.category}
                  onChange={(e) => setForm((f) => ({ ...f, category: e.target.value }))}
                  style={inputStyle}
                  placeholder="Type or pick a category"
                />
                <datalist id="lobby-cats">
                  {kindCats.map((c) => (
                    <option key={c.id} value={c.name} />
                  ))}
                </datalist>
              </label>
              <label>
                Address
                <input
                  value={form.address}
                  onChange={(e) => setForm((f) => ({ ...f, address: e.target.value }))}
                  style={inputStyle}
                />
              </label>
              <label>
                Title
                <input
                  value={form.title}
                  onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}
                  style={inputStyle}
                />
              </label>
              <label>
                Description
                <textarea
                  value={form.description}
                  onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
                  style={{ ...inputStyle, minHeight: 80 }}
                />
              </label>
              <div>
                <div style={{ fontWeight: 600, marginBottom: 6 }}>Video *</div>
                <label className="sr-btn sr-btn-ghost" style={{ display: "inline-flex", gap: 8, cursor: "pointer" }}>
                  <Upload size={16} /> {uploading ? "Uploading…" : "Upload video"}
                  <input type="file" accept="video/*" hidden onChange={onUpload} disabled={uploading} />
                </label>
                <input
                  value={form.video_url}
                  onChange={(e) => setForm((f) => ({ ...f, video_url: e.target.value }))}
                  style={{ ...inputStyle, marginTop: 8 }}
                  placeholder="/uploads/achievers-lobby/…"
                />
                {form.video_url ? (
                  <video
                    src={mediaUrl(form.video_url)}
                    controls
                    style={{ width: "100%", maxHeight: 220, marginTop: 8, borderRadius: 8, background: "#000" }}
                  />
                ) : null}
              </div>
              <button type="submit" className="sr-btn sr-btn-primary" disabled={saving || uploading}>
                {saving ? <Loader2 className="spinner" size={16} /> : null}
                {editingId ? "Save changes" : "Add video"}
              </button>
            </form>
          </div>
        </div>
      )}

      {catModal && (
        <div className="modal-overlay" onClick={() => !catSaving && setCatModal(false)}>
          <div className="modal-content sr-modal" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 440 }}>
            <div className="modal-header sr-modal-header">
              <h2>{catEditingId ? "Edit category" : "Add category"}</h2>
              <button type="button" className="sr-btn sr-btn-ghost" onClick={() => setCatModal(false)}>
                <X size={18} />
              </button>
            </div>
            <form onSubmit={onSaveCat} style={{ display: "grid", gap: 12, padding: "0 1.25rem 1.25rem" }}>
              {error && (
                <div style={{ color: "#b91c1c", fontSize: "0.875rem" }}>{error}</div>
              )}
              <label>
                Kind
                <select
                  value={catForm.kind}
                  onChange={(e) => setCatForm((f) => ({ ...f, kind: e.target.value }))}
                  style={inputStyle}
                >
                  <option value="achiever">Achiever</option>
                  <option value="innovation">Innovation</option>
                  <option value="both">Both</option>
                </select>
              </label>
              <label>
                Name *
                <input
                  value={catForm.name}
                  onChange={(e) => setCatForm((f) => ({ ...f, name: e.target.value }))}
                  style={inputStyle}
                />
              </label>
              <label>
                Kannada name
                <input
                  value={catForm.name_kn}
                  onChange={(e) => setCatForm((f) => ({ ...f, name_kn: e.target.value }))}
                  style={inputStyle}
                />
              </label>
              <label>
                Sort order
                <input
                  type="number"
                  value={catForm.sort_order}
                  onChange={(e) => setCatForm((f) => ({ ...f, sort_order: e.target.value }))}
                  style={inputStyle}
                />
              </label>
              <label>
                Status
                <select
                  value={catForm.status}
                  onChange={(e) => setCatForm((f) => ({ ...f, status: e.target.value }))}
                  style={inputStyle}
                >
                  <option value="active">Active</option>
                  <option value="inactive">Inactive</option>
                </select>
              </label>
              <button type="submit" className="sr-btn sr-btn-primary" disabled={catSaving}>
                {catSaving ? <Loader2 className="spinner" size={16} /> : null}
                Save category
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default AchieversLobbyAdmin;
