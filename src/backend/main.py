import os, uuid, time, json, csv, pathlib, base64, io, logging
from typing import List, Optional
from PIL import Image
import requests
import boto3
from fastapi import FastAPI, UploadFile, File, Form, Request, HTTPException, status, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from dotenv import load_dotenv
from botocore.client import Config
from requests import Session, RequestException
import numpy as np

# ==== パス設定 ====
BASE = pathlib.Path(__file__).resolve().parents[2]
RESULTS_DIR = BASE / "results"
IMAGES_DIR = RESULTS_DIR / "images"
LOGS_DIR = RESULTS_DIR / "logs"
CONFIGS_DIR = BASE / "configs"

# ==== 環境変数 ====
load_dotenv(CONFIGS_DIR / ".env")  # configs/.env を読む
load_dotenv()
USE_REAL = os.getenv("USE_REAL", "0") == "1"

# ==== Runtime settings (env with sane defaults) ====
REQUEST_TIMEOUT_CONNECT = int(os.getenv("REQUEST_TIMEOUT_CONNECT", "10"))
REQUEST_TIMEOUT_TOTAL   = int(os.getenv("REQUEST_TIMEOUT_TOTAL", "30"))
AZURE_MAX_RETRIES       = int(os.getenv("AZURE_MAX_RETRIES", "3"))
AZURE_RETRY_BASE_SEC    = float(os.getenv("AZURE_RETRY_BASE_SEC", "1.0"))
S3_PRESIGN_EXPIRE_SEC   = int(os.getenv("S3_PRESIGN_EXPIRE_SEC", "300"))

API_KEY_OPTIONAL        = os.getenv("API_KEY_OPTIONAL", "1") == "1"
API_KEY_VALUE           = os.getenv("API_KEY_VALUE", "")
MAX_IMAGE_BYTES         = int(os.getenv("MAX_IMAGE_BYTES", str(2*1024*1024)))

# Azure
AZURE_ENDPOINT = os.getenv("AZURE_OPENAI_ENDPOINT", "").rstrip("/")
AZURE_KEY = os.getenv("AZURE_OPENAI_API_KEY", "")
AZURE_DEPLOY = os.getenv("AZURE_OPENAI_DEPLOYMENT_MINI", "gpt4omini-poc")
AZURE_API_VERSION = os.getenv("AZURE_OPENAI_API_VERSION", "2024-10-21")

# AWS
AWS_REGION = os.getenv("AWS_REGION", "ap-northeast-1")
BEDROCK_MODEL_ID = os.getenv("BEDROCK_MODEL_ID", "anthropic.claude-3-haiku-20240307-v1:0")
S3_UPLOAD_BUCKET = os.getenv("S3_UPLOAD_BUCKET", "poc-mc-vision-upload")
DDB_TABLE  = os.getenv("DDB_TABLE", "poc-mc-vision-table")

# ルーティング設定
MODEL_PRESET_COST = os.getenv("MODEL_PRESET_COST", "azure:gpt-4o-mini")
MODEL_PRESET_QUALITY = os.getenv("MODEL_PRESET_QUALITY", "aws:anthropic.claude-3-haiku-20240307-v1:0")

s3  = boto3.client("s3", region_name=AWS_REGION, config=Config(signature_version="s3v4"))
ddb = boto3.resource("dynamodb", region_name=AWS_REGION).Table(DDB_TABLE)

# ==== SageMaker Runtime (遅延初期化) ====
_smr_client = None

def _get_smr():
    global _smr_client
    if _smr_client is None:
        region = os.environ.get("AWS_REGION", "ap-northeast-1")
        _smr_client = boto3.client("sagemaker-runtime", region_name=region)
    return _smr_client

# ==== Bedrock Runtime (遅延初期化) ====
_bedrock_rt = None

def _get_bedrock_rt():
    global _bedrock_rt
    if _bedrock_rt is None:
        region = os.environ.get("AWS_REGION", "ap-northeast-1")
        _bedrock_rt = boto3.client("bedrock-runtime", region_name=region)
    return _bedrock_rt

print("USE_REAL =", USE_REAL)

# ==== 構造化ロガー（JSON） ====
logger = logging.getLogger("app")
logger.setLevel(logging.INFO)
if not logger.handlers:
    _h = logging.StreamHandler()
    _fmt = logging.Formatter('%(message)s')
    _h.setFormatter(_fmt)
    logger.addHandler(_h)

