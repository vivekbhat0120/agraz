import React, { useCallback, useEffect, useMemo, useState } from "react";
import { Milk, Loader2, ChevronLeft, ChevronRight, Plus, Pencil, Trash2, X } from "lucide-react";
import {
  getUsers,
  getAdminDairySummary,
  getAdminDairyCustomers,
  createAdminDairyCustomer,
  updateAdminDairyCustomer,
  deleteAdminDairyCustomer,
  getAdminDairyEntries,
  createAdminDairyEntry,
  updateAdminDairyEntry,
  deleteAdminDairyEntry,
} from "../api/api";
import "./ServiceRegistrations.css";
import "./UserList.css";

const limit = 20;

const OWNER_KINDS = [
  { id: "collected", label: "Milk collected (from customer)" },
  { id: "sold", label: "Milk sold (to customer)" },
  { id: "paid", label: "Paid to customer" },
  { id: "received", label: "Received from customer" },
];

function money(v) {
  const n = Number(v) || 0;
  return `₹${n.toLocaleString("en-IN", { maximumFractionDigits: 2 })}`;
}

function liters(v) {
  const n = Number(v) || 0;
  return `${n.toLocaleString("en-IN", { maximumFractionDigits: 2 })} L`;
}

function todayIso() {
  return new Date().toISOString().slice(0, 10);
}

const emptyCustomer = () => ({
  name: "",
  mobile: "",
  village: "",
  default_rate: "",
  notes: "",
});

const emptyEntry = () => ({
  owner_kind: "collected",
  customer_id: "",
  party_name: "",
  party_mobile: "",
  date: todayIso(),
  shift: "morning",
  quantity_liters: "",
  rate_per_liter: "",
  amount: "",
  narration: "",
});

