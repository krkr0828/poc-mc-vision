# Docker & ECR デプロイメントガイド

このドキュメントでは、PoC MC Visionプロジェクトにおける**DockerイメージのビルドからECRへのプッシュ、Lambdaでの実行までの完全なフロー**を解説します。

## 目次

- [ソースコードの場所](#ソースコードの場所)
- [Terraformの役割範囲](#terraformの役割範囲)
- [ECRイメージの内容](#ecrイメージの内容)
- [ECRへのデプロイフロー](#ecrへのデプロイフロー)
- [2つのLambda関数の仕組み](#2つのlambda関数の仕組み)
- [コード更新時の手順](#コード更新時の手順)
- [トラブルシューティング](#トラブルシューティング)

---

## ソースコードの場所

### FastAPI（Lambda用アプリケーション）

| ファイル | パス | 説明 |
|---------|------|------|
| **アプリケーション本体** | `src/backend/main.py` | FastAPIアプリ + 推論ロジック（単一ファイル） |
| **Dockerfile** | `src/backend/Dockerfile` | Dockerイメージのビルド定義 |
| **依存関係** | `src/backend/requirements.txt` | Pythonパッケージの一覧 |
| **除外設定** | `src/backend/.dockerignore` | イメージに含めないファイルの指定 |

### Step Functions

| ファイル | パス | 説明 |
|---------|------|------|
| **定義テンプレート** | `Terraform/aws/step_functions/definition.json.tpl` | ワークフロー定義 |
| **Terraform設定** | `Terraform/aws/step_functions/main.tf` | Step Functionsリソース定義 |

### Terraform（インフラ定義）

| ファイル | パス | 説明 |
|---------|------|------|
| **ECR設定** | `Terraform/aws/ecr/main.tf` | ECRリポジトリの作成 |
| **Lambda FastAPI設定** | `Terraform/aws/lambda_fastapi/main.tf` | Lambda関数の作成（イメージ参照） |
| **メイン設定** | `Terraform/aws/main.tf` | 全モジュールの統合 |

---

## Terraformの役割範囲

Terraformは以下のリソースを**作成・管理**しますが、**Dockerイメージのビルドとプッシュは行いません**。

### ✅ Terraformが行うこと

```hcl
# Terraform/aws/main.tf

# 1. ECRリポジトリの作成
module "ecr" {
  source = "./ecr"
  repository_name = "poc-mc-vision-fastapi"
}
# → リポジトリのみ作成（イメージは空）

# 2. Lambda FastAPI の作成
module "lambda_fastapi" {
  source = "./lambda_fastapi"
  function_name = "poc-mc-vision-fastapi"
  image_uri = "${module.ecr.repository_url}:latest"
  # → ECRイメージを参照（既に存在する前提）
}

# 3. Lambda Pipeline Worker の作成
module "lambda_pipeline_worker" {
  source = "./lambda_fastapi"
  function_name = "poc-mc-vision-pipeline-worker"
  image_uri = "${module.ecr.repository_url}:latest"  # 同じイメージ
  image_command = ["main.pipeline_handler"]  # 異なるハンドラ
  # → 同じイメージを異なる設定で使用
}
```

### ❌ Terraformが行わないこと

- Dockerイメージのビルド（`docker build`）
- ECRへのイメージプッシュ（`docker push`）
- イメージの更新管理

これらは**手動またはCI/CDパイプラインで実行**する必要があります。

---

## ECRイメージの内容

### Dockerfile の動作

```dockerfile
# src/backend/Dockerfile

FROM public.ecr.aws/lambda/python:3.12
WORKDIR /var/task

# 1. 依存関係のインストール
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 2. アプリケーションコードのコピー
COPY . .
# ↑ src/backend/ 配下の全ファイルをコピー（.dockerignore除く）

# 3. デフォルトのエントリーポイント設定
CMD ["main.handler"]
```

### イメージに含まれるファイル

```
src/backend/                        イメージへの含有
├── main.py                    →   ✅ 含まれる（アプリケーション本体）
├── requirements.txt           →   ✅ 含まれる（インストール後は不要だが含まれる）
├── Dockerfile                 →   ✅ 含まれる（実行時は不要だが除外されていない）
├── .dockerignore              →   ✅ 含まれる（実行時は不要だが除外されていない）
│
└── 除外されるファイル（.dockerignoreで指定）:
    ├── .venv/                 →   ❌ 除外（ローカル仮想環境）
    ├── __pycache__/           →   ❌ 除外（キャッシュファイル）
    ├── *.pyc                  →   ❌ 除外（コンパイル済みPython）
    ├── results/               →   ❌ 除外（実行結果）
    ├── images/                →   ❌ 除外（テスト画像）
    └── .env                   →   ❌ 除外（環境変数はLambda設定で管理）
```

### インストールされるパッケージ

`requirements.txt`で指定された以下のパッケージがイメージに含まれます：

```txt
fastapi
mangum
boto3
pillow
requests
python-dotenv
aws-embedded-metrics
numpy
```

---

## ECRへのデプロイフロー

### 全体フロー図

```
┌──────────────────────────────────────────────────────────────┐
│ 開発者                                                        │
└──┬───────────────────────────────────────────────────────────┘
   │
   │ ①コード編集
   ├─────────────► src/backend/main.py
   │               src/backend/Dockerfile
   │               src/backend/requirements.txt
   │
   │ ②Terraformでインフラ作成
   ├─────────────► terraform apply
   │                  │
   │                  ├─► ECRリポジトリ作成 (空)
   │                  ├─► Lambda FastAPI作成 (イメージ未設定 → エラー状態)
   │                  └─► Lambda Pipeline Worker作成 (イメージ未設定 → エラー状態)
   │
   │ ③Dockerイメージをビルド＆プッシュ（手動）
   ├─────────────► docker build
   │                  │
   │                  └─► docker push
   │                         │
   │                         ▼
   │                  ┌─────────────────────────┐
   │                  │ ECR Repository          │
   │                  │ poc-mc-vision-fastapi   │
   │                  │   └─ :latest            │
   │                  └─────────────────────────┘
   │                         │
   │                         │ イメージ参照
   │                         │
   │                  ┌──────┴──────────────────┐
   │                  │                         │
   │                  ▼                         ▼
   │           ┌─────────────────┐      ┌─────────────────┐
   │           │Lambda FastAPI   │      │Lambda Pipeline  │
   │           │                 │      │Worker           │
   │           │CMD:             │      │CMD:             │
   │           │["main.handler"] │      │["main.pipeline_ │
   │           │                 │      │ handler"]       │
   │           │→ FastAPIサーバー │      │→ 推論処理       │
   │           └─────────────────┘      └─────────────────┘
   │                  │                         │
   │                  │                         │
   │                  ▼                         ▼
   │           ┌─────────────────┐      ┌─────────────────┐
   │           │Lambda Function  │      │Step Functions   │
   │           │URL              │      │から呼び出し     │
   │           │→ API Gateway的  │      │                 │
   │           └─────────────────┘      └─────────────────┘
   │
   └─────────────► ④Lambda関数が正常起動
```

### ステップバイステップ手順

#### ステップ1: Terraformでインフラを作成

```bash
cd Terraform/aws
terraform init
terraform apply
```

**この時点での状態**：
- ✅ ECRリポジトリ `poc-mc-vision-fastapi` が作成される
- ⚠️ ECRリポジトリは**空**（イメージが存在しない）
- ⚠️ Lambda関数は作成されるが、イメージがないため**エラー状態**

#### ステップ2: Dockerイメージをビルド＆プッシュ

```bash
cd src/backend

# AWSアカウントIDを取得
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# 1. ECRにログイン
aws ecr get-login-password --region ap-northeast-1 \
  | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com

# 2. イメージをビルド
docker build --platform linux/amd64 \
  -t ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest \
  -f Dockerfile .

# 3. ECRにプッシュ
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest
```

**この時点での状態**：
- ✅ ECRに `poc-mc-vision-fastapi:latest` イメージがアップロードされる
- ✅ Lambda関数が自動的にイメージを参照して**正常動作**

#### ステップ3: Lambda関数の更新確認（オプション）

```bash
# Lambda FastAPI の状態確認
aws lambda get-function --function-name poc-mc-vision-fastapi

# Lambda Pipeline Worker の状態確認
aws lambda get-function --function-name poc-mc-vision-pipeline-worker

# 必要に応じて明示的に更新
aws lambda update-function-code \
  --function-name poc-mc-vision-fastapi \
  --image-uri ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest

aws lambda update-function-code \
  --function-name poc-mc-vision-pipeline-worker \
  --image-uri ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest
```

---

## 2つのLambda関数の仕組み

### main.py の2つのエントリーポイント

```python
# src/backend/main.py

# FastAPI アプリケーション定義
app = FastAPI(title="PoC MC Vision API")

# ... FastAPIのエンドポイント定義 ...

# ===== エントリーポイント1: FastAPI用ハンドラ (line 143) =====
handler = Mangum(app)
# Mangumライブラリが FastAPI を Lambda ハンドラに変換
# Lambda FastAPI から呼び出される

# ===== エントリーポイント2: Pipeline Worker用ハンドラ (line 848) =====
def pipeline_handler(event, context):
    """
    Step Functions から呼び出される推論処理ハンドラ

    Args:
        event: {
            "s3_key": "path/to/image.jpg",
            "inference_type": "sagemaker" | "bedrock" | "azure"
        }
        context: Lambda context

    Returns:
        推論結果
    """
    # S3から画像取得 → AIサービス呼び出し → 結果返却
    pass
```

### 同じイメージ、異なるハンドラの実現方法

| 項目 | Lambda FastAPI | Lambda Pipeline Worker |
|------|----------------|------------------------|
| **イメージ** | `poc-mc-vision-fastapi:latest` | `poc-mc-vision-fastapi:latest`（同じ） |
| **エントリーポイント** | `CMD ["main.handler"]`（Dockerfile） | `image_command = ["main.pipeline_handler"]`（Terraform） |
| **呼び出し元** | API Gateway / Function URL | Step Functions |
| **役割** | FastAPIサーバー（HTTP API） | バッチ推論処理（イベント駆動） |
| **レスポンス形式** | HTTP Response（JSON） | Lambda Response（dict） |

### Terraform設定の違い

```hcl
# Terraform/aws/main.tf

# Lambda FastAPI
module "lambda_fastapi" {
  source = "./lambda_fastapi"
  function_name = "poc-mc-vision-fastapi"
  image_uri = "${module.ecr.repository_url}:latest"
  create_function_url = true  # Function URL作成
  # image_commandを指定しない → Dockerfileの CMD ["main.handler"] が使用される
}

# Lambda Pipeline Worker
module "lambda_pipeline_worker" {
  source = "./lambda_fastapi"
  function_name = "poc-mc-vision-pipeline-worker"
  image_uri = "${module.ecr.repository_url}:latest"  # 同じイメージ
  create_function_url = false  # Function URL不要
  image_command = ["main.pipeline_handler"]  # 異なるハンドラを指定
}
```

### イメージ構成の全体像

```
┌───────────────────────────────────────────────────────────────┐
│ ECR Image: poc-mc-vision-fastapi:latest                       │
├───────────────────────────────────────────────────────────────┤
│ ベースイメージ: public.ecr.aws/lambda/python:3.12            │
│                                                                │
│ インストール済みパッケージ:                                    │
│  - FastAPI, Mangum, boto3, PIL, requests, numpy, etc.        │
│    (requirements.txtから)                                      │
│                                                                │
│ アプリケーションコード:                                        │
│  - main.py ← 単一ファイル（FastAPI + 推論ロジック）           │
│    ├─ app: FastAPI() ← FastAPIアプリケーション本体            │
│    ├─ handler = Mangum(app) ← Lambda用にラップ (line 143)    │
│    └─ def pipeline_handler(...) ← Step Functions用 (line 848)│
│                                                                │
│  - requirements.txt                                            │
│  - Dockerfile（実行時は不要）                                  │
│  - .dockerignore（実行時は不要）                               │
└───────────────────────────────────────────────────────────────┘
                         │
                         │ 同じイメージを異なる設定で使用
                         │
        ┌────────────────┴─────────────────┐
        │                                   │
        ▼                                   ▼
┌─────────────────────┐         ┌─────────────────────┐
│ Lambda FastAPI      │         │ Lambda Pipeline     │
│                     │         │ Worker              │
│ Terraform設定:      │         │                     │
│  image_command: -   │         │ Terraform設定:      │
│  (未指定)           │         │  image_command:     │
│                     │         │  ["main.pipeline_   │
│ 実行されるコマンド: │         │   handler"]         │
│  CMD ["main.handler"]│         │                     │
│  (Dockerfile)       │         │ 実行されるコマンド: │
│                     │         │  main.pipeline_     │
│ 動作:               │         │  handler            │
│  - FastAPIサーバー   │         │                     │
│  - HTTP APIを提供    │         │ 動作:               │
│  - Function URL経由  │         │  - 推論処理実行     │
│    でアクセス可能    │         │  - Step Functionsから│
│                     │         │    呼び出される      │
└─────────────────────┘         └─────────────────────┘
```

---

## コード更新時の手順

### ケース1: main.py のみ更新

```bash
# 1. コード編集
vim src/backend/main.py

# 2. イメージを再ビルド＆プッシュ
cd src/backend
docker build --platform linux/amd64 \
  -t ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest \
  -f Dockerfile .
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest

# 3. Lambda関数が自動的に最新イメージを参照（数分かかる場合あり）
# 必要に応じて明示的に更新:
aws lambda update-function-code \
  --function-name poc-mc-vision-fastapi \
  --image-uri ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest

aws lambda update-function-code \
  --function-name poc-mc-vision-pipeline-worker \
  --image-uri ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest
```

### ケース2: requirements.txt を更新

```bash
# 1. 依存関係追加
echo "new-package==1.0.0" >> src/backend/requirements.txt

# 2. イメージを再ビルド＆プッシュ（ケース1と同じ）
cd src/backend
docker build --platform linux/amd64 \
  -t ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest \
  -f Dockerfile .
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest
```

### ケース3: Terraform設定を変更

```bash
# 1. Terraform設定編集（環境変数、タイムアウト、メモリサイズなど）
vim Terraform/aws/main.tf

# 2. Terraformを適用
cd Terraform/aws
terraform plan
terraform apply

# 注: イメージのビルド＆プッシュは不要
```

---

## トラブルシューティング

### 問題1: Lambda関数がエラー状態

**症状**:
```
Error: The image manifest or layer media type for the source image [...] is not supported.
```

**原因**: ECRにイメージがプッシュされていない

**解決策**:
```bash
# ECRリポジトリにイメージが存在するか確認
aws ecr describe-images \
  --repository-name poc-mc-vision-fastapi \
  --region ap-northeast-1

# イメージが存在しない場合、ビルド＆プッシュを実行
cd src/backend
docker build --platform linux/amd64 \
  -t ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest \
  -f Dockerfile .
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest
```

### 問題2: Dockerビルドが失敗

**症状**:
```
ERROR [internal] load metadata for public.ecr.aws/lambda/python:3.12
```

**原因**: Dockerデーモンが起動していない、またはネットワークエラー

**解決策**:
```bash
# Dockerデーモンの状態確認
docker info

# Dockerを再起動
sudo systemctl restart docker

# ビルドを再実行
docker build --platform linux/amd64 \
  -t ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest \
  -f Dockerfile .
```

### 問題3: ECRへのプッシュが失敗

**症状**:
```
denied: Your authorization token has expired. Reauthenticate and try again.
```

**原因**: ECRログイントークンの有効期限切れ（12時間）

**解決策**:
```bash
# 再ログイン
aws ecr get-login-password --region ap-northeast-1 \
  | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com

# プッシュを再実行
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest
```

### 問題4: Lambda関数が古いイメージを参照

**症状**: コード変更後も古い動作が続く

**原因**: Lambdaのイメージキャッシュ、または明示的な更新が必要

**解決策**:
```bash
# Lambda関数を明示的に更新
aws lambda update-function-code \
  --function-name poc-mc-vision-fastapi \
  --image-uri ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest

# 更新完了を待つ（LastUpdateStatusがSuccessfulになるまで）
aws lambda get-function --function-name poc-mc-vision-fastapi \
  --query 'Configuration.LastUpdateStatus'

# 関数を実行してテスト
aws lambda invoke \
  --function-name poc-mc-vision-fastapi \
  --payload '{"test": "data"}' \
  response.json
```

### 問題5: Platform mismatch エラー

**症状**:
```
WARNING: The requested image's platform (linux/arm64) does not match the detected host platform
```

**原因**: MacのApple Silicon（M1/M2）でビルドした場合、デフォルトでarm64イメージになる

**解決策**:
```bash
# --platform linux/amd64 を必ず指定してビルド
docker build --platform linux/amd64 \
  -t ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest \
  -f Dockerfile .
```

---

## CI/CD自動化（オプション）

現在のプロジェクトではDockerイメージのビルド＆プッシュは手動ですが、GitHub Actionsで自動化することも可能です。

### 自動化ワークフローの例

```yaml
# .github/workflows/docker-build-push.yml
name: Build and Push Docker Image

on:
  push:
    branches: [main]
    paths:
      - 'src/backend/**'

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-northeast-1

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build, tag, and push image to Amazon ECR
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          ECR_REPOSITORY: poc-mc-vision-fastapi
          IMAGE_TAG: ${{ github.sha }}
        run: |
          cd src/backend
          docker build --platform linux/amd64 -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG .
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest

      - name: Update Lambda functions
        run: |
          aws lambda update-function-code \
            --function-name poc-mc-vision-fastapi \
            --image-uri ${{ steps.login-ecr.outputs.registry }}/poc-mc-vision-fastapi:latest

          aws lambda update-function-code \
            --function-name poc-mc-vision-pipeline-worker \
            --image-uri ${{ steps.login-ecr.outputs.registry }}/poc-mc-vision-fastapi:latest
```

このワークフローを追加すると、`src/backend/`配下のファイルがmainブランチにプッシュされた際に、自動的にイメージがビルドされてECRにプッシュされ、Lambda関数が更新されます。

---

## まとめ

### デプロイフローの全体像

```
開発者
  ├─ ① コード編集（src/backend/main.py）
  ├─ ② Terraformでインフラ作成（ECR、Lambda）
  ├─ ③ Dockerイメージビルド＆プッシュ（手動）
  └─ ④ Lambda関数が最新イメージで起動
```

### 重要なポイント

1. **Terraformの役割**: ECRリポジトリとLambda関数の**設定のみ**を管理
2. **イメージビルド**: 手動またはCI/CDで**別途実行**が必要
3. **1つのイメージ、2つの用途**: `image_command`で異なるエントリーポイントを指定
4. **main.py の2つのハンドラ**:
   - `handler`: FastAPIサーバー（HTTP API）
   - `pipeline_handler`: Step Functions用推論処理（イベント駆動）

### 参考リンク

- [Terraform AWS Provider - Lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function)
- [AWS Lambda - Container Images](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html)
- [Amazon ECR - Docker CLI](https://docs.aws.amazon.com/AmazonECR/latest/userguide/docker-push-ecr-image.html)
- [FastAPI - Mangum](https://mangum.io/)

---

**Last Updated**: 2025-11-21