def log_json(**kwargs):
    try:
        logger.info(json.dumps(kwargs, ensure_ascii=False))
    except Exception:
        logger.info(str(kwargs))

# ==== 簡易APIキー検証（任意） ====
def require_api_key(request: Request):
    if not API_KEY_OPTIONAL:
        return
    key = request.headers.get("X-API-Key", "")
    if not key or key != API_KEY_VALUE:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="invalid api key")

# ==== FastAPI ====
app = FastAPI(title="PoC MC Vision (Real/Mock)")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://127.0.0.1:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==== スキーマ ====
class AnalyzeRequest(BaseModel):
    request_id: str
    s3_uri: Optional[str] = None
    model_preset: Optional[str] = "cheap"

class AnalyzeResponse(BaseModel):
    provider: str
    model: str
    caption: str
    tags: List[str]
    latency_ms: int
    tokens: dict
    cost_estimate: dict
    raw: dict

class RouteRequest(BaseModel):
    request_id: str
    s3_uri: Optional[str] = None
    policy: str

class RouteResponse(BaseModel):
    chosen: str
    reason: str
    result: AnalyzeResponse

class S3AnalyzeReq(BaseModel):
    s3_key: str

# ==== Util ====
def _log_csv(row: dict):
    LOGS_DIR.mkdir(parents=True, exist_ok=True)
    csv_path = LOGS_DIR / "poc_results.csv"
    new_file = not csv_path.exists()
    with open(csv_path, "a", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=list(row.keys()))
        if new_file:
            w.writeheader()
        w.writerow(row)

def _find_image_path_by_request_id(req_id: str) -> pathlib.Path:
    candidates = list(IMAGES_DIR.glob(f"{req_id}__*"))
    if not candidates:
        raise FileNotFoundError(f"image not found for request_id={req_id}")
    return candidates[0]

def _downscale_to_jpeg_b64(path: pathlib.Path, max_side: int = 512, quality: int = 80):
    """画像を512px以内に縮小・JPEG再圧縮してbase64化"""
    im = Image.open(path).convert("RGB")
    w, h = im.size
    if max(w, h) > max_side:
        if w >= h:
            nh = int(h * (max_side / w))
            nw = max_side
        else:
            nw = int(w * (max_side / h))
            nh = max_side
        im = im.resize((nw, nh))
    buf = io.BytesIO()
    im.save(buf, format="JPEG", quality=quality, optimize=True)
    b64 = base64.b64encode(buf.getvalue()).decode("utf-8")
    return b64, "image/jpeg"

# ==== モック応答 ====
def _mock_result(provider: str, model: str) -> AnalyzeResponse:
    return AnalyzeResponse(
        provider=provider,
        model=model,
        caption="テーブルの上に寿司が並べられています。",
        tags=["寿司", "テーブル", "食べ物"],
        latency_ms=0,
        tokens={"input": 50, "output": 30},
        cost_estimate={"usd": 0.0, "method": "mock"},
        raw={}
    )

# ==== 実API: Azure (gpt-4o-mini) ====
def call_azure_real(req_id: str) -> AnalyzeResponse:
    img_path = _find_image_path_by_request_id(req_id)
    b64, mime = _downscale_to_jpeg_b64(img_path)

    system_prompt = (
        "次の画像を説明してください。出力は必ず有効なJSONのみ、余計な文章は禁止。\n"
        '{ "caption": "日本語で1〜2文、50文字以内", "tags": ["日本語の単語を最大5個"] }'
    )

    user_content = [
        {"type": "text", "text": "画像を要約し、JSONのみで返してください。"},
        {"type": "image_url", "image_url": {"url": f"data:{mime};base64,{b64}"}}
    ]

    url = f"{AZURE_ENDPOINT}/openai/deployments/{AZURE_DEPLOY}/chat/completions?api-version={AZURE_API_VERSION}"
    headers = {"api-key": AZURE_KEY, "Content-Type": "application/json"}
    body = {
        "messages": [
            {"role": "system", "content": [{"type": "text", "text": system_prompt}]},
            {"role": "user", "content": user_content}
        ],
        "temperature": 0.2,
        "max_tokens": 128  # 抑えめ
    }

    t0 = time.time()
    out = None
    for attempt in range(3):
        resp = requests.post(url, headers=headers, json=body, timeout=60)
        if resp.status_code == 429:
            ra = resp.headers.get("Retry-After")
            wait = int(ra) if ra and ra.isdigit() else (2 * (attempt + 1))
            print(f"[Azure 429] retry in {wait}s (attempt {attempt+1}/3)")
            time.sleep(wait)
            continue
        if not resp.ok:
            print("AZURE ERROR", resp.status_code, resp.text[:300])
            resp.raise_for_status()
        out = resp.json()
        break
    if out is None:
        resp.raise_for_status()

    content = out["choices"][0]["message"]["content"]
    if isinstance(content, list):
        text = "".join([c.get("text", "") for c in content if isinstance(c, dict)])
    else:
        text = content or ""

    try:
        payload = json.loads(text)
    except Exception:
        s, e = text.find("{"), text.rfind("}")
        payload = json.loads(text[s:e + 1])

    latency = int((time.time() - t0) * 1000)
    return AnalyzeResponse(
        provider="azure",
        model="gpt-4o-mini",
        caption=str(payload.get("caption", "")),
        tags=list(payload.get("tags", [])),
        latency_ms=latency,
        tokens={"input": 0, "output": 0},
        cost_estimate={"usd": 0.0, "method": "token_based"},
        raw=out,
    )

