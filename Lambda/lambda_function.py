import json
import os
import time
import uuid
import logging

APP_NAME = os.getenv("APP_NAME", "poc-mc-vision")
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()

logger = logging.getLogger()
for h in logger.handlers:
    h.setFormatter(logging.Formatter("%(message)s"))
logger.setLevel(LOG_LEVEL)

def log_json(**kwargs):
    # CloudWatch に構造化(JSON)で出力
    try:
        logger.info(json.dumps(kwargs, ensure_ascii=False))
    except Exception:
        logger.info(str(kwargs))

def lambda_handler(event, context):
    t0 = time.time()
    # S3イベント（複数レコードに対応）
    records = event.get("Records", [])
    # 起動の相関ID（無ければ生成）
    invoke_id = str(uuid.uuid4())

    summary = {
        "app": APP_NAME,
        "stage": "lambda_ingest",
        "invoke_id": invoke_id,
        "record_count": len(records),
        "aws_request_id": getattr(context, "aws_request_id", None),
        "status": "start",
        "ts": int(time.time()),
    }
    log_json(**summary)

    ok = 0
    for i, r in enumerate(records):
        try:
            s3 = r.get("s3", {})
            bucket = s3.get("bucket", {}).get("name")
            key    = s3.get("object", {}).get("key")
            size   = s3.get("object", {}).get("size")

            # ここでは「受けた事実」を記録するのみ（本文は読まない）
            log_json(
                app=APP_NAME,
                stage="lambda_ingest",
                invoke_id=invoke_id,
                idx=i,
                bucket=bucket,
                key=key,
                size=size,
                status="received"
            )
            ok += 1
        except Exception as e:
            log_json(
                app=APP_NAME,
                stage="lambda_ingest",
                invoke_id=invoke_id,
                idx=i,
                error=str(e),
                status="error"
            )

    rt_ms = round((time.time() - t0) * 1000)
    log_json(
        app=APP_NAME,
        stage="lambda_ingest",
        invoke_id=invoke_id,
        status="done",
        ok=ok,
        total=len(records),
        rt_ms=rt_ms
    )

    # 常に200で返す（S3再試行ループを避ける）
    return {
        "statusCode": 200,
        "body": json.dumps({"ok": True, "received": ok, "total": len(records)})
    }
