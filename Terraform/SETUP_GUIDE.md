# PoC MC Vision - セットアップガイド

本ドキュメントは、PoC MC Vision プロジェクトの**Terraform特化**のセットアップガイドです。インフラのデプロイ手順、ローカル開発環境のセットアップ、トラブルシューティングを記載しています。

## 📚 関連ドキュメント

| ドキュメント | 内容 |
|------------|------|
| [docs/GETTING_STARTED.md](../docs/GETTING_STARTED.md) | **プロジェクト全体の初回セットアップガイド**（最初に読むドキュメント） |
| [docs/CI_CD_TESTING_GUIDE.md](../docs/CI_CD_TESTING_GUIDE.md) | CI/CDの運用・テスト手順（日常的な開発フロー） |
| [docs/DOCKER_ECR_DEPLOYMENT_GUIDE.md](../docs/DOCKER_ECR_DEPLOYMENT_GUIDE.md) | Docker・ECR技術リファレンス + 手動デプロイ手順 |
| **このドキュメント** | Terraform特化のセットアップガイド |
| [DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md) | デプロイチェックリスト |
| [TERRAFORM_CICD_SETUP_GUIDE.md](./TERRAFORM_CICD_SETUP_GUIDE.md) | GitHub ActionsによるCI/CD初期設定ガイド |

---

## 🚀 デプロイ手順

### 前提条件

#### 1. 実行環境

本PoCは以下の環境での動作を想定しています：

| 項目 | 内容 |
|------|------|
| **クラウド環境** | AWS（東京リージョン: ap-northeast-1）＋ Azure（米国東部2: East US 2） |
| **Terraform** | 1.9.8 |
| **AWS CLI** | v2（最新版） |
| **Azure CLI** | 最新版 |
| **Python** | 3.12 |
| **Node.js** | 18.x |

> **注**: Terraform 1.9.8はGitHub Actions CI/CDワークフローでも使用されているバージョンです。バージョンを統一することで、ローカル環境とCI/CD環境での挙動の一貫性が保たれます。

#### 2. 認証情報の設定

**AWS:**
```bash
aws configure
# または環境変数設定
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="ap-northeast-1"
```

**Azure:**
```bash
az login
az account set --subscription "your-subscription-id"
```

#### 3. ローカル開発環境のセットアップ

インフラデプロイ後、アプリケーションをローカルで動作確認する場合は以下の手順でセットアップしてください。

**Backend（FastAPI）:**
```bash
cd src/backend
pip install -r requirements.txt
cp ../../configs/.env.example .env
# .envファイルに AWS/Azure の認証情報を設定
uvicorn main:app --reload  # http://localhost:8000 で起動
```

**Frontend（React + Vite）:**
```bash
cd src/frontend
npm install
npm run dev  # http://localhost:5173 で起動
```

> **注**: `.env` ファイルには、TerraformデプロイでAWS/Azureから取得した認証情報やエンドポイントURLを設定してください。

#### 4. 事前準備（重要）

以下のファイルを**事前にS3にアップロード**してください（以下の例はリポジトリルートで実行）：

```bash
# S3バケット作成（手動）- デプロイパッケージ格納用
aws s3 mb s3://poc-mc-vision-zip --region ap-northeast-1

# Lambda zipファイルをアップロード（リポジトリ内: `Lambda/poc-mc-vision-handler.zip`）
aws s3 cp ./Lambda/poc-mc-vision-handler.zip s3://poc-mc-vision-zip/

# SageMaker モデルファイルをアップロード（リポジトリ内: `sagemaker_model/model_torchscript.tar.gz`）
aws s3 cp ./sagemaker_model/model_torchscript.tar.gz s3://poc-mc-vision-zip/
```

> **注意**: Terraformはこれらのファイルが既に存在することを前提としています。
>
> **S3バケットの役割分担**:
> - `poc-mc-vision-zip`: Lambda zipとSageMakerモデルの格納（手動作成）
> - `poc-mc-vision-upload`: 画像アップロード用（Terraformで自動作成）

---

### ステップ1: State管理用リソースの作成

```bash
cd setup/
chmod +x create-state-backend.sh
./create-state-backend.sh
```

作成されるリソース:
- S3バケット: `poc-mc-vision-terraform-state-aws`
- S3バケット: `poc-mc-vision-terraform-state-azure`
- DynamoDBテーブル: `poc-mc-vision-terraform-locks`

---

### ステップ2: AWS リソースのデプロイ

```bash
cd ../aws/

# 初期化
terraform init

# Providerバージョン確認（AWS Provider 5.100.0がロックされていることを確認）
terraform version
terraform providers

# プラン確認
terraform plan

# デプロイ実行
terraform apply

# 出力確認
terraform output
```