# ==== Azure呼び出し：指数バックオフ＋タイムアウト ====
def azure_chat_completion_with_retry(endpoint: str, deployment: str, api_version: str, api_key: str, img_bytes: bytes, user_prompt: str) -> dict:
    url = f"{endpoint}/openai/deployments/{deployment}/chat/completions?api-version={api_version}"
    img_b64 = base64.b64encode(img_bytes).decode("utf-8")

    payload = {
        "messages": [
            {"role":"system","content":[{"type":"text","text":"You are a helpful vision assistant. Describe the image briefly and output 3 tags."}]},
            {"role":"user","content":[
                {"type":"text","text": user_prompt},
                {"type":"image_url","image_url": {"url": f"data:image/jpeg;base64,{img_b64}"}}
            ]}
        ],
        "max_tokens": 128
    }
    headers = {"api-key": api_key, "Content-Type":"application/json"}

    session = Session()
    for attempt in range(1, AZURE_MAX_RETRIES+1):
        t0 = time.time()
        try:
            resp = session.post(
                url, headers=headers, json=payload,
                timeout=(REQUEST_TIMEOUT_CONNECT, REQUEST_TIMEOUT_TOTAL)
            )
            if resp.status_code in (429, 500, 502, 503, 504):
                # リトライ系
                retry_after = resp.headers.get("retry-after")
                wait = float(retry_after) if retry_after else (AZURE_RETRY_BASE_SEC * (2 ** (attempt-1)))
                log_json(stage="azure_call", status="retry", attempt=attempt, code=resp.status_code, wait_sec=wait)
                time.sleep(wait)
                continue
            resp.raise_for_status()
            rt = round((time.time()-t0)*1000)
            log_json(stage="azure_call", status="ok", code=resp.status_code, rt_ms=rt)
            return resp.json()
        except RequestException as e:
            # 接続/タイムアウトもリトライ対象
            wait = AZURE_RETRY_BASE_SEC * (2 ** (attempt-1))
            log_json(stage="azure_call", status="exception", attempt=attempt, error=str(e), wait_sec=wait)
            if attempt < AZURE_MAX_RETRIES:
                time.sleep(wait)
            else:
                raise
    raise RuntimeError("Azure call exhausted retries")

def call_azure_from_bytes(img_bytes: bytes) -> dict:
    endpoint = os.environ["AZURE_OPENAI_ENDPOINT"].rstrip("/")
    deployment = os.environ["AZURE_OPENAI_DEPLOYMENT_MINI"]
    api_ver = os.environ.get("AZURE_OPENAI_API_VERSION", "2024-10-21")
    api_key = os.environ["AZURE_OPENAI_API_KEY"]

    # 画像サイズバリデーション（過大入力抑止）
    if len(img_bytes) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail=f"image too large: {len(img_bytes)} bytes (limit {MAX_IMAGE_BYTES})")

    return azure_chat_completion_with_retry(
        endpoint=endpoint,
        deployment=deployment,
        api_version=api_ver,
        api_key=api_key,
        img_bytes=img_bytes,
        user_prompt="この画像の内容を短く説明し、日本語で3つのタグを箇条書きで出力して下さい。"
    )