const DairyAdmin = () => {
  const [tab, setTab] = useState("entries");
  const [users, setUsers] = useState([]);
  const [userId, setUserId] = useState("");
  const [q, setQ] = useState("");
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [rows, setRows] = useState([]);
  const [customers, setCustomers] = useState([]);
  const [summary, setSummary] = useState(null);
  const [loading, setLoading] = useState(false);
  const [modalOpen, setModalOpen] = useState(false);
  const [editingId, setEditingId] = useState(null);
  const [custForm, setCustForm] = useState(emptyCustomer());
  const [entryForm, setEntryForm] = useState(emptyEntry());
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

  useEffect(() => {
    setPage(1);
  }, [q, userId, tab]);

  const loadCustomers = useCallback(async () => {
    if (!userId) {
      setCustomers([]);
      return;
    }
    try {
      const data = await getAdminDairyCustomers({ user_id: userId, q: q.trim() || undefined });
      setCustomers(data.data || []);
    } catch (e) {
      console.error(e);
      setCustomers([]);
    }
  }, [userId, q]);

  const loadSummary = useCallback(async () => {
    if (!userId) {
      setSummary(null);
      return;
    }
    try {
      const data = await getAdminDairySummary({ user_id: userId });
      setSummary(data);
    } catch (e) {
      console.error(e);
      setSummary(null);
    }
  }, [userId]);

  const fetchRows = useCallback(async () => {
    if (!userId) {
      setRows([]);
      setTotal(0);
      setLoading(false);
      return;
    }
    setLoading(true);
    try {
      if (tab === "customers") {
        const data = await getAdminDairyCustomers({ user_id: userId, q: q.trim() || undefined });
        const list = data.data || [];
        setRows(list);
        setTotal(data.total ?? list.length);
        setCustomers(list);
      } else {
        const data = await getAdminDairyEntries({
          user_id: userId,
          q: q.trim() || undefined,
        });
        const list = data.data || [];
        setRows(list);
        setTotal(data.total ?? list.length);
      }
    } catch (e) {
      console.error(e);
      setRows([]);
      setTotal(0);
    } finally {
      setLoading(false);
    }
  }, [tab, userId, q]);

  useEffect(() => {
    fetchRows();
    loadSummary();
    if (tab !== "customers") loadCustomers();
  }, [fetchRows, loadSummary, loadCustomers, tab]);

  const totalPages = Math.max(1, Math.ceil(total / limit) || 1);
  const paged = useMemo(() => {
    const start = (page - 1) * limit;
    return rows.slice(start, start + limit);
  }, [rows, page]);

  const isMilkKind = entryForm.owner_kind === "collected" || entryForm.owner_kind === "sold";

  const computedAmount = useMemo(() => {
    if (!isMilkKind) return Number(entryForm.amount) || 0;
    const qty = Number(entryForm.quantity_liters) || 0;
    const rate = Number(entryForm.rate_per_liter) || 0;
    if (qty && rate) return +(qty * rate).toFixed(2);
    return Number(entryForm.amount) || 0;
  }, [isMilkKind, entryForm.quantity_liters, entryForm.rate_per_liter, entryForm.amount]);

  const openCreate = () => {
    setEditingId(null);
    setError("");
    if (tab === "customers") setCustForm(emptyCustomer());
    else setEntryForm(emptyEntry());
    setModalOpen(true);
  };

  const openEdit = (row) => {
    setEditingId(row.id);
    setError("");
    if (tab === "customers") {
      setCustForm({
        name: row.name || "",
        mobile: row.mobile || "",
        village: row.village || "",
        default_rate: row.default_rate ?? "",
        notes: row.notes || "",
      });
    } else {
      setEntryForm({
        owner_kind: row.owner_kind || "collected",
        customer_id: row.customer_id ? String(row.customer_id) : "",
        party_name: row.party_name || "",
        party_mobile: row.party_mobile || "",
        date: String(row.date || todayIso()).slice(0, 10),
        shift: row.shift || "morning",
        quantity_liters: row.quantity_liters ?? "",
        rate_per_liter: row.rate_per_liter ?? "",
        amount: row.amount ?? "",
        narration: row.narration || "",
      });
    }
    setModalOpen(true);
  };

  const onCustomerPick = (id) => {
    const c = customers.find((x) => String(x.id) === String(id));
    setEntryForm((f) => ({
      ...f,
      customer_id: id,
      party_name: c?.name || f.party_name,
      party_mobile: c?.mobile || f.party_mobile,
      rate_per_liter: f.rate_per_liter || c?.default_rate || "",
    }));
  };

  const onSave = async (e) => {
    e.preventDefault();
    if (!userId) {
      setError("Select a dairy owner user first");
      return;
    }
    setSaving(true);
    setError("");
    try {
      if (tab === "customers") {
        if (!String(custForm.name || "").trim()) {
          setError("Name is required");
          setSaving(false);
          return;
        }
        const payload = {
          user_id: Number(userId),
          name: String(custForm.name).trim(),
          mobile: String(custForm.mobile || "").trim(),
          village: String(custForm.village || "").trim(),
          default_rate: Number(custForm.default_rate) || 0,
          notes: String(custForm.notes || "").trim(),
        };
        if (editingId) await updateAdminDairyCustomer(editingId, payload);
        else await createAdminDairyCustomer(payload);
      } else {
        if (!String(entryForm.party_name || "").trim()) {
          setError("Customer name is required");
          setSaving(false);
          return;
        }
        const payload = {
          user_id: Number(userId),
          owner_kind: entryForm.owner_kind,
          party_name: String(entryForm.party_name).trim(),
          party_mobile: String(entryForm.party_mobile || "").trim(),
          date: entryForm.date,
          shift: isMilkKind ? entryForm.shift : "",
          quantity_liters: Number(entryForm.quantity_liters) || 0,
          rate_per_liter: Number(entryForm.rate_per_liter) || 0,
          amount: computedAmount,
          narration: String(entryForm.narration || "").trim(),
        };
        if (entryForm.customer_id) payload.customer_id = Number(entryForm.customer_id);
        if (editingId) await updateAdminDairyEntry(editingId, payload);
        else await createAdminDairyEntry(payload);
      }
      setModalOpen(false);
      await fetchRows();
      await loadSummary();
      await loadCustomers();
    } catch (err) {
      setError(err?.response?.data?.error || "Save failed");
    } finally {
      setSaving(false);
    }
  };

  const onDelete = async (row) => {
    const label = tab === "customers" ? row.name : `${row.party_name} ${row.date || ""}`;
    if (!window.confirm(`Delete ${label}?`)) return;
    try {
      if (tab === "customers") await deleteAdminDairyCustomer(row.id, { user_id: userId });
      else await deleteAdminDairyEntry(row.id, { user_id: userId });
      await fetchRows();
      await loadSummary();
    } catch (err) {
      alert(err?.response?.data?.error || "Delete failed");
    }
  };

  return (
    <div className="service-reg-page">
      <div className="sr-toolbar">
        <div>
          <h1 style={{ display: "flex", alignItems: "center", gap: "0.5rem", margin: 0 }}>
            <Milk size={22} /> Dairy
          </h1>
          <p style={{ margin: "0.35rem 0 0", color: "var(--text-muted)", fontSize: "0.9rem" }}>
            Dairy owners record customer milk here. Matching mobile numbers show automatically on the
            customer&apos;s Dairy page in the app — no re-entry.
          </p>
        </div>
        <button
          type="button"
          className="sr-btn sr-btn-primary"
          onClick={openCreate}
          disabled={!userId}
        >
          <Plus size={16} /> {tab === "customers" ? "New customer" : "New milk entry"}
        </button>
      </div>

      <div className="sr-toolbar" style={{ gap: "0.75rem" }}>
        <select
          value={userId}
          onChange={(e) => setUserId(e.target.value)}
          style={{ minWidth: 240, padding: "0.65rem 0.75rem", borderRadius: 8, border: "1px solid var(--border)" }}
        >
          <option value="">Select dairy owner (user)</option>
          {users.map((u) => (
            <option key={u.id} value={u.id}>
              {(u.firstname || u.username || `User #${u.id}`) +
                (u.mobile_number ? ` (${u.mobile_number})` : "")}
            </option>
          ))}
        </select>
        <div className="sr-filter-tabs">
          <button
            type="button"
            className={`sr-filter-tab ${tab === "entries" ? "active" : ""}`}
            onClick={() => setTab("entries")}
          >
            Milk entries
          </button>
          <button
            type="button"
            className={`sr-filter-tab ${tab === "customers" ? "active" : ""}`}
            onClick={() => setTab("customers")}
          >
            Customers
          </button>
        </div>
        <div className="sr-search" style={{ flex: 1 }}>
          <input
            value={q}
            onChange={(e) => setQ(e.target.value)}
            placeholder="Search name / mobile…"
            style={{ width: "100%", border: "none", outline: "none", background: "transparent" }}
          />
        </div>
      </div>

      {summary && userId && (
        <div className="sr-list-card" style={{ padding: "1rem 1.1rem", display: "grid", gridTemplateColumns: "repeat(4, minmax(0, 1fr))", gap: 12 }}>
          <div>
            <div style={{ color: "var(--text-muted)", fontSize: 12 }}>Milk collected</div>
            <strong>{liters(summary.milk_bought_liters)}</strong>
          </div>
          <div>
            <div style={{ color: "var(--text-muted)", fontSize: 12 }}>Milk sold</div>
            <strong>{liters(summary.milk_given_liters)}</strong>
          </div>
          <div>
            <div style={{ color: "var(--text-muted)", fontSize: 12 }}>Payable to farmers</div>
            <strong>{money(summary.payable)}</strong>
          </div>
          <div>
            <div style={{ color: "var(--text-muted)", fontSize: 12 }}>Receivable</div>
            <strong>{money(summary.receivable)}</strong>
          </div>
        </div>
      )}

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

        {!userId ? (
          <div className="sr-empty" style={{ padding: "2rem" }}>
            Select a dairy owner user to view and enter milk records.
          </div>
        ) : loading ? (
          <div className="sr-empty" style={{ padding: "2rem", display: "flex", justifyContent: "center" }}>
            <Loader2 className="spinner" size={28} />
          </div>
        ) : (
          <div className="sr-table-wrap" style={{ overflowX: "auto" }}>
            <table className="sr-table" style={{ width: "100%", borderCollapse: "collapse", fontSize: "0.875rem" }}>
              <thead>
                {tab === "customers" ? (
                  <tr>
                    <th style={th}>Customer</th>
                    <th style={th}>Mobile</th>
                    <th style={th}>Village</th>
                    <th style={th}>App account</th>
                    <th style={th}>Payable</th>
                    <th style={{ ...th, textAlign: "center" }}>Actions</th>
                  </tr>
                ) : (
                  <tr>
                    <th style={th}>Date</th>
                    <th style={th}>Customer</th>
                    <th style={th}>Type</th>
                    <th style={th}>Qty / Amount</th>
                    <th style={{ ...th, textAlign: "center" }}>Actions</th>
                  </tr>
                )}
              </thead>
              <tbody>
                {paged.length === 0 ? (
                  <tr>
                    <td colSpan={6}>
                      <div className="sr-empty" style={{ padding: "1.5rem" }}>
                        No records yet
                      </div>
                    </td>
                  </tr>
                ) : tab === "customers" ? (
                  paged.map((row) => (
                    <tr key={row.id}>
                      <td style={td}><strong>{row.name}</strong></td>
                      <td style={td}>{row.mobile || "—"}</td>
                      <td style={td}>{row.village || "—"}</td>
                      <td style={td}>{row.linked_account ? "Yes" : "No"}</td>
                      <td style={td}>{money(row.balance?.payable)}</td>
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
                ) : (
                  paged.map((row) => (
                    <tr key={row.id}>
                      <td style={td}>{String(row.date || "").slice(0, 10)}</td>
                      <td style={td}>
                        <strong>{row.party_name}</strong>
                        <div style={{ color: "var(--text-muted)", fontSize: 12 }}>{row.party_mobile}</div>
                      </td>
                      <td style={td}>{row.owner_kind}</td>
                      <td style={td}>
                        {Number(row.quantity_liters) > 0 ? `${liters(row.quantity_liters)} · ` : ""}
                        {money(row.amount)}
                      </td>
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
          <div className="modal-content sr-modal" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 520 }}>
            <div className="modal-header sr-modal-header">
              <h2>
                {tab === "customers"
                  ? editingId
                    ? "Edit customer"
                    : "New customer"
                  : editingId
                    ? "Edit milk entry"
                    : "New milk entry"}
              </h2>
              <button type="button" className="sr-btn sr-btn-ghost" onClick={() => setModalOpen(false)}>
                <X size={18} />
              </button>
            </div>
            <form onSubmit={onSave} style={{ display: "grid", gap: 12, padding: "0 1.25rem 1.25rem" }}>
              {error && (
                <div style={{ color: "#dc2626", fontSize: "0.875rem" }}>{error}</div>
              )}
              {tab === "customers" ? (
                <>
                  <label>
                    Name *
                    <input
                      style={inputStyle}
                      value={custForm.name}
                      onChange={(e) => setCustForm((f) => ({ ...f, name: e.target.value }))}
                    />
                  </label>
                  <label>
                    Mobile
                    <input
                      style={inputStyle}
                      value={custForm.mobile}
                      onChange={(e) => setCustForm((f) => ({ ...f, mobile: e.target.value }))}
                    />
                  </label>
                  <label>
                    Village
                    <input
                      style={inputStyle}
                      value={custForm.village}
                      onChange={(e) => setCustForm((f) => ({ ...f, village: e.target.value }))}
                    />
                  </label>
                  <label>
                    Default rate / liter
                    <input
                      style={inputStyle}
                      type="number"
                      step="0.01"
                      value={custForm.default_rate}
                      onChange={(e) => setCustForm((f) => ({ ...f, default_rate: e.target.value }))}
                    />
                  </label>
                </>
              ) : (
                <>
                  <label>
                    Type
                    <select
                      style={inputStyle}
                      value={entryForm.owner_kind}
                      onChange={(e) => setEntryForm((f) => ({ ...f, owner_kind: e.target.value }))}
                    >
                      {OWNER_KINDS.map((k) => (
                        <option key={k.id} value={k.id}>{k.label}</option>
                      ))}
                    </select>
                  </label>
                  <label>
                    Existing customer
                    <select
                      style={inputStyle}
                      value={entryForm.customer_id}
                      onChange={(e) => onCustomerPick(e.target.value)}
                    >
                      <option value="">New / type below</option>
                      {customers.map((c) => (
                        <option key={c.id} value={c.id}>
                          {c.name} {c.mobile ? `(${c.mobile})` : ""}
                        </option>
                      ))}
                    </select>
                  </label>
                  <label>
                    Customer name *
                    <input
                      style={inputStyle}
                      value={entryForm.party_name}
                      onChange={(e) => setEntryForm((f) => ({ ...f, party_name: e.target.value }))}
                    />
                  </label>
                  <label>
                    Mobile
                    <input
                      style={inputStyle}
                      value={entryForm.party_mobile}
                      onChange={(e) => setEntryForm((f) => ({ ...f, party_mobile: e.target.value }))}
                    />
                  </label>
                  <label>
                    Date
                    <input
                      style={inputStyle}
                      type="date"
                      value={entryForm.date}
                      onChange={(e) => setEntryForm((f) => ({ ...f, date: e.target.value }))}
                    />
                  </label>
                  {isMilkKind && (
                    <>
                      <label>
                        Shift
                        <select
                          style={inputStyle}
                          value={entryForm.shift}
                          onChange={(e) => setEntryForm((f) => ({ ...f, shift: e.target.value }))}
                        >
                          <option value="morning">Morning</option>
                          <option value="evening">Evening</option>
                        </select>
                      </label>
                      <label>
                        Quantity (liters)
                        <input
                          style={inputStyle}
                          type="number"
                          step="0.001"
                          value={entryForm.quantity_liters}
                          onChange={(e) => setEntryForm((f) => ({ ...f, quantity_liters: e.target.value }))}
                        />
                      </label>
                      <label>
                        Rate / liter
                        <input
                          style={inputStyle}
                          type="number"
                          step="0.01"
                          value={entryForm.rate_per_liter}
                          onChange={(e) => setEntryForm((f) => ({ ...f, rate_per_liter: e.target.value }))}
                        />
                      </label>
                    </>
                  )}
                  <label>
                    Amount
                    <input
                      style={inputStyle}
                      type="number"
                      step="0.01"
                      value={isMilkKind ? computedAmount : entryForm.amount}
                      onChange={(e) => setEntryForm((f) => ({ ...f, amount: e.target.value }))}
                    />
                  </label>
                  <label>
                    Notes
                    <input
                      style={inputStyle}
                      value={entryForm.narration}
                      onChange={(e) => setEntryForm((f) => ({ ...f, narration: e.target.value }))}
                    />
                  </label>
                </>
              )}
              <div style={{ display: "flex", justifyContent: "flex-end", gap: 8, marginTop: 8 }}>
                <button type="button" className="sr-btn sr-btn-ghost" onClick={() => setModalOpen(false)}>
                  Cancel
                </button>
                <button type="submit" className="sr-btn sr-btn-primary" disabled={saving}>
                  {saving ? "Saving…" : "Save"}
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

export default DairyAdmin;