> **注**: `.terraform.lock.hcl` ファイルにより、AWS Provider 5.100.0がロックされています。これにより、異なる環境（ローカル、CI/CD）でも同一バージョンが使用され、挙動の一貫性が保たれます。

#### デプロイされるリソース:

| リソース | 名前 | 用途 |
|---------|------|------|
| S3 Bucket | `poc-mc-vision-upload` | 画像アップロード用（Lambdaトリガー） |
| Lambda (S3イベント) | `poc-mc-vision-handler` | S3イベント処理・メタデータ記録 |
| Lambda (FastAPI) | `poc-mc-vision-fastapi` | コンテナイメージ（ECR）で FastAPI を実行 |
| Lambda (Pipeline Worker) | `poc-mc-vision-pipeline-worker` | Step Functions から呼ばれ、S3→SageMaker/Bedrock/Azure を実行 |
| Step Functions | `poc-mc-vision-pipeline` | SageMaker→Bedrock/Azure→DynamoDB→SNS をオーケストレーション |
| SageMaker Endpoint | `poc-mc-vision-sm` | カスタムモデル推論 (Serverless) |
| DynamoDB Table | `poc-mc-vision-table` | 推論結果保存（TTL 7日） |
| SNS Topic | `poc-mc-vision-alerts` | CloudWatch アラーム/パイプライン完了通知（メール購読） |
| CloudWatch Logs & Alarms | `/aws/lambda/*`, `/aws/states/*` | FastAPI / Pipeline / S3 Lambda / Step Functions / SageMaker の監視（11個のアラーム） |
| CloudWatch Dashboard | `poc-mc-vision-operations` | 運用監視ダッシュボード（9個のウィジェット） |
| IAM Roles | 各 Lambda / SageMaker / Step Functions 用 | 実行ロール・ポリシー |
| ECR Repository | `poc-mc-vision-fastapi` | FastAPI ＆ Pipeline Worker コンテナを格納 |

> **注**: S3バケットには、フロントエンド（localhost:5173）からの直接アップロードを許可するCORS設定が含まれています。

> **注**: Lambda zipとSageMakerモデルは事前作成した `poc-mc-vision-zip` バケットから参照されます。

#### FastAPI / Pipeline Worker 用コンテナのビルド & プッシュ（初回のみ）

Terraform は FastAPI/Pipeline Worker Lambda に ECR イメージを参照させますが、**イメージのビルドとプッシュは別途実施が必要**です。**初回のみ**以下を実行してください。

```bash
cd src/backend

# AWS へログイン
aws ecr get-login-password --region ap-northeast-1 \
  | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com

# コンテナをビルド
docker build --platform linux/amd64 -t ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest -f Dockerfile .

# ECR へ push
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest
```

FastAPI と Pipeline Worker は同じイメージを共有しているため、上記 push を行うだけで両方の Lambda に反映されます。

> **📌 CI/CD実装済み**: 初回プッシュ後は、`src/backend/`の変更を`main`ブランチにプッシュすると、GitHub Actionsが自動的にDockerイメージをビルド・プッシュ・Lambda更新を行います。
>
> 詳細: [docs/CI_CD_TESTING_GUIDE.md](../docs/CI_CD_TESTING_GUIDE.md)

#### 所要時間:
- **約5〜10分**（SageMaker エンドポイントの起動に時間がかかります）

---

### ステップ2.5: Bedrock Guardrailの作成（オプション）

Guardrailを使用する場合、**Terraformデプロイ前に**手動でGuardrailを作成してください：

```bash
# リポジトリルートから実行
python scripts/create_guardrail.py --name poc-mc-vision-guardrail --region ap-northeast-1
```

出力されるIDとVersionを `terraform.tfvars` に設定：
```hcl
bedrock_guardrail_id      = "<出力されたID>"
bedrock_guardrail_version = "1"
use_guardrails            = true
```

> **注**: GuardrailはTerraformではなくPythonスクリプトで作成します。これは設定の柔軟性を確保するためです。

---

### ステップ3: Azure リソースのデプロイ

#### 3-1. Azure Resource Providerの登録（初回のみ）

```bash
# 必要なResource Providerを登録
az provider register --namespace Microsoft.CognitiveServices
az provider register --namespace Microsoft.Resources

# 登録状態を確認（"Registered"になるまで待つ）
az provider show --namespace Microsoft.CognitiveServices --query "registrationState"
az provider show --namespace Microsoft.Resources --query "registrationState"
```

> **注**: 登録には数分かかる場合があります。`"Registered"` と表示されるまで待ってから次に進んでください。