# ==== SageMaker呼び出し ====
def call_sagemaker_from_bytes(img_bytes: bytes) -> dict:
    """
    SageMaker Serverless Endpoint に画像をJSON形式で投げ、分類結果(JSON)を返す。
    TorchScript形式のモデルはJSON入力が必要。
      - 入力: 画像をNumPy配列に変換してJSON化
      - ヘッダ: ContentType='application/json'
      - 出力: JSON（推論結果）
    """
    
    endpoint = os.environ["SAGEMAKER_ENDPOINT_NAME"]
    
    # 画像バイナリをPIL経由でNumPy配列に変換
    img = Image.open(io.BytesIO(img_bytes)).convert('RGB')
    img = img.resize((224, 224))  # ResNet18の入力サイズ
    img_array = np.array(img, dtype=np.float32)
    
    # (H, W, C) -> (C, H, W) に変換
    img_array = img_array.transpose(2, 0, 1)
    
    # 正規化（ImageNet標準）
    mean = np.array([0.485, 0.456, 0.406]).reshape(3, 1, 1)
    std = np.array([0.229, 0.224, 0.225]).reshape(3, 1, 1)
    img_array = (img_array / 255.0 - mean) / std
    
    # バッチ次元を追加 (1, 3, 224, 224)
    img_array = np.expand_dims(img_array, axis=0)
    
    smr = _get_smr()
    resp = smr.invoke_endpoint(
        EndpointName=endpoint,
        ContentType="application/json",
        Body=json.dumps(img_array.tolist()),
    )
    body = resp["Body"].read()
    try:
        txt = body.decode("utf-8", errors="ignore")
        data = json.loads(txt)
        
        # 最も高いスコアのクラスを取得
        if isinstance(data, list) and len(data) > 0:
            scores = data[0]
            max_idx = int(np.argmax(scores))
            max_score = float(max(scores))
            
            result = {
                "predicted_class_index": max_idx,
                "confidence_score": max_score,
                "top_5_indices": [int(i) for i in np.argsort(scores)[-5:][::-1]],
                "all_scores": data
            }
        else:
            result = {"raw": data}
            
    except Exception as e:
        result = {"raw": body.decode("utf-8", errors="ignore"), "error": str(e)}
        
    return {
        "provider": "sagemaker",
        "endpoint": endpoint,
        "raw": result,
    }

# ==== Bedrock呼び出し ====
def call_bedrock_from_bytes(img_bytes: bytes) -> dict:
    """
    Bedrock Claude 3 Haiku に画像を渡して説明文を生成。
    - 入力: 画像バイナリ
    - 出力: {"text": "..."} を主とする辞書
    """
    model_id = os.environ.get("BEDROCK_MODEL_ID", "anthropic.claude-3-haiku-20240307-v1:0")
    brt = _get_bedrock_rt()

    # 画像をbase64に
    b64 = base64.b64encode(img_bytes).decode("utf-8")

    # Claude Messages 形式（Bedrock方言）
    body_payload = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 512,
        "temperature": 0.2,
        "messages": [
            {
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": b64
                        }
                    },
                    {
                        "type": "text",
                        "text": "画像の内容を短く説明し、3つのタグを日本語で列挙してください。"
                    }
                ]
            }
        ]
    }

    resp = brt.invoke_model(
        modelId=model_id,
        body=json.dumps(body_payload).encode("utf-8"),
        contentType="application/json",
        accept="application/json",
    )
    raw = resp["body"].read().decode("utf-8", errors="ignore")

    # 正規化（content[0].text を取り出す）
    try:
        data = json.loads(raw)
        text = ""
        if isinstance(data, dict) and "content" in data and data["content"]:
            # [{"type":"text","text":"..."}] 形式
            for part in data["content"]:
                if part.get("type") == "text":
                    text += part.get("text", "")
        norm = {"text": text.strip() or raw}
    except Exception:
        norm = {"text": raw}

    return {
        "provider": "bedrock",
        "model": model_id,
        "result": norm
    }

