# PoC MC Vision - Terraform Infrastructure

このディレクトリには、PoC MC Visionプロジェクトのマルチクラウドインフラストラクチャを構築するためのTerraformテンプレートが含まれています。

## 📁 ディレクトリ構成

```
Terraform/
├── setup/                  # State管理用リソース初期化スクリプト
│   ├── create-state-backend.sh
│   └── README.md
├── aws/                    # AWS リソース
│   ├── backend.tf
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── .terraform.lock.hcl # Providerバージョンロックファイル（AWS Provider 5.100.0）
│   ├── s3/                 # S3バケット
│   ├── lambda/             # Lambda関数
│   ├── dynamodb/           # DynamoDB テーブル
│   ├── sagemaker/          # SageMaker エンドポイント
│   ├── iam/                # IAM ロール・ポリシー
│   └── cloudwatch/         # CloudWatch Logs
├── azure/                  # Azure リソース
│   ├── backend.tf
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── README.md               # 本ファイル（Terraformデプロイガイド）
├── DEPLOYMENT_CHECKLIST.md # デプロイチェックリスト
└── TERRAFORM_CICD_COMPLETE_GUIDE.md # CI/CD完全ガイド（GitHub Actions）
```

## 🚀 デプロイ手順

### 前提条件

#### 1. ツールのインストール

- **Terraform**: 1.9.8（推奨）
- **AWS CLI**: 最新版
- **Azure CLI**: 最新版（Azure リソースデプロイ時）

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

#### 3. 事前準備（重要）

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
| S3 Bucket | `poc-mc-vision-upload` | 画像アップロード用（Lambda起動トリガー） |
| S3 CORS Configuration | - | ブラウザからの直接アップロード許可 |
| Lambda Function | `poc-mc-vision-handler` | S3イベント処理・推論実行 |
| DynamoDB Table | `poc-mc-vision-table` | 推論結果保存 |
| SageMaker Endpoint | `poc-mc-vision-sm` | カスタムモデル推論 (Serverless) |
| IAM Role | `poc-mc-vision-lambda-role` | Lambda実行ロール |
| IAM Role | `poc-mc-vision-sagemaker-role` | SageMaker実行ロール |
| CloudWatch Logs | `/aws/lambda/poc-mc-vision-handler` | Lambda ログ（1日保持） |

> **注**: S3バケットには、フロントエンド（localhost:5173）からの直接アップロードを許可するCORS設定が含まれています。

> **注**: Lambda zipとSageMakerモデルは事前作成した `poc-mc-vision-zip` バケットから参照されます。

#### 所要時間:
- **約5〜10分**（SageMaker エンドポイントの起動に時間がかかります）

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

**[TERRAFORM_CICD_COMPLETE_GUIDE.md](./TERRAFORM_CICD_COMPLETE_GUIDE.md)** - Personal Access Token作成、GitHub Secrets設定、Environment構成、検証手順、トラブルシューティング等を含む完全ガイド

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

### S3バケット名の競合

```
Error: creating S3 Bucket (poc-mc-vision-upload): BucketAlreadyExists
```

**解決策**: `aws/variables.tf` の `s3_bucket_name` を別の名前に変更してください。

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

### Azure デプロイ時の認証エラー

```
Error: building account: getting authenticated object ID: Error listing Service Principals
```

**解決策**: `az login` で再認証してください。

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
3. **クォータ引き上げ申請**: Azureサポートに連絡（数日かかる場合あり）

---

## 💰 コスト見積もり

### AWS（月額推定）

| リソース | 料金 |
|---------|------|
| S3 (100GB) | ~$2.30 |
| Lambda (100万リクエスト) | ~$0.20 |
| DynamoDB (オンデマンド) | ~$1.25 |
| SageMaker Serverless | 使用時のみ課金 |
| Bedrock (Claude Haiku) | 使用時のみ課金 |
| **合計** | **~$5〜10/月** |

### Azure（月額推定）

| リソース | 料金 |
|---------|------|
| Cognitive Services (S0) | $0（保有のみ） |
| GPT-4o-mini (GlobalStandard) | 使用時のみ課金 |
| **合計** | **~$0〜5/月** |

> **注**: 実際の料金は使用量により変動します。

---

## 📚 参考リンク

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [AWS SageMaker Serverless](https://docs.aws.amazon.com/sagemaker/latest/dg/serverless-endpoints.html)
- [Azure OpenAI Service](https://learn.microsoft.com/en-us/azure/ai-services/openai/)

---

## 🆘 サポート

問題が発生した場合:
1. `terraform plan` でエラー内容を確認
2. AWS/Azure コンソールでリソース状態を確認
3. CloudWatch Logs でLambda実行ログを確認
