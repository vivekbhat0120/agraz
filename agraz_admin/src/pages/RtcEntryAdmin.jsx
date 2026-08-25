import React, { useCallback, useEffect, useMemo, useState } from "react";
import {
  Map,
  Loader2,
  ChevronLeft,
  ChevronRight,
  Plus,
  Pencil,
  Trash2,
  X,
  Upload,
} from "lucide-react";
import {
  getUsers,
  getAdminLandRtcs,
  createAdminLandRtc,
  updateAdminLandRtc,
  deleteAdminLandRtc,
  uploadAdminLandRtcDocument,
  getUploadsBaseUrl,
} from "../api/api";
import "./ServiceRegistrations.css";

const limit = 20;

const STATES = ["Karnataka"];
const DISTRICTS = ["Uttara Kannada"];
const TALUKS = [
  "Sirsi",
  "Siddapur",
  "Yellapur",
  "Mundgod",
  "Haliyal",
  "Joida",
  "Dandeli",
  "Karwar",
  "Ankola",
  "Kumta",
  "Honnavar",
  "Bhatkal",
];

const HOBLIS = {
  Sirsi: ["Sirsi", "Banavasi", "Sonda", "Sugavi", "Chipgi", "Hulekal", "Devanalli", "Bisalkoppa"],
  Siddapur: ["Siddapur", "Kansur", "Kyadgi", "Hareguli", "Bilagi"],
  Yellapur: ["Yellapur", "Kiravatti", "Idagundi", "Vajralli"],
  Mundgod: ["Mundgod", "Pala", "Bedasgaon", "Hangarki"],
  Haliyal: ["Haliyal", "Bhagawati", "Tattihalla", "Murkwad"],
  Joida: ["Joida", "Castle Rock", "Anshi", "Kumbarwada"],
  Dandeli: ["Dandeli", "Ambewadi"],
  Karwar: ["Karwar", "Chittakula", "Kadwad", "Majali"],
  Ankola: ["Ankola", "Belase", "Achave", "Agsur"],
  Kumta: ["Kumta", "Gokarna", "Mirjan", "Baad", "Kagal"],
  Honnavar: ["Honnavar", "Manki", "Karki", "Idagunji"],
  Bhatkal: ["Bhatkal", "Murdeshwar", "Mavinkurve", "Shirali"],
};

function normalizeArea(acre, gunta, ana) {
  let a = Number(acre) || 0;
  let g = Number(gunta) || 0;
  let n = Number(ana) || 0;
  g += Math.floor(n / 4);
  n = n % 4;
  a += Math.floor(g / 40);
  g = g % 40;
  const total = a + g / 40 + n / 160;
  return { acre: a, gunta: g, ana: n, total };
}