#### 3-2. Terraformデプロイ

```bash
cd ../azure/

# 初期化（Resource Provider登録後に実行）
terraform init -reconfigure

# プラン確認
terraform plan

# デプロイ実行
terraform apply

# 出力確認（機密情報含む）
terraform output
terraform output -json > azure_outputs.json
```

#### デプロイされるリソース:

| リソース | 名前 | 用途 |
|---------|------|------|
| Resource Group | `rg-aoai-poc` | リソースグループ |
| Cognitive Account | `aoai-poc-vision-eastus2` | Azure OpenAI アカウント |
| Deployment | `gpt4omini-poc` | GPT-4o-mini デプロイ |

#### 所要時間:
- **約3〜5分**

---

### ステップ4: Azure 認証情報の取得

Azure デプロイ後、FastAPI の環境変数に設定するため、以下のコマンドで接続情報を取得してください：

```bash
# Azure出力値を取得
cd azure/
terraform output aoai_endpoint
terraform output aoai_primary_key
terraform output deployment_name
terraform output api_version
```

#### エンドポイント形式について

Azure OpenAIのエンドポイントは**リージョナルエンドポイント形式**です：

```
https://<region>.api.cognitive.microsoft.com/
例: https://eastus2.api.cognitive.microsoft.com/
```

> **注**: カスタムサブドメイン形式（`https://<resource-name>.openai.azure.com/`）ではありません。

取得した情報を FastAPI の環境変数（`configs/.env` ファイル）に設定してください：

```bash
AZURE_OPENAI_ENDPOINT="https://eastus2.api.cognitive.microsoft.com"
AZURE_OPENAI_API_KEY="<取得したAPIキー>"
AZURE_OPENAI_DEPLOYMENT_MINI="gpt4omini-poc"
AZURE_OPENAI_API_VERSION="2024-10-21"
```

---

## 📊 デプロイ確認

### AWS リソース確認

```bash
# Lambda関数確認
aws lambda get-function --function-name poc-mc-vision-handler

# S3バケット確認
aws s3 ls s3://poc-mc-vision-upload/

# DynamoDB テーブル確認
aws dynamodb describe-table --table-name poc-mc-vision-table

# SageMaker エンドポイント確認
aws sagemaker describe-endpoint --endpoint-name poc-mc-vision-sm
```

### Azure リソース確認

```bash
# リソースグループ確認
az group show --name rg-aoai-poc

# Azure OpenAI アカウント確認
az cognitiveservices account show \
  --name aoai-poc-vision-eastus2 \
  --resource-group rg-aoai-poc

# デプロイ確認
az cognitiveservices account deployment list \
  --name aoai-poc-vision-eastus2 \
  --resource-group rg-aoai-poc
```

---

## 🔧 カスタマイズ

### 変数のカスタマイズ

各ディレクトリに `terraform.tfvars` ファイルを作成して変数を上書きできます：

**aws/terraform.tfvars:**
```hcl
aws_region              = "us-east-1"
lambda_timeout          = 120
sagemaker_memory_size   = 2048
sagemaker_max_concurrency = 5
```

**azure/terraform.tfvars:**
```hcl
azure_location          = "eastus"
model_version           = "2024-10-21"
```

### リソース名の変更

`variables.tf` のデフォルト値を編集するか、`terraform.tfvars` で上書きしてください。

---

## 🔄 CI/CD パイプライン（GitHub Actions）

本プロジェクトでは、**GitHub Actionsを活用したTerraform CI/CDパイプライン**を実装しています（PR時の自動検証・mainマージ後の手動承認デプロイ）。

CI/CDのセットアップ手順・ワークフローの詳細については、以下のドキュメントを参照してください：

**[TERRAFORM_CICD_SETUP_GUIDE.md](./TERRAFORM_CICD_SETUP_GUIDE.md)** - Personal Access Token作成、GitHub Secrets設定、Environment構成、検証手順、トラブルシューティング等を含む初期設定ガイド

---

## 🗑️ リソースの削除

### 注意事項
- **削除は逆順**で実行してください（Azure → AWS → State管理）
- **データは完全に削除**されます（S3、DynamoDB等）
- State管理用リソースは最後に削除
- **S3バケット内のファイルは事前削除が必要**（バージョニング有効のため）

### 削除手順

