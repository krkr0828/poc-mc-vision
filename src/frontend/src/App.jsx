import React, { useState } from "react";

const API_BASE = "http://127.0.0.1:8000";

export default function App() {
  const [file, setFile] = useState(null);
  const [requestId, setRequestId] = useState("");
  const [policy, setPolicy] = useState("cost");

  const [awsRes, setAwsRes] = useState(null);
  const [azureRes, setAzureRes] = useState(null);
  const [routerRes, setRouterRes] = useState(null);

  // S3 経由用
  const [s3Key, setS3Key] = useState("");
  const [s3AnalyzeRes, setS3AnalyzeRes] = useState(null);

  const onPick = (e) => {
    setAwsRes(null);
    setAzureRes(null);
    setRouterRes(null);
    setS3AnalyzeRes(null);
    setRequestId("");
    setS3Key("");
    setFile(e.target.files?.[0] ?? null);
  };

  // ---- 既存: ローカル→FastAPI→/api/upload
  const handleLocalUpload = async () => {
    if (!file) {
      alert("ファイルを選んでください");
      return;
    }
    const form = new FormData();
    form.append("file", file);
    form.append("file_name", file.name);
    const r = await fetch(`${API_BASE}/api/upload`, {
      method: "POST",
      body: form,
    });
    if (!r.ok) {
      alert("アップロード失敗");
      return;
    }
    const j = await r.json();
    setRequestId(j.request_id);
    alert("アップロード成功: req=" + j.request_id);
  };

  // ---- 既存: Azure 解析
  const handleAnalyzeAzure = async () => {
    if (!requestId) {
      alert("まず /api/upload を実行してください");
      return;
    }
    const r = await fetch(`${API_BASE}/api/analyze/azure`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ request_id: requestId, model_preset: "cheap" }),
    });
    const j = await r.json();
    setAzureRes(j);
  };

  // ---- 既存: AWS 解析（モック/実APIはサーバ側の USE_REAL でスイッチ）
  const handleAnalyzeAws = async () => {
    if (!requestId) {
      alert("まず /api/upload を実行してください");
      return;
    }
    const r = await fetch(`${API_BASE}/api/analyze/aws`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ request_id: requestId, model_preset: "cheap" }),
    });
    const j = await r.json();
    setAwsRes(j);
  };

  // ---- 既存: ルーター
  const handleRoute = async () => {
    if (!requestId) {
      alert("まず /api/upload を実行してください");
      return;
    }
    const r = await fetch(`${API_BASE}/api/route`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ request_id: requestId, policy }),
    });
    const j = await r.json();
    setRouterRes(j);
  };

  // ---- 新規: S3 に直接 PUT → /api/s3/analyze
  const handleS3UploadAndAnalyze = async () => {
    if (!file) {
      alert("ファイルを選んでください");
      return;
    }
    // 1) 署名URLを取得
    const presignRes = await fetch(
      `${API_BASE}/api/s3/presign?content_type=${encodeURIComponent(file.type || "image/jpeg")}`,
      { method: "POST" }
    );
    if (!presignRes.ok) {
      alert("presign 失敗");
      return;
    }
    const { url, key } = await presignRes.json();

    // 2) 取得した URL に PUT（CORS不要）
    const putRes = await fetch(url, { method: "PUT", body: file });
    if (!putRes.ok) {
      alert("S3 への PUT 失敗");
      return;
    }
    setS3Key(key);

    // 3) サーバ側で Azure に流して結果保存（DynamoDB）
    const analyzeRes = await fetch(`${API_BASE}/api/s3/analyze`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ s3_key: key }),
    });
    if (!analyzeRes.ok) {
      alert("S3 解析 API 失敗");
      return;
    }
    const j = await analyzeRes.json();
    setS3AnalyzeRes(j);
    alert("S3→解析 完了: request_id=" + j.request_id);
  };

  return (
    <div style={{ padding: 24, fontFamily: "system-ui, sans-serif" }}>
      <h1>PoC MC Vision (Mock)</h1>

      <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
        <input type="file" accept="image/*" onChange={onPick} />
        <button onClick={handleLocalUpload}>Upload (local→/api/upload)</button>

        <select value={policy} onChange={(e) => setPolicy(e.target.value)}>
          <option value="cost">policy: cost（Azure mini）</option>
          <option value="quality">policy: quality（AWS高品質）</option>
        </select>

        <button onClick={handleAnalyzeAzure}>Analyze Azure</button>
        <button onClick={handleAnalyzeAws}>Analyze AWS</button>
        <button onClick={handleRoute}>Route</button>

        <button onClick={handleS3UploadAndAnalyze}>
          S3にアップして解析（署名URL→PUT→/api/s3/analyze）
        </button>
      </div>

      <div style={{ marginTop: 12 }}>
        <div>request_id: <code>{requestId || "-"}</code></div>
        <div>S3 key: <code>{s3Key || "-"}</code></div>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 16, marginTop: 20 }}>
        <JsonPanel title="AWS Result" data={awsRes} />
        <JsonPanel title="Azure Result" data={azureRes} />
        <JsonPanel title="Router Result" data={routerRes} />
      </div>

      <div style={{ marginTop: 20 }}>
        <JsonPanel title="S3 Analyze Result (DynamoDB保存用の応答)" data={s3AnalyzeRes} />
      </div>
    </div>
  );
}

function JsonPanel({ title, data }) {
  return (
    <div style={{ border: "1px solid #444", borderRadius: 6, padding: 12, minHeight: 280 }}>
      <div style={{ fontWeight: "bold", marginBottom: 8 }}>{title}</div>
      <pre style={{ whiteSpace: "pre-wrap", wordBreak: "break-word" }}>
        {data ? JSON.stringify(data, null, 2) : "no data"}
      </pre>
    </div>
  );
}
