import React, { useCallback, useEffect, useState } from "react";
import { CalendarDays, Loader2, Plus, Pencil, Trash2, X } from "lucide-react";
import {
  getUsers,
  getAdminEvents,
  createAdminEvent,
  updateAdminEvent,
  deleteAdminEvent,
} from "../api/api";
import "./ServiceRegistrations.css";
import "./UserList.css";

const RECURRENCE = [
  { id: "yearly", label: "Yearly" },
  { id: "monthly", label: "Monthly" },
  { id: "weekly", label: "Weekly" },
  { id: "daily", label: "Daily" },
];

function userLabel(u) {
  return `${u.firstname || u.username || `User #${u.id}`}${
    u.mobile_number ? ` (${u.mobile_number})` : ""
  }`;
}

function todayIso() {
  return new Date().toISOString().slice(0, 10);
}

function dateOnly(v) {
  if (!v) return "";
  return String(v).slice(0, 10);
}

function recurrenceLabel(v) {
  return RECURRENCE.find((r) => r.id === v)?.label || v || "Yearly";
}

const emptyForm = () => ({
  name: "",
  event_date: todayIso(),
  recurrence: "yearly",
  notify_time: "09:00",
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
const td = { padding: "0.7rem 1rem" };

const EventsAdmin = () => {
  const [users, setUsers] = useState([]);
  const [userId, setUserId] = useState("");
  const [q, setQ] = useState("");
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(false);
  const [modalOpen, setModalOpen] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [form, setForm] = useState(emptyForm());
  const [saving, setSaving] = useState(false);
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

  const fetchRows = useCallback(async () => {
    if (!userId) {
      setRows([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    setError("");
    try {
      const data = await getAdminEvents({
        user_id: userId,
        q: q.trim() || undefined,
      });
      setRows(data.data || []);
    } catch (e) {
      console.error(e);
      setRows([]);
      setError(e?.response?.data?.error || "Failed to load events");
    } finally {
      setLoading(false);
    }
  }, [userId, q]);

  useEffect(() => {
    fetchRows();
  }, [fetchRows]);

  const openCreate = () => {
    setEditingId(null);
    setError("");
    setForm(emptyForm());
    setModalOpen(true);
  };

  const openEdit = (row) => {
    setEditingId(row.id);
    setError("");
    setForm({
      name: row.name || "",
      event_date: dateOnly(row.event_date) || todayIso(),
      recurrence: row.recurrence || "yearly",
      notify_time: String(row.notify_time || "09:00").slice(0, 5),
    });
    setModalOpen(true);
  };

  const onSave = async (e) => {
    e.preventDefault();
    if (!userId) return;
    const name = form.name.trim();
    if (!name) {
      setError("Event name is required");
      return;
    }
    if (!form.event_date) {
      setError("Date is required");
      return;
    }
    setSaving(true);
    setError("");
    const payload = {
      user_id: Number(userId),
      name,
      event_date: form.event_date,
      recurrence: form.recurrence,
      notify_time: form.notify_time,
    };
    try {
      if (editingId) await updateAdminEvent(editingId, payload);
      else await createAdminEvent(payload);
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
      await deleteAdminEvent(row.id, { user_id: userId });
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
            <CalendarDays size={22} /> Event Manage
          </h1>
          <p style={{ margin: "0.35rem 0 0", color: "var(--text-muted)", fontSize: "0.9rem" }}>
            Birthdays, insurance renewals, and other reminders. The phone app plays an alarm at
            the notification time.
          </p>
        </div>
        <button
          type="button"
          className="sr-btn sr-btn-primary"
          onClick={openCreate}
          disabled={!userId}
        >
          <Plus size={16} /> Add event
        </button>
      </div>

      <div className="sr-toolbar" style={{ gap: "0.75rem" }}>
        <select
          value={userId}
          onChange={(e) => setUserId(e.target.value)}
          style={{ minWidth: 240, padding: "0.65rem 0.75rem", borderRadius: 8, border: "1px solid var(--border)" }}
        >
          <option value="">Select user</option>
          {users.map((u) => (
            <option key={u.id} value={u.id}>
              {userLabel(u)}
            </option>
          ))}
        </select>
        <input
          type="search"
          placeholder="Search event name"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          disabled={!userId}
          style={{ ...inputStyle, marginTop: 0, maxWidth: 280 }}
        />
      </div>

      <div className="sr-list-card">
        {!userId ? (
          <div className="sr-empty" style={{ padding: "2rem" }}>
            Select a user to view and manage events.
          </div>
        ) : loading ? (
          <div className="sr-empty" style={{ padding: "2rem", display: "flex", justifyContent: "center" }}>
            <Loader2 className="spinner" size={28} />
          </div>
        ) : (
          <div className="sr-table-wrap" style={{ overflowX: "auto" }}>
            <table className="sr-table" style={{ width: "100%", borderCollapse: "collapse", fontSize: "0.875rem" }}>
              <thead>
                <tr>
                  <th style={th}>Event</th>
                  <th style={th}>Date</th>
                  <th style={th}>Occurring</th>
                  <th style={th}>Notification time</th>
                  <th style={{ ...th, textAlign: "center" }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {rows.length === 0 ? (
                  <tr>
                    <td colSpan={5}>
                      <div className="sr-empty" style={{ padding: "1.5rem" }}>
                        {error || "No events yet"}
                      </div>
                    </td>
                  </tr>
                ) : (
                  rows.map((row) => (
                    <tr key={row.id}>
                      <td style={td}><strong>{row.name}</strong></td>
                      <td style={td}>{dateOnly(row.event_date)}</td>
                      <td style={td}>{recurrenceLabel(row.recurrence)}</td>
                      <td style={td}>{String(row.notify_time || "").slice(0, 5)}</td>
                      <td style={{ ...td, textAlign: "center" }}>
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

      {modalOpen && (
        <div className="modal-overlay" onClick={() => !saving && setModalOpen(false)}>
          <div className="modal-content sr-modal" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 480 }}>
            <div className="modal-header sr-modal-header">
              <h2>{editingId ? "Edit event" : "Add event"}</h2>
              <button type="button" className="sr-btn sr-btn-ghost" onClick={() => setModalOpen(false)}>
                <X size={18} />
              </button>
            </div>
            <form onSubmit={onSave} style={{ display: "grid", gap: 12, padding: "0 1.25rem 1.25rem" }}>
              {error && (
                <div style={{ color: "#dc2626", fontSize: "0.875rem" }}>{error}</div>
              )}
              <label>
                Event name *
                <input
                  style={inputStyle}
                  value={form.name}
                  onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
                  placeholder="e.g. Ravi birthday, LIC renewal"
                />
              </label>
              <label>
                Date *
                <input
                  style={inputStyle}
                  type="date"
                  value={form.event_date}
                  onChange={(e) => setForm((f) => ({ ...f, event_date: e.target.value }))}
                />
              </label>
              <label>
                Occurring
                <select
                  style={inputStyle}
                  value={form.recurrence}
                  onChange={(e) => setForm((f) => ({ ...f, recurrence: e.target.value }))}
                >
                  {RECURRENCE.map((r) => (
                    <option key={r.id} value={r.id}>{r.label}</option>
                  ))}
                </select>
              </label>
              <label>
                Notification time
                <input
                  style={inputStyle}
                  type="time"
                  value={form.notify_time}
                  onChange={(e) => setForm((f) => ({ ...f, notify_time: e.target.value }))}
                />
              </label>
              <div style={{ display: "flex", justifyContent: "flex-end", gap: 8, marginTop: 8 }}>
                <button type="button" className="sr-btn sr-btn-ghost" onClick={() => setModalOpen(false)} disabled={saving}>
                  Cancel
                </button>
                <button type="submit" className="sr-btn sr-btn-primary" disabled={saving}>
                  {saving ? <Loader2 className="spinner" size={16} /> : null}
                  {editingId ? "Update" : "Save"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};

export default EventsAdmin;