```bash
# 1. Azure リソース削除
cd azure/
terraform destroy

# 2. AWS S3バケット内のオブジェクトを削除（バージョニング対応）
# S3バケットが空でない場合、terraform destroyは失敗します

# オブジェクトバージョンを削除
aws s3api list-object-versions \
  --bucket poc-mc-vision-upload \
  --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
  --output json > /tmp/s3-versions.json

aws s3api delete-objects \
  --bucket poc-mc-vision-upload \
  --delete file:///tmp/s3-versions.json

# 削除マーカーも削除
aws s3api list-object-versions \
  --bucket poc-mc-vision-upload \
  --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
  --output json > /tmp/s3-markers.json

aws s3api delete-objects \
  --bucket poc-mc-vision-upload \
  --delete file:///tmp/s3-markers.json

# 3. AWS リソース削除
cd ../aws/
terraform destroy

# 4. State管理用リソース削除（任意）
cd ../setup/
aws dynamodb delete-table --table-name poc-mc-vision-terraform-locks
aws s3 rb s3://poc-mc-vision-terraform-state-aws --force
aws s3 rb s3://poc-mc-vision-terraform-state-azure --force
```

> **Tip**: S3バケット削除を簡単にするには、`s3/main.tf` で `force_destroy = true` を設定すると、terraform destroy時に自動的にオブジェクトも削除されます。

---

## 📝 トラブルシューティング

### S3バケット削除失敗（BucketNotEmpty）

```
Error: deleting S3 Bucket (poc-mc-vision-upload): BucketNotEmpty: The bucket you tried to delete is not empty.
```

**原因**: バージョニングが有効なため、削除したファイルのバージョン履歴が残っています。

**解決策**:
```bash
# オブジェクトバージョンを削除
aws s3api list-object-versions \
  --bucket poc-mc-vision-upload \
  --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
  --output json > /tmp/s3-versions.json

aws s3api delete-objects \
  --bucket poc-mc-vision-upload \
  --delete file:///tmp/s3-versions.json

# 削除マーカーも削除
aws s3api list-object-versions \
  --bucket poc-mc-vision-upload \
  --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
  --output json > /tmp/s3-markers.json

aws s3api delete-objects \
  --bucket poc-mc-vision-upload \
  --delete file:///tmp/s3-markers.json

# 再度terraform destroyを実行
terraform destroy
```

### SageMaker エンドポイント起動失敗

```
Error: error waiting for SageMaker Endpoint (poc-mc-vision-sm) to become available
```

**解決策**:
1. モデルファイル（`model_torchscript.tar.gz`）がS3に正しくアップロードされているか確認
2. IAMロールに適切な権限があるか確認

### Lambda関数がS3イベントで起動しない

**確認事項**:
1. S3イベント通知が正しく設定されているか: `aws s3api get-bucket-notification-configuration --bucket poc-mc-vision-upload`
2. Lambda関数にS3からの実行権限があるか確認

### ブラウザからS3へのアップロードが失敗（CORS）

```
Error: Access to fetch has been blocked by CORS policy
```

**原因**: S3バケットのCORS設定が不足しています。

**解決策**: `aws/s3/main.tf` にCORS設定が含まれていることを確認してください（Terraform v1.9以降で自動的に含まれています）。

### Azure Resource Provider未登録エラー

```
Error: Encountered an error whilst ensuring Resource Providers are registered.
```

**原因**: 必要なResource Providerが登録されていません。

**解決策**:
```bash
# Resource Providerを手動登録
az provider register --namespace Microsoft.CognitiveServices
az provider register --namespace Microsoft.Resources

# 登録完了を確認（"Registered"になるまで待つ）
az provider show --namespace Microsoft.CognitiveServices --query "registrationState"

# 再度terraform initとplanを実行
terraform init -reconfigure
terraform plan
```

### Azure OpenAI接続エラー（DNSエラー）

```
Error: Failed to resolve 'aoai-poc-vision-eastus2.openai.azure.com'
```

**原因**: エンドポイントURLの形式が間違っています。

**解決策**:
- 正しいエンドポイント形式: `https://eastus2.api.cognitive.microsoft.com/`
- 間違った形式: `https://aoai-poc-vision-eastus2.openai.azure.com/`

`configs/.env` ファイルのエンドポイントを修正してください：
```bash
AZURE_OPENAI_ENDPOINT="https://eastus2.api.cognitive.microsoft.com"
```

### Azure OpenAIクォータ不足エラー

```
Error: InsufficientQuota: Insufficient quota. Cannot create/update/move resource
```

**原因**: 選択したリージョンでAzure OpenAIリソースの上限に達しています。

**解決策**:
1. **別のリージョンを使用**: `azure/variables.tf` の `azure_location` を変更（例: `swedencentral`, `eastus`, `westus`）
2. **既存リソースの削除**: ソフトデリート状態のリソースをパージ
   ```bash
   az cognitiveservices account list-deleted
   az cognitiveservices account purge --name <名前> --resource-group <RG> --location <リージョン>
   ```
   
---