function mediaUrl(path) {
  if (!path) return "";
  if (/^https?:\/\//i.test(path)) return path;
  const base = getUploadsBaseUrl();
  return path.startsWith("/") ? `${base}${path}` : `${base}/${path}`;
}

const emptyForm = () => ({
  user_id: "",
  state: "Karnataka",
  district: "Uttara Kannada",
  taluk: "Sirsi",
  hobli: "Sirsi",
  survey_number: "",
  hissa: "",
  acre: 0,
  gunta: 0,
  ana: 0,
  details: "",
  document_url: "",
});

const RtcEntryAdmin = () => {
  const [rows, setRows] = useState([]);
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [q, setQ] = useState("");
  const [userId, setUserId] = useState("");
  const [modalOpen, setModalOpen] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState(emptyForm());
  const [saving, setSaving] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    (async () => {
      try {
        const data = await getUsers(1, 500);
        setUsers(data.data || data.users || []);
      } catch (e) {
        console.error(e);
      }
    })();
  }, []);

  useEffect(() => {
    setPage(1);
  }, [q, userId]);

  const fetchRows = useCallback(async () => {
    setLoading(true);
    try {
      const params = { page, limit };
      if (q.trim()) params.q = q.trim();
      if (userId) params.user_id = userId;
      const data = await getAdminLandRtcs(params);
      setRows(data.data || []);
      setTotal(data.total ?? 0);
    } catch (e) {
      console.error(e);
      setRows([]);
      setTotal(0);
    } finally {
      setLoading(false);
    }
  }, [page, q, userId]);

  useEffect(() => {
    fetchRows();
  }, [fetchRows]);

  const totalPages = Math.max(1, Math.ceil(total / limit) || 1);
  const hobliOptions = HOBLIS[form.taluk] || [];
  const area = useMemo(
    () => normalizeArea(form.acre, form.gunta, form.ana),
    [form.acre, form.gunta, form.ana]
  );

  const openCreate = () => {
    setEditingId(null);
    setForm(emptyForm());
    setError("");
    setModalOpen(true);
  };

  const openEdit = (row) => {
    setEditingId(row.id);
    setForm({
      user_id: String(row.user_id || ""),
      state: row.state || "Karnataka",
      district: row.district || "Uttara Kannada",
      taluk: row.taluk || "Sirsi",
      hobli: row.hobli || "",
      survey_number: row.survey_number || "",
      hissa: row.hissa || "",
      acre: row.acre || 0,
      gunta: row.gunta || 0,
      ana: row.ana || 0,
      details: row.details || "",
      document_url: row.document_url || "",
    });
    setError("");
    setModalOpen(true);
  };

  const onTalukChange = (taluk) => {
    const list = HOBLIS[taluk] || [];
    setForm((f) => ({
      ...f,
      taluk,
      hobli: list.includes(f.hobli) ? f.hobli : list[0] || "",
    }));
  };

  const onUpload = async (e) => {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file) return;
    setUploading(true);
    setError("");
    try {
      const data = await uploadAdminLandRtcDocument(file);
      setForm((f) => ({ ...f, document_url: data.url || "" }));
    } catch (err) {
      setError(err?.response?.data?.error || "Upload failed");
    } finally {
      setUploading(false);
    }
  };

  const onSave = async (e) => {
    e.preventDefault();
    if (!form.user_id) {
      setError("Select a user");
      return;
    }
    if (!String(form.survey_number || "").trim()) {
      setError("Survey number is required");
      return;
    }
    setSaving(true);
    setError("");
    try {
      const payload = {
        user_id: Number(form.user_id),
        state: form.state,
        district: form.district,
        taluk: form.taluk,
        hobli: form.hobli,
        survey_number: String(form.survey_number).trim(),
        hissa: String(form.hissa || "").trim(),
        acre: area.acre,
        gunta: area.gunta,
        ana: area.ana,
        details: form.details || "",
        document_url: form.document_url || "",
      };
      if (editingId) {
        await updateAdminLandRtc(editingId, payload);
      } else {
        await createAdminLandRtc(payload);
      }
      setModalOpen(false);
      await fetchRows();
    } catch (err) {
      setError(err?.response?.data?.error || "Save failed");
    } finally {
      setSaving(false);
    }
  };

  const onDelete = async (row) => {
    if (!window.confirm(`Delete RTC survey ${row.survey_number || row.id}?`)) return;
    try {
      await deleteAdminLandRtc(row.id);
      await fetchRows();
    } catch (err) {
      alert(err?.response?.data?.error || "Delete failed");
    }
  };

  return (
    <div className="service-reg-page">
      <div className="sr-toolbar">
        <div>
          <h1 style={{ display: "flex", alignItems: "center", gap: "0.5rem", margin: 0 }}>
            <Map size={22} /> RTC Entry
          </h1>
          <p style={{ margin: "0.35rem 0 0", color: "var(--text-muted)", fontSize: "0.9rem" }}>
            Karnataka land records (RTC) — view, create, edit and delete entries.
          </p>
        </div>
        <button type="button" className="sr-btn sr-btn-primary" onClick={openCreate}>
          <Plus size={16} /> New RTC
        </button>
      </div>

      <div className="sr-toolbar" style={{ gap: "0.75rem" }}>
        <div className="sr-search" style={{ flex: 1 }}>
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Search survey / taluk / hobli…"
            style={{ width: "100%", border: "none", outline: "none", background: "transparent" }}
          />
        </div>
        <select
          value={userId}
          onChange={(e) => setUserId(e.target.value)}
          style={{ minWidth: 200, padding: "0.65rem 0.75rem", borderRadius: 8, border: "1px solid var(--border)" }}
        >
          <option value="">All users</option>
          {users.map((u) => (
            <option key={u.id} value={u.id}>
              {(u.firstname || u.username || `User #${u.id}`) +
                (u.mobile_number ? ` (${u.mobile_number})` : "")}
            </option>
          ))}
        </select>
      </div>

      <div className="sr-list-card">
        <div className="sr-list-header">
          <span className="sr-count">
            {total} record{total === 1 ? "" : "s"}
          </span>
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
                  <th style={th}>User</th>
                  <th style={th}>Location</th>
                  <th style={th}>Survey / Hissa</th>
                  <th style={th}>Area</th>
                  <th style={th}>Doc</th>
                  <th style={{ ...th, textAlign: "center" }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {rows.length === 0 ? (
                  <tr>
                    <td colSpan={6}>
                      <div className="sr-empty" style={{ padding: "1.5rem" }}>
                        No RTC entries found
                      </div>
                    </td>
                  </tr>
                ) : (
                  rows.map((row) => (
                    <tr key={row.id}>
                      <td style={td}>
                        <div style={{ fontWeight: 600 }}>{row.user_name || `User #${row.user_id}`}</div>
                        <div style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>
                          {row.user_phone || ""}
                        </div>
                      </td>
                      <td style={td}>
                        {row.district}
                        <br />
                        <span style={{ color: "var(--text-muted)" }}>
                          {row.taluk} · {row.hobli}
                        </span>
                      </td>
                      <td style={td}>
                        <strong>{row.survey_number}</strong>
                        {row.hissa ? ` / ${row.hissa}` : ""}
                      </td>
                      <td style={td}>
                        {row.acre}A · {row.gunta}G · {row.ana}An
                        <div style={{ fontSize: "0.75rem", color: "var(--text-muted)" }}>
                          {row.total_acres} acre
                        </div>
                      </td>
                      <td style={td}>
                        {row.document_url ? (
                          <a href={mediaUrl(row.document_url)} target="_blank" rel="noreferrer">
                            View
                          </a>
                        ) : (
                          "—"
                        )}
                      </td>
                      <td style={{ ...td, textAlign: "center" }}>
                        <button type="button" className="sr-btn sr-btn-ghost" onClick={() => openEdit(row)} title="Edit">
                          <Pencil size={16} />
                        </button>
                        <button type="button" className="sr-btn sr-btn-ghost" onClick={() => onDelete(row)} title="Delete">
                          <Trash2 size={16} color="#dc2626" />
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

      {modalOpen && (
        <div className="modal-overlay" onClick={() => !saving && setModalOpen(false)}>
          <div className="modal-content sr-modal" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 560 }}>
            <div className="modal-header sr-modal-header">
              <h2 style={{ margin: 0 }}>{editingId ? `Edit RTC #${editingId}` : "New RTC entry"}</h2>
              <button type="button" className="sr-btn sr-btn-ghost" onClick={() => setModalOpen(false)}>
                <X size={18} />
              </button>
            </div>
            <form onSubmit={onSave} style={{ display: "grid", gap: "0.75rem", padding: "0 1.25rem 1.25rem" }}>
              {error && (
                <div style={{ color: "#dc2626", fontSize: "0.875rem" }}>{error}</div>
              )}
              <label>
                User *
                <select
                  required
                  value={form.user_id}
                  onChange={(e) => setForm((f) => ({ ...f, user_id: e.target.value }))}
                  style={inputStyle}
                >
                  <option value="">Select user</option>
                  {users.map((u) => (
                    <option key={u.id} value={u.id}>
                      {(u.firstname || u.username || `User #${u.id}`) +
                        (u.mobile_number ? ` (${u.mobile_number})` : "")}
                    </option>
                  ))}
                </select>
              </label>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "0.75rem" }}>
                <label>
                  State
                  <select
                    value={form.state}
                    onChange={(e) => setForm((f) => ({ ...f, state: e.target.value }))}
                    style={inputStyle}
                  >
                    {STATES.map((s) => (
                      <option key={s} value={s}>
                        {s}
                      </option>
                    ))}
                  </select>
                </label>
                <label>
                  District
                  <select
                    value={form.district}
                    onChange={(e) => setForm((f) => ({ ...f, district: e.target.value }))}
                    style={inputStyle}
                  >
                    {DISTRICTS.map((d) => (
                      <option key={d} value={d}>
                        {d}
                      </option>
                    ))}
                  </select>
                </label>
              </div>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "0.75rem" }}>
                <label>
                  Taluk
                  <select value={form.taluk} onChange={(e) => onTalukChange(e.target.value)} style={inputStyle}>
                    {TALUKS.map((t) => (
                      <option key={t} value={t}>
                        {t}
                      </option>
                    ))}
                  </select>
                </label>
                <label>
                  Hobli
                  <select
                    value={form.hobli}
                    onChange={(e) => setForm((f) => ({ ...f, hobli: e.target.value }))}
                    style={inputStyle}
                  >
                    {hobliOptions.map((h) => (
                      <option key={h} value={h}>
                        {h}
                      </option>
                    ))}
                  </select>
                </label>
              </div>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "0.75rem" }}>
                <label>
                  Survey number *
                  <input
                    value={form.survey_number}
                    onChange={(e) => setForm((f) => ({ ...f, survey_number: e.target.value }))}
                    style={inputStyle}
                    required
                  />
                </label>
                <label>
                  Hissa
                  <input
                    value={form.hissa}
                    onChange={(e) => setForm((f) => ({ ...f, hissa: e.target.value }))}
                    style={inputStyle}
                  />
                </label>
              </div>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: "0.75rem" }}>
                <label>
                  Acre
                  <input
                    type="number"
                    min="0"
                    value={form.acre}
                    onChange={(e) => setForm((f) => ({ ...f, acre: e.target.value }))}
                    style={inputStyle}
                  />
                </label>
                <label>
                  Gunta
                  <input
                    type="number"
                    min="0"
                    value={form.gunta}
                    onChange={(e) => setForm((f) => ({ ...f, gunta: e.target.value }))}
                    style={inputStyle}
                  />
                </label>
                <label>
                  Ana
                  <input
                    type="number"
                    min="0"
                    value={form.ana}
                    onChange={(e) => setForm((f) => ({ ...f, ana: e.target.value }))}
                    style={inputStyle}
                  />
                </label>
              </div>
              <div
                style={{
                  padding: "0.65rem 0.85rem",
                  background: "var(--bg-main)",
                  borderRadius: 8,
                  fontWeight: 600,
                  fontSize: "0.875rem",
                }}
              >
                Total: {area.acre} A – {area.gunta} G – {area.ana} An ({area.total.toFixed(4)} acre)
              </div>
              <label>
                Details
                <textarea
                  value={form.details}
                  onChange={(e) => setForm((f) => ({ ...f, details: e.target.value }))}
                  rows={3}
                  style={{ ...inputStyle, resize: "vertical" }}
                />
              </label>
              <div>
                <div style={{ display: "flex", alignItems: "center", gap: "0.75rem", marginBottom: 6 }}>
                  <label className="sr-btn sr-btn-ghost" style={{ cursor: "pointer" }}>
                    <Upload size={16} /> {uploading ? "Uploading…" : "Upload PDF/JPG"}
                    <input type="file" accept=".pdf,.jpg,.jpeg,.png" hidden onChange={onUpload} disabled={uploading} />
                  </label>
                  {form.document_url && (
                    <a href={mediaUrl(form.document_url)} target="_blank" rel="noreferrer">
                      Current file
                    </a>
                  )}
                </div>
              </div>
              <div style={{ display: "flex", justifyContent: "flex-end", gap: "0.5rem", marginTop: 8 }}>
                <button type="button" className="sr-btn sr-btn-ghost" onClick={() => setModalOpen(false)} disabled={saving}>
                  Cancel
                </button>
                <button type="submit" className="sr-btn sr-btn-primary" disabled={saving || uploading}>
                  {saving ? "Saving…" : editingId ? "Update" : "Create"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

const th = {
  padding: "0.75rem 1rem",
  textAlign: "left",
  borderBottom: "1px solid var(--border)",
};

const td = {
  padding: "0.75rem 1rem",
  borderBottom: "1px solid var(--border)",
  verticalAlign: "top",
};

const inputStyle = {
  display: "block",
  width: "100%",
  marginTop: 4,
  padding: "0.55rem 0.7rem",
  borderRadius: 8,
  border: "1px solid var(--border)",
  background: "var(--surface)",
};

export default RtcEntryAdmin;
