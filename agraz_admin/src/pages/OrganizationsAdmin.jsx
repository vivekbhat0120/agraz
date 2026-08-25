import React, { useCallback, useEffect, useState } from "react";
import { Building2, Loader2, ChevronLeft, ChevronRight } from "lucide-react";
import {
  getAdminOrganizations,
  getAdminOrgLedgers,
  getAdminOrgTransactions,
  getUsers,
} from "../api/api";
import "./ServiceRegistrations.css";
import "./MarketReports.css";

const limit = 20;

function fmtDate(v) {
  if (!v) return "—";
  const s = String(v);
  if (s.length >= 10) return s.slice(0, 10);
  return s;
}

function money(v) {
  const n = Number(v) || 0;
  return `₹${n.toLocaleString("en-IN", { maximumFractionDigits: 2 })}`;
}

const OrganizationsAdmin = () => {
  const [tab, setTab] = useState("transactions"); // organizations | ledgers | transactions
  const [users, setUsers] = useState([]);
  const [userId, setUserId] = useState("");
  const [orgId, setOrgId] = useState("");
  const [from, setFrom] = useState("");
  const [to, setTo] = useState("");
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [rows, setRows] = useState([]);
  const [orgs, setOrgs] = useState([]);
  const [loading, setLoading] = useState(true);

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
  }, [tab, userId, orgId, from, to]);

  const loadOrgsFilter = useCallback(async () => {
    try {
      const params = { page: 1, limit: 200 };
      if (userId) params.user_id = userId;
      const data = await getAdminOrganizations(params);
      setOrgs(data.data || []);
    } catch (e) {
      console.error(e);
      setOrgs([]);
    }
  }, [userId]);

  useEffect(() => {
    loadOrgsFilter();
  }, [loadOrgsFilter]);

  const fetchRows = useCallback(async () => {
    setLoading(true);
    try {
      const params = { page, limit };
      if (userId) params.user_id = userId;
      if (orgId) params.organization_id = orgId;
      if (from) params.from = from;
      if (to) params.to = to;

      let data;
      if (tab === "organizations") {
        data = await getAdminOrganizations(params);
      } else if (tab === "ledgers") {
        data = await getAdminOrgLedgers(params);
      } else {
        data = await getAdminOrgTransactions(params);
      }
      setRows(data.data || []);
      setTotal(data.total ?? 0);
    } catch (e) {
      console.error(e);
      setRows([]);
      setTotal(0);
    } finally {
      setLoading(false);
    }
  }, [tab, page, userId, orgId, from, to]);

  useEffect(() => {
    fetchRows();
  }, [fetchRows]);

  const totalPages = Math.max(1, Math.ceil(total / limit));

  return (
    <div className="sr-page">
      <div className="sr-header">
        <div>
          <h1>
            <Building2 size={22} style={{ marginRight: 8, verticalAlign: -4 }} />
            Organizations
          </h1>
          <p>View users&apos; organizations, ledgers, and transactions</p>
        </div>
      </div>

      <div className="mr-filters" style={{ marginBottom: 16 }}>
        <div className="mr-filter-row">
          <label>
            User
            <select value={userId} onChange={(e) => setUserId(e.target.value)}>
              <option value="">All users</option>
              {users.map((u) => (
                <option key={u.id} value={u.id}>
                  {[u.firstname, u.lastname].filter(Boolean).join(" ") || u.email} (#{u.id})
                </option>
              ))}
            </select>
          </label>
          {tab === "transactions" && (
            <label>
              Organization
              <select value={orgId} onChange={(e) => setOrgId(e.target.value)}>
                <option value="">All</option>
                {orgs.map((o) => (
                  <option key={o.id} value={o.id}>
                    {o.name} (user #{o.user_id})
                  </option>
                ))}
              </select>
            </label>
          )}
          {tab === "transactions" && (
            <>
              <label>
                From
                <input type="date" value={from} onChange={(e) => setFrom(e.target.value)} />
              </label>
              <label>
                To
                <input type="date" value={to} onChange={(e) => setTo(e.target.value)} />
              </label>
            </>
          )}
        </div>
      </div>

      <div className="sr-tabs" style={{ display: "flex", gap: 8, marginBottom: 16 }}>
        {[
          { id: "transactions", label: "Transactions" },
          { id: "organizations", label: "Organizations" },
          { id: "ledgers", label: "Ledgers" },
        ].map((t) => (
          <button
            key={t.id}
            type="button"
            className={tab === t.id ? "sr-btn primary" : "sr-btn"}
            onClick={() => setTab(t.id)}
          >
            {t.label}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="sr-loading">
          <Loader2 className="spin" size={28} />
        </div>
      ) : (
        <div className="sr-table-wrap">
          <table className="sr-table">
            <thead>
              {tab === "organizations" && (
                <tr>
                  <th>ID</th>
                  <th>Name</th>
                  <th>User</th>
                  <th>Balance</th>
                  <th>Created</th>
                </tr>
              )}
              {tab === "ledgers" && (
                <tr>
                  <th>ID</th>
                  <th>Name</th>
                  <th>System</th>
                  <th>User</th>
                </tr>
              )}
              {tab === "transactions" && (
                <tr>
                  <th>Date</th>
                  <th>User</th>
                  <th>Organization</th>
                  <th>Ledger</th>
                  <th>Type</th>
                  <th>Mode</th>
                  <th>Amount</th>
                  <th>Transfer To</th>
                </tr>
              )}
            </thead>
            <tbody>
              {rows.length === 0 && (
                <tr>
                  <td colSpan={8} style={{ textAlign: "center" }}>
                    No records
                  </td>
                </tr>
              )}
              {tab === "organizations" &&
                rows.map((r) => (
                  <tr key={r.id}>
                    <td>{r.id}</td>
                    <td>{r.name}</td>
                    <td>
                      {r.user_name || "—"}
                      <div className="sr-muted">{r.user_email}</div>
                    </td>
                    <td>{money(r.balance)}</td>
                    <td>{fmtDate(r.created_at)}</td>
                  </tr>
                ))}
              {tab === "ledgers" &&
                rows.map((r) => (
                  <tr key={r.id}>
                    <td>{r.id}</td>
                    <td>{r.name}</td>
                    <td>{r.is_system ? "Yes" : "No"}</td>
                    <td>
                      {r.user_name || "—"}
                      <div className="sr-muted">{r.user_email}</div>
                    </td>
                  </tr>
                ))}
              {tab === "transactions" &&
                rows.map((r) => (
                  <tr key={r.id}>
                    <td>{fmtDate(r.date)}</td>
                    <td>
                      {r.user_name || "—"}
                      <div className="sr-muted">{r.user_email}</div>
                    </td>
                    <td>{r.organization?.name || r.organization_id}</td>
                    <td>{r.ledger?.name || r.ledger_id}</td>
                    <td>{r.type}</td>
                    <td>{r.transaction_mode}</td>
                    <td>{money(r.amount)}</td>
                    <td>{r.transfer_to_organization?.name || "—"}</td>
                  </tr>
                ))}
            </tbody>
          </table>
        </div>
      )}

      <div className="sr-pagination">
        <button
          type="button"
          className="sr-btn"
          disabled={page <= 1}
          onClick={() => setPage((p) => Math.max(1, p - 1))}
        >
          <ChevronLeft size={16} /> Prev
        </button>
        <span>
          Page {page} / {totalPages} · {total} total
        </span>
        <button
          type="button"
          className="sr-btn"
          disabled={page >= totalPages}
          onClick={() => setPage((p) => p + 1)}
        >
          Next <ChevronRight size={16} />
        </button>
      </div>
    </div>
  );
};

export default OrganizationsAdmin;
