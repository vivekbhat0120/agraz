import React, { useCallback, useEffect, useState } from "react";
import {
  FolderOpen,
  Folder,
  FileText,
  Loader2,
  Plus,
  Pencil,
  Trash2,
  X,
  Upload,
  ChevronRight,
  Image as ImageIcon,
} from "lucide-react";
import {
  getUsers,
  getAdminDocumentsBrowse,
  createAdminDocumentFolder,
  updateAdminDocumentFolder,
  deleteAdminDocumentFolder,
  getAdminUserDocument,
  createAdminUserDocument,
  updateAdminUserDocument,
  deleteAdminUserDocument,
  uploadAdminDocumentImages,
  getUploadsBaseUrl,
} from "../api/api";
import "./ServiceRegistrations.css";
import "./UserList.css";

function mediaUrl(path) {
  if (!path) return "";
  if (/^https?:\/\//i.test(path)) return path;
  const base = getUploadsBaseUrl();
  return path.startsWith("/") ? `${base}${path}` : `${base}/${path}`;
}

function userLabel(u) {
  return `${u.firstname || u.username || `User #${u.id}`}${
    u.mobile_number ? ` (${u.mobile_number})` : ""
  }`;
}

const inputStyle = {
  display: "block",
  width: "100%",
  marginTop: 6,
  padding: "0.6rem 0.75rem",
  borderRadius: 8,
  border: "1px solid var(--border)",
};

const DocumentsAdmin = () => {
  const [users, setUsers] = useState([]);
  const [userId, setUserId] = useState("");
  const [folderId, setFolderId] = useState(null);
  const [folderName, setFolderName] = useState("");
  const [folders, setFolders] = useState([]);
  const [documents, setDocuments] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const [folderModal, setFolderModal] = useState(false);
  const [folderEditingId, setFolderEditingId] = useState(null);
  const [folderFormName, setFolderFormName] = useState("");

  const [docModal, setDocModal] = useState(false);
  const [docEditingId, setDocEditingId] = useState(null);
  const [docName, setDocName] = useState("");
  const [docImages, setDocImages] = useState([]);
  const [uploading, setUploading] = useState(false);
  const [saving, setSaving] = useState(false);

  const [viewer, setViewer] = useState(null);

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

  const loadBrowse = useCallback(async () => {
    if (!userId) {
      setFolders([]);
      setDocuments([]);
      setLoading(false);
      return;
    }
    setLoading(true);
    setError("");
    try {
      const params = { user_id: userId };
      if (folderId) params.folder_id = folderId;
      const data = await getAdminDocumentsBrowse(params);
      setFolders(data.folders || []);
      setDocuments(data.documents || []);
      if (data.folder?.name) setFolderName(data.folder.name);
    } catch (e) {
      console.error(e);
      setFolders([]);
      setDocuments([]);
      setError(e?.response?.data?.error || "Failed to load documents");
    } finally {
      setLoading(false);
    }
  }, [userId, folderId]);

  useEffect(() => {
    loadBrowse();
  }, [loadBrowse]);

  const openRoot = () => {
    setFolderId(null);
    setFolderName("");
  };

  const openFolderModal = (row) => {
    setFolderEditingId(row?.id || null);
    setFolderFormName(row?.name || "");
    setError("");
    setFolderModal(true);
  };

  const saveFolder = async (e) => {
    e.preventDefault();
    if (!userId) return;
    const name = folderFormName.trim();
    if (!name) {
      setError("Folder name is required");
      return;
    }
    setSaving(true);
    setError("");
    try {
      const payload = { user_id: Number(userId), name };
      if (folderEditingId) await updateAdminDocumentFolder(folderEditingId, payload);
      else await createAdminDocumentFolder(payload);
      setFolderModal(false);
      await loadBrowse();
    } catch (err) {
      setError(err?.response?.data?.error || "Save failed");
    } finally {
      setSaving(false);
    }
  };

  const onDeleteFolder = async (row) => {
    if (!window.confirm(`Delete folder "${row.name}" and all documents inside?`)) return;
    try {
      await deleteAdminDocumentFolder(row.id, { user_id: userId });
      if (folderId === row.id) openRoot();
      else await loadBrowse();
    } catch (err) {
      alert(err?.response?.data?.error || "Delete failed");
    }
  };

  const openDocModal = async (row) => {
    setError("");
    if (row?.id) {
      try {
        const full = await getAdminUserDocument(row.id, { user_id: userId });
        setDocEditingId(full.id);
        setDocName(full.name || "");
        setDocImages(Array.isArray(full.images) ? full.images : []);
      } catch (err) {
        setError(err?.response?.data?.error || "Failed to load document");
        return;
      }
    } else {
      setDocEditingId(null);
      setDocName("");
      setDocImages([]);
    }
    setDocModal(true);
  };

  const onUploadFiles = async (e) => {
    const files = Array.from(e.target.files || []);
    e.target.value = "";
    if (!files.length) return;
    setUploading(true);
    setError("");
    try {
      const data = await uploadAdminDocumentImages(files);
      const urls = Array.isArray(data.urls) ? data.urls : data.url ? [data.url] : [];
      setDocImages((prev) => [...prev, ...urls]);
    } catch (err) {
      setError(err?.response?.data?.error || "Upload failed");
    } finally {
      setUploading(false);
    }
  };

  const saveDocument = async (e) => {
    e.preventDefault();
    if (!userId) return;
    const name = docName.trim();
    if (!name) {
      setError("Document name is required");
      return;
    }
    if (!docImages.length) {
      setError("Add at least one image");
      return;
    }
    setSaving(true);
    setError("");
    try {
      const payload = {
        user_id: Number(userId),
        name,
        folder_id: folderId || 0,
        images: docImages,
      };
      if (docEditingId) await updateAdminUserDocument(docEditingId, payload);
      else await createAdminUserDocument(payload);
      setDocModal(false);
      await loadBrowse();
    } catch (err) {
      setError(err?.response?.data?.error || "Save failed");
    } finally {
      setSaving(false);
    }
  };

  const onDeleteDocument = async (row) => {
    if (!window.confirm(`Delete document "${row.name}" and its photos?`)) return;
    try {
      await deleteAdminUserDocument(row.id, { user_id: userId });
      await loadBrowse();
    } catch (err) {
      alert(err?.response?.data?.error || "Delete failed");
    }
  };

  const openViewer = async (row) => {
    try {
      const full = await getAdminUserDocument(row.id, { user_id: userId });
      setViewer({
        name: full.name || row.name,
        images: Array.isArray(full.images) ? full.images : [],
      });
    } catch (err) {
      alert(err?.response?.data?.error || "Failed to open document");
    }
  };

  return (
    <div className="service-reg-page">
      <div className="sr-toolbar">
        <div>
          <h1 style={{ display: "flex", alignItems: "center", gap: "0.5rem", margin: 0 }}>
            <FolderOpen size={22} /> Documents
          </h1>
          <p style={{ margin: "0.35rem 0 0", color: "var(--text-muted)", fontSize: "0.9rem" }}>
            Store personal papers such as Aadhaar and PAN. Create a folder per family member, or
            upload a document directly.
          </p>
        </div>
        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
          {!folderId && (
            <button
              type="button"
              className="sr-btn sr-btn-ghost"
              onClick={() => openFolderModal(null)}
              disabled={!userId}
            >
              <Plus size={16} /> New folder
            </button>
          )}
          <button
            type="button"
            className="sr-btn sr-btn-primary"
            onClick={() => openDocModal(null)}
            disabled={!userId}
          >
            <Upload size={16} /> Upload document
          </button>
        </div>
      </div>

      <div className="sr-toolbar" style={{ gap: "0.75rem" }}>
        <select
          value={userId}
          onChange={(e) => {
            setUserId(e.target.value);
            openRoot();
          }}
          style={{ minWidth: 240, padding: "0.65rem 0.75rem", borderRadius: 8, border: "1px solid var(--border)" }}
        >
          <option value="">Select user</option>
          {users.map((u) => (
            <option key={u.id} value={u.id}>
              {userLabel(u)}
            </option>
          ))}
        </select>
        {userId && (
          <div style={{ display: "flex", alignItems: "center", gap: 6, fontSize: "0.9rem" }}>
            <button type="button" className="sr-btn sr-btn-ghost" onClick={openRoot}>
              All
            </button>
            {folderId && (
              <>
                <ChevronRight size={14} />
                <strong>{folderName || "Folder"}</strong>
              </>
            )}
          </div>
        )}
      </div>

      <div className="sr-list-card">
        {!userId ? (
          <div className="sr-empty" style={{ padding: "2rem" }}>
            Select a user to view and upload documents.
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
                  <th style={{ textAlign: "left", padding: "0.75rem 1rem" }}>Name</th>
                  <th style={{ textAlign: "left", padding: "0.75rem 1rem" }}>Type</th>
                  <th style={{ textAlign: "left", padding: "0.75rem 1rem" }}>Items</th>
                  <th style={{ textAlign: "center", padding: "0.75rem 1rem" }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {folders.length === 0 && documents.length === 0 ? (
                  <tr>
                    <td colSpan={4}>
                      <div className="sr-empty" style={{ padding: "1.5rem" }}>
                        No folders or documents yet
                      </div>
                    </td>
                  </tr>
                ) : (
                  <>
                    {folders.map((row) => (
                      <tr key={`f-${row.id}`}>
                        <td style={{ padding: "0.7rem 1rem" }}>
                          <button
                            type="button"
                            className="sr-btn sr-btn-ghost"
                            onClick={() => {
                              setFolderId(row.id);
                              setFolderName(row.name);
                            }}
                            style={{ fontWeight: 700 }}
                          >
                            <Folder size={16} /> {row.name}
                          </button>
                        </td>
                        <td style={{ padding: "0.7rem 1rem", color: "var(--text-muted)" }}>Folder</td>
                        <td style={{ padding: "0.7rem 1rem" }}>{row.document_count || 0} documents</td>
                        <td style={{ padding: "0.7rem 1rem", textAlign: "center" }}>
                          <button type="button" className="sr-btn sr-btn-ghost" onClick={() => openFolderModal(row)}>
                            <Pencil size={16} />
                          </button>
                          <button type="button" className="sr-btn sr-btn-ghost" onClick={() => onDeleteFolder(row)}>
                            <Trash2 size={16} />
                          </button>
                        </td>
                      </tr>
                    ))}
                    {documents.map((row) => (
                      <tr key={`d-${row.id}`}>
                        <td style={{ padding: "0.7rem 1rem" }}>
                          <button
                            type="button"
                            className="sr-btn sr-btn-ghost"
                            onClick={() => openViewer(row)}
                            style={{ fontWeight: 700 }}
                          >
                            <FileText size={16} /> {row.name}
                          </button>
                        </td>
                        <td style={{ padding: "0.7rem 1rem", color: "var(--text-muted)" }}>Document</td>
                        <td style={{ padding: "0.7rem 1rem" }}>
                          {(row.images || []).length} photo{(row.images || []).length === 1 ? "" : "s"}
                        </td>
                        <td style={{ padding: "0.7rem 1rem", textAlign: "center" }}>
                          <button type="button" className="sr-btn sr-btn-ghost" onClick={() => openDocModal(row)}>
                            <Pencil size={16} />
                          </button>
                          <button type="button" className="sr-btn sr-btn-ghost" onClick={() => onDeleteDocument(row)}>
                            <Trash2 size={16} />
                          </button>
                        </td>
                      </tr>
                    ))}
                  </>
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {folderModal && (
        <div className="modal-overlay" onClick={() => !saving && setFolderModal(false)}>
          <div className="modal-content sr-modal" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 420 }}>
            <div className="modal-header sr-modal-header">
              <h2 style={{ margin: 0 }}>{folderEditingId ? "Rename folder" : "New folder"}</h2>
              <button type="button" className="sr-btn sr-btn-ghost" onClick={() => setFolderModal(false)}>
                <X size={18} />
              </button>
            </div>
            <form onSubmit={saveFolder} style={{ display: "grid", gap: 12, padding: "0 1.25rem 1.25rem" }}>
              {error && <div style={{ color: "#dc2626", fontSize: "0.875rem" }}>{error}</div>}
              <label>
                Folder name *
                <input
                  style={inputStyle}
                  value={folderFormName}
                  onChange={(e) => setFolderFormName(e.target.value)}
                  placeholder="Family member name"
                  autoFocus
                />
              </label>
              <button type="submit" className="sr-btn sr-btn-primary" disabled={saving}>
                {saving ? <Loader2 className="spinner" size={16} /> : null} Save
              </button>
            </form>
          </div>
        </div>
      )}

      {docModal && (
        <div className="modal-overlay" onClick={() => !saving && setDocModal(false)}>
          <div className="modal-content sr-modal" onClick={(e) => e.stopPropagation()} style={{ maxWidth: 560 }}>
            <div className="modal-header sr-modal-header">
              <h2 style={{ margin: 0 }}>{docEditingId ? "Edit document" : "Upload document"}</h2>
              <button type="button" className="sr-btn sr-btn-ghost" onClick={() => setDocModal(false)}>
                <X size={18} />
              </button>
            </div>
            <form onSubmit={saveDocument} style={{ display: "grid", gap: 12, padding: "0 1.25rem 1.25rem" }}>
              {error && <div style={{ color: "#dc2626", fontSize: "0.875rem" }}>{error}</div>}
              <label>
                Document name *
                <input
                  style={inputStyle}
                  value={docName}
                  onChange={(e) => setDocName(e.target.value)}
                  placeholder="Aadhaar, PAN, Driving licence…"
                />
              </label>
              <div>
                <div style={{ fontWeight: 600, marginBottom: 8 }}>Photos</div>
                <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
                  {docImages.map((src) => (
                    <div key={src} style={{ position: "relative" }}>
                      <img
                        src={mediaUrl(src)}
                        alt=""
                        style={{ width: 88, height: 88, objectFit: "cover", borderRadius: 8, border: "1px solid var(--border)" }}
                      />
                      <button
                        type="button"
                        className="sr-btn sr-btn-ghost"
                        onClick={() => setDocImages((prev) => prev.filter((p) => p !== src))}
                        style={{ position: "absolute", top: 0, right: 0, padding: 2, background: "#fff" }}
                      >
                        <X size={14} />
                      </button>
                    </div>
                  ))}
                </div>
                <label className="sr-btn sr-btn-ghost" style={{ marginTop: 10, display: "inline-flex", cursor: "pointer" }}>
                  {uploading ? <Loader2 className="spinner" size={16} /> : <ImageIcon size={16} />}
                  {uploading ? " Uploading…" : " Add photos"}
                  <input type="file" accept="image/*" multiple hidden onChange={onUploadFiles} />
                </label>
              </div>
              <button type="submit" className="sr-btn sr-btn-primary" disabled={saving || uploading}>
                {saving ? <Loader2 className="spinner" size={16} /> : null} Save
              </button>
            </form>
          </div>
        </div>
      )}

      {viewer && (
        <div className="modal-overlay" onClick={() => setViewer(null)}>
          <div
            className="modal-content sr-modal"
            onClick={(e) => e.stopPropagation()}
            style={{ maxWidth: 720, maxHeight: "90vh", overflow: "auto" }}
          >
            <div className="modal-header sr-modal-header">
              <h2 style={{ margin: 0 }}>{viewer.name}</h2>
              <button type="button" className="sr-btn sr-btn-ghost" onClick={() => setViewer(null)}>
                <X size={18} />
              </button>
            </div>
            <div style={{ padding: "0 1.25rem 1.25rem", display: "grid", gap: 12 }}>
              {viewer.images.length === 0 ? (
                <div className="sr-empty">No photos</div>
              ) : (
                viewer.images.map((src) => (
                  <a key={src} href={mediaUrl(src)} target="_blank" rel="noreferrer">
                    <img
                      src={mediaUrl(src)}
                      alt={viewer.name}
                      style={{ width: "100%", borderRadius: 10, border: "1px solid var(--border)" }}
                    />
                  </a>
                ))
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default DocumentsAdmin;