# ==== 実API: Bedrock (Claude 3 Haiku) ====
def call_bedrock_real(req_id: str) -> AnalyzeResponse:
    img_path = _find_image_path_by_request_id(req_id)
    b64, mime = _downscale_to_jpeg_b64(img_path)

    system_prompt = (
        "次の画像を説明してください。出力は必ず有効なJSONのみ、余計な文章は禁止。\n"
        '{ "caption": "日本語で1〜2文、50文字以内", "tags": ["日本語の単語を最大5個"] }'
    )
    user_content = [
        {"type": "image", "source": {"type": "base64", "media_type": mime, "data": b64}},
        {"type": "text", "text": "画像を要約し、上記仕様のJSONのみで返してください。"}
    ]

    client = boto3.client("bedrock-runtime", region_name=AWS_REGION)
    body = {
        "anthropic_version": "bedrock-2023-05-31",
        "max_tokens": 400,
        "temperature": 0.2,
        "system": system_prompt,
        "messages": [{"role": "user", "content": user_content}]
    }

    t0 = time.time()
    resp = client.invoke_model(
        modelId=BEDROCK_MODEL_ID,
        contentType="application/json",
        accept="application/json",
        body=json.dumps(body),
    )
    out = json.loads(resp["body"].read())
    text = out["content"][0]["text"] if out.get("content") else ""

    try:
        payload = json.loads(text)
    except Exception:
        s, e = text.find("{"), text.rfind("}")
        payload = json.loads(text[s:e + 1])

    latency = int((time.time() - t0) * 1000)
    return AnalyzeResponse(
        provider="aws",
        model=BEDROCK_MODEL_ID,
        caption=str(payload.get("caption", "")),
        tags=list(payload.get("tags", [])),
        latency_ms=latency,
        tokens={"input": 0, "output": 0},
        cost_estimate={"usd": 0.0, "method": "token_based"},
        raw=out,
    )

# ==== エンドポイント ====
@app.get("/healthz")
def healthz():
    return {"ok": True, "real": USE_REAL}

@app.post("/api/s3/presign")
def create_s3_presigned_url(content_type: str = Query("image/jpeg")):
    """
    S3に直接PUTするための 署名付きURL（有効期限: S3_PRESIGN_EXPIRE_SEC秒）
    - ポイント: SigV4 + リージョン直URL(virtual hosting) を強制
    """
    if not content_type:
        raise HTTPException(status_code=400, detail="content_type is required")

    key = f"uploads/{uuid.uuid4()}.jpg"

    s3_client = boto3.client(
        "s3",
        region_name=AWS_REGION,
        config=Config(
            signature_version="s3v4",
            s3={"addressing_style": "virtual"}  # URLを https://<bucket>.s3.<region>.amazonaws.com/... に
        ),
        endpoint_url=f"https://s3.{AWS_REGION}.amazonaws.com"
    )

    url = s3_client.generate_presigned_url(
        ClientMethod="put_object",
        Params={"Bucket": S3_UPLOAD_BUCKET, "Key": key, "ContentType": content_type},
        ExpiresIn=S3_PRESIGN_EXPIRE_SEC,
        HttpMethod="PUT",
    )
    return {"url": url, "key": key}

@app.post("/api/upload")
async def upload(file: UploadFile = File(...), file_name: Optional[str] = Form(None)):
    req_id = str(uuid.uuid4())
    fn = file_name or file.filename
    IMAGES_DIR.mkdir(parents=True, exist_ok=True)
    save_path = IMAGES_DIR / f"{req_id}__{fn}"
    with open(save_path, "wb") as out:
        out.write(await file.read())
    return {"request_id": req_id, "s3_uri": f"local://{save_path.name}"}

@app.post("/api/analyze/aws", response_model=AnalyzeResponse)
async def analyze_aws(req: AnalyzeRequest):
    t0 = time.time()
    if USE_REAL:
        res = call_bedrock_real(req.request_id)
    else:
        res = _mock_result("aws", "bedrock-claude-3-haiku")
        res.latency_ms = int((time.time() - t0) * 1000)

    _log_csv({
        "request_id": req.request_id,
        "policy": req.model_preset or "cheap",
        "provider": "aws",
        "model": res.model,
        "latency_ms": res.latency_ms,
        "cost_usd": res.cost_estimate["usd"]
    })
    return res

@app.post("/api/analyze/azure", response_model=AnalyzeResponse)
async def analyze_azure(req: AnalyzeRequest):
    t0 = time.time()
    if USE_REAL:
        res = call_azure_real(req.request_id)
    else:
        res = _mock_result("azure", "gpt-4o-mini")
        res.latency_ms = int((time.time() - t0) * 1000)

    _log_csv({
        "request_id": req.request_id,
        "policy": req.model_preset or "cheap",
        "provider": "azure",
        "model": res.model,
        "latency_ms": res.latency_ms,
        "cost_usd": res.cost_estimate["usd"]
    })
    return res

@app.post("/api/route", response_model=RouteResponse)
async def route(req: RouteRequest):
    # ポリシーに応じたプリセットを取得
    if req.policy == "cost":
        preset = MODEL_PRESET_COST
    elif req.policy == "quality":
        preset = MODEL_PRESET_QUALITY
    else:
        # デフォルトはコスト優先
        preset = MODEL_PRESET_COST

    # "provider:model" の形式をパース
    try:
        provider, model = preset.split(":", 1)
    except ValueError:
        raise HTTPException(status_code=500, detail=f"Invalid preset format: {preset}")

    chosen = provider
    reason = f"policy={req.policy} により {provider} ({model}) を選択"

    # プロバイダーに応じて呼び出し
    if provider == "azure":
        result = call_azure_real(req.request_id) if USE_REAL else _mock_result("azure", model)
    elif provider == "aws":
        result = call_bedrock_real(req.request_id) if USE_REAL else _mock_result("aws", model)
    else:
        raise HTTPException(status_code=500, detail=f"Unknown provider: {provider}")

    return RouteResponse(chosen=chosen, reason=reason, result=result)

@app.post("/api/s3/analyze")
def analyze_from_s3(request: Request, req: S3AnalyzeReq):
    require_api_key(request)  # 任意
    t0 = time.time()
    request_id = f"req-{int(time.time()*1000)}"
    key = req.s3_key

    if not key:
        raise HTTPException(status_code=400, detail="s3_key is required")

    log_json(stage="analyze_s3", action="start", request_id=request_id, s3_key=key)

    # 1) S3からバイナリ取得
    try:
        obj = s3.get_object(Bucket=S3_UPLOAD_BUCKET, Key=key)
        img_bytes = obj["Body"].read()
    except Exception as e:
        log_json(stage="analyze_s3", action="s3_get_failed", error=str(e))
        raise HTTPException(status_code=502, detail="failed to fetch object from S3")

    # 2) 各プロバイダーへ解析リクエスト
    results = []

    # (A) Azure
    if os.environ.get("USE_AZURE", "0") == "1":
        try:
            azure_result = call_azure_from_bytes(img_bytes)
            results.append({"provider": "azure", "result": azure_result})
        except Exception as e:
            log_json(stage="analyze_s3", action="azure_failed", error=str(e))
            results.append({"provider": "azure", "error": str(e)})

    # (B) SageMaker
    if os.environ.get("USE_SAGEMAKER", "0") == "1":
        try:
            sm_result = call_sagemaker_from_bytes(img_bytes)
            results.append({"provider": "sagemaker", "result": sm_result})
        except Exception as e:
            log_json(stage="analyze_s3", action="sagemaker_failed", error=str(e))
            results.append({"provider": "sagemaker", "error": str(e)})

    # (C) Bedrock
    if os.environ.get("USE_BEDROCK", "0") == "1":
        try:
            bd_result = call_bedrock_from_bytes(img_bytes)
            results.append({"provider": "bedrock", "result": bd_result})
        except Exception as e:
            log_json(stage="analyze_s3", action="bedrock_failed", error=str(e))
            results.append({"provider": "bedrock", "error": str(e)})

    # 3) DynamoDBへ保存（TTL=1日）
    try:
        ttl = int(time.time()) + 24*3600
        item = {
            "request_id": request_id,
            "s3_key": key,
            "results": results,
            "created_at": int(time.time()),
            "expire_at": ttl
        }
        ddb.put_item(Item=item)
    except Exception as e:
        log_json(stage="analyze_s3", action="dynamo_failed", error=str(e))
        # DynamoDB失敗時も結果は返す（オプション）

    rt = round((time.time()-t0)*1000)
    log_json(stage="analyze_s3", action="done", request_id=request_id, rt_ms=rt)
    return {"request_id": request_id, "results": results}

@app.get("/api/result/{request_id}")
def get_result(request_id: str):
    r = ddb.get_item(Key={"request_id": request_id})
    if "Item" not in r:
        return {"found": False}
    return {"found": True, "item": r["Item"]}
