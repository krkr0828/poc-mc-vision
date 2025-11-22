# 🚀 PoC MC Vision - Terraform デプロイチェックリスト

このチェックリストに従って、Terraformテンプレートを段階的にデプロイしてください。

---

## ✅ 事前準備チェックリスト

### 1. ツールのインストール確認

- [ ] **Terraform** >= 1.6.0 がインストール済み
  ```bash
  terraform version
  ```

- [ ] **AWS CLI** がインストール・認証済み
  ```bash
  aws --version
  aws sts get-caller-identity
  ```

- [ ] **Azure CLI** がインストール・認証済み（Azure利用時）
  ```bash
  az --version
  az account show
  ```

### 2. Lambda & SageMaker準備

- [ ] Lambda関数のデプロイパッケージを確認（必要に応じて再生成）
  ```bash
  ls ./Lambda/poc-mc-vision-handler.zip
  # 再生成する場合（任意）
  cd Lambda
  zip poc-mc-vision-handler.zip lambda_function.py
  cd ..
  ```

- [ ] SageMaker モデルファイル（sagemaker_model/model_torchscript.tar.gz）が存在することを確認

- [ ] FastAPI / Pipeline Worker 用コンテナをビルドし ECR へプッシュ
  ```bash
  cd src/backend
  aws ecr get-login-password --region ap-northeast-1 \
    | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com
  docker build --platform linux/amd64 -t ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest -f Dockerfile .
  docker push ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest
  ```

### 3. S3バケットの事前作成（重要）

以下のコマンドはリポジトリルートで実行します。

- [ ] S3バケット `poc-mc-vision-zip` を手動作成（デプロイパッケージ格納用）
  ```bash
  aws s3 mb s3://poc-mc-vision-zip --region ap-northeast-1
  ```

- [ ] Lambda zip をアップロード
  ```bash
  aws s3 cp ./Lambda/poc-mc-vision-handler.zip s3://poc-mc-vision-zip/
  ```

- [ ] SageMaker モデルをアップロード
  ```bash
  aws s3 cp ./sagemaker_model/model_torchscript.tar.gz s3://poc-mc-vision-zip/
  ```

- [ ] アップロード確認
  ```bash
  aws s3 ls s3://poc-mc-vision-zip/
  ```

> **S3バケットの役割**:
> - `poc-mc-vision-zip`: Lambda zipとSageMakerモデル格納（手動作成）
> - `poc-mc-vision-upload`: 画像アップロード用（Terraformで自動作成）

---

## 📋 デプロイ手順

### ステップ1: State管理リソースの作成

- [ ] setup ディレクトリに移動
  ```bash
  cd Terraform/setup/
  ```

- [ ] スクリプトに実行権限付与
  ```bash
  chmod +x create-state-backend.sh
  ```

- [ ] State管理リソース作成実行
  ```bash
  ./create-state-backend.sh
  ```

- [ ] 作成確認
  ```bash
  aws s3 ls | grep terraform-state
  aws dynamodb list-tables | grep terraform-locks
  ```

**想定される出力:**
```
✓ S3 Bucket (AWS): OK
✓ S3 Bucket (Azure): OK
✓ DynamoDB Table: ACTIVE
```

---

### ステップ2: AWS リソースのデプロイ

- [ ] AWS ディレクトリに移動
  ```bash
  cd ../aws/
  ```

- [ ] Terraform 初期化
  ```bash
  terraform init
  ```

- [ ] 構文検証
  ```bash
  terraform validate
  ```

- [ ] プラン確認（dry-run）
  ```bash
  terraform plan
  ```

**確認事項:**
- [ ] 作成されるリソース数が正しいか（約30〜40リソース）
- [ ] S3バケット名が正しいか
- [ ] Lambda zipのS3パスが正しいか
- [ ] SageMaker モデルのS3パスが正しいか
- [ ] Step Functions、SNS、CloudWatch Alarms（10個）が含まれているか

- [ ] デプロイ実行
  ```bash
  terraform apply
  ```

- [ ] デプロイ完了確認
  ```bash
  terraform output
  ```

**想定される所要時間:** 5〜10分

---

### ステップ3: Azure リソースのデプロイ

- [ ] Azure ディレクトリに移動
  ```bash
  cd ../azure/
  ```

- [ ] Azure 認証確認
  ```bash
  az account show
  ```

- [ ] **Azure Resource Providerの登録**（初回のみ、重要）
  ```bash
  az provider register --namespace Microsoft.CognitiveServices
  az provider register --namespace Microsoft.Resources

  # 登録状態を確認（"Registered"になるまで待つ）
  az provider show --namespace Microsoft.CognitiveServices --query "registrationState"
  az provider show --namespace Microsoft.Resources --query "registrationState"
  ```

- [ ] Terraform 初期化（Resource Provider登録後）
  ```bash
  terraform init -reconfigure
  ```

- [ ] 構文検証
  ```bash
  terraform validate
  ```

- [ ] プラン確認
  ```bash
  terraform plan
  ```

**確認事項:**
- [ ] Resource Group名が正しいか
- [ ] Cognitive Account名が正しいか（グローバルで一意である必要あり）
- [ ] モデルバージョンが正しいか

- [ ] デプロイ実行
  ```bash
  terraform apply
  ```

- [ ] デプロイ完了確認（機密情報含む）
  ```bash
  terraform output
  terraform output -json > azure_outputs.json
  ```

**想定される所要時間:** 3〜5分

---

### ステップ4: Azure 認証情報の取得と設定

- [ ] Azure出力値を取得
  ```bash
  cd ../azure/
  terraform output aoai_endpoint
  terraform output aoai_primary_key
  terraform output deployment_name
  terraform output api_version
  ```

- [ ] 取得した値をメモ
  - エンドポイントURL（リージョナル形式: `https://eastus2.api.cognitive.microsoft.com`）
  - APIキー（32文字または96文字）
  - デプロイメント名（`gpt4omini-poc`）
  - APIバージョン（`2024-10-21`）

- [ ] FastAPI の環境変数に設定（`configs/.env` ファイル）
  ```bash
  AZURE_OPENAI_ENDPOINT="https://eastus2.api.cognitive.microsoft.com"
  AZURE_OPENAI_API_KEY="<取得したAPIキー>"
  AZURE_OPENAI_DEPLOYMENT_MINI="gpt4omini-poc"
  AZURE_OPENAI_API_VERSION="2024-10-21"
  ```

> **注意**: エンドポイントは**リージョナル形式**（`https://<region>.api.cognitive.microsoft.com`）です。カスタムサブドメイン形式（`https://<resource-name>.openai.azure.com`）ではありません。

---

## 🧪 動作確認

### AWS リソース確認

- [ ] Lambda関数が作成されているか
  ```bash
  aws lambda get-function --function-name poc-mc-vision-handler
  ```

- [ ] S3イベント通知が設定されているか
  ```bash
  aws s3api get-bucket-notification-configuration --bucket poc-mc-vision-upload
  ```

- [ ] DynamoDB テーブルが作成されているか
  ```bash
  aws dynamodb describe-table --table-name poc-mc-vision-table
  ```

- [ ] SageMaker エンドポイントが InService 状態か
  ```bash
  aws sagemaker describe-endpoint --endpoint-name poc-mc-vision-sm
  ```

- [ ] CloudWatch Logs グループが作成されているか
  ```bash
  aws logs describe-log-groups --log-group-name-prefix /aws/lambda/poc-mc-vision
  ```

- [ ] Step Functions が作成されているか
  ```bash
  aws stepfunctions list-state-machines | grep poc-mc-vision-pipeline
  ```

- [ ] SNS トピックが作成されているか
  ```bash
  aws sns list-topics | grep poc-mc-vision-alerts
  ```

- [ ] CloudWatch Alarms が作成されているか（10個）
  ```bash
  aws cloudwatch describe-alarms --alarm-name-prefix poc-mc-vision
  ```

- [ ] ECR リポジトリが作成されているか
  ```bash
  aws ecr describe-repositories --repository-names poc-mc-vision-fastapi
  ```

### Azure リソース確認

- [ ] Resource Group が作成されているか
  ```bash
  az group show --name rg-aoai-poc
  ```

- [ ] Cognitive Account が作成されているか
  ```bash
  az cognitiveservices account show \
    --name aoai-poc-vision-eastus2 \
    --resource-group rg-aoai-poc
  ```

- [ ] Deployment が作成されているか
  ```bash
  az cognitiveservices account deployment list \
    --name aoai-poc-vision-eastus2 \
    --resource-group rg-aoai-poc
  ```

### エンドツーエンドテスト

- [ ] テスト画像をS3にアップロード
  ```bash
  aws s3 cp /path/to/test-image.jpg s3://poc-mc-vision-upload/test/
  ```

- [ ] Lambda が自動起動したか確認（S3イベントログ確認）
  ```bash
  aws logs tail /aws/lambda/poc-mc-vision-handler --follow
  ```

- [ ] FastAPI を起動して画像推論リクエスト送信

- [ ] DynamoDB にレコードが保存されたか確認
  ```bash
  aws dynamodb scan --table-name poc-mc-vision-table --max-items 5
  ```

---

## ⚠️ トラブルシューティング

### エラー: S3バケット名の競合

```
Error: creating S3 Bucket (poc-mc-vision-upload): BucketAlreadyExists
```

**解決策:**
1. `terraform/aws/variables.tf` を編集
2. `s3_bucket_name` のデフォルト値を変更（例: `poc-mc-vision-upload-12345`）
3. 再度 `terraform apply` 実行

### エラー: S3バケット削除失敗（BucketNotEmpty）

```
Error: deleting S3 Bucket (poc-mc-vision-upload): BucketNotEmpty
```

**原因:** バージョニング有効のため、削除したファイルのバージョン履歴が残っています。

**解決策:**
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

terraform destroy  # 再実行
```

### エラー: SageMaker エンドポイント起動失敗

```
Error: error waiting for SageMaker Endpoint to become available
```

**確認事項:**
1. モデルファイルが正しくS3にアップロードされているか
2. モデルファイルの形式が正しいか（tar.gz）
3. IAMロールに適切な権限があるか

### エラー: Lambda関数がS3イベントで起動しない

**確認事項:**
1. S3イベント通知が正しく設定されているか
   ```bash
   aws s3api get-bucket-notification-configuration --bucket poc-mc-vision-upload
   ```
2. Lambda関数にS3からの実行権限があるか
3. CloudWatch Logsでエラーログを確認

### エラー: Azure認証エラー

```
Error: building account: getting authenticated object ID
```

**解決策:**
```bash
az logout
az login
az account set --subscription "your-subscription-id"
```

### エラー: Azure Resource Provider未登録

```
Error: Encountered an error whilst ensuring Resource Providers are registered.
```

**解決策:**
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

### エラー: Azure OpenAI接続エラー（DNSエラー）

```
Error: Failed to resolve 'aoai-poc-vision-eastus2.openai.azure.com'
```

**原因:** エンドポイントURLの形式が間違っています。

**解決策:** `configs/.env` のエンドポイントを修正
```bash
# 正しい形式（リージョナルエンドポイント）
AZURE_OPENAI_ENDPOINT="https://eastus2.api.cognitive.microsoft.com"

# 間違った形式（カスタムサブドメイン）- 使用不可
# AZURE_OPENAI_ENDPOINT="https://aoai-poc-vision-eastus2.openai.azure.com"
```

### エラー: Azure OpenAIクォータ不足

```
Error: InsufficientQuota: Insufficient quota
```

**原因:** リージョンでAzure OpenAIリソースの上限に達しています。

**解決策:**
1. **別のリージョンを使用** (`swedencentral`, `eastus`, `westus` など)
2. **ソフトデリート状態のリソースをパージ**
   ```bash
   az cognitiveservices account list-deleted
   az cognitiveservices account purge --name <名前> --resource-group <RG> --location <リージョン>
   ```
3. **Azureサポートにクォータ引き上げ申請**

### エラー: ブラウザからS3へのアップロード失敗（CORS）

```
Error: Access to fetch has been blocked by CORS policy
```

**原因:** S3バケットのCORS設定が不足しています。

**解決策:** Terraform v1.9以降では自動的にCORS設定が含まれます。`aws/s3/main.tf` に `aws_s3_bucket_cors_configuration` リソースがあることを確認してください。

---

## 💰 コスト確認

- [ ] AWS Cost Explorer でコスト確認
  - S3ストレージ料金
  - Lambda実行料金
  - DynamoDB使用料金
  - SageMaker推論料金
  - Bedrock API呼び出し料金

- [ ] Azure Cost Management でコスト確認
  - Cognitive Services料金（保有のみなら$0）
  - GPT-4o-mini API呼び出し料金

**想定月額コスト:** $5〜15（使用量により変動）

---

## 🗑️ リソース削除（必要時）

### 削除前の確認

- [ ] 重要なデータはバックアップ済みか
- [ ] S3バケット内のデータは削除してよいか
- [ ] DynamoDBのデータは削除してよいか

### 削除手順（逆順で実行）

1. [ ] Azure リソース削除
   ```bash
   cd Terraform/azure/
   terraform destroy
   ```

2. [ ] AWS S3バケット内のオブジェクトを削除（バージョニング対応）
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
   ```

3. [ ] AWS リソース削除
   ```bash
   cd ../aws/
   terraform destroy
   ```

4. [ ] S3バケット削除（手動作成したもの）
   ```bash
   aws s3 rb s3://poc-mc-vision-zip --force
   ```

5. [ ] State管理リソース削除（最後に実行）
   ```bash
   aws dynamodb delete-table --table-name poc-mc-vision-terraform-locks
   aws s3 rb s3://poc-mc-vision-terraform-state-aws --force
   aws s3 rb s3://poc-mc-vision-terraform-state-azure --force
   ```

---

## 📝 次のステップ

- [ ] FastAPI バックエンドに環境変数を設定（`configs/.env` ファイル）
  - Azure認証情報（エンドポイント、APIキー）
  - エンドポイントは**リージョナル形式**を使用
- [ ] フロントエンド（React）の環境変数設定
- [ ] 実際の画像推論テスト（FastAPI経由）
- [ ] パフォーマンスチューニング
  - SageMaker Serverless のメモリサイズ調整（variables.tf で調整）
  - FastAPI のタイムアウト調整
  - 並列度調整

---

## 📋 実装された主要機能

- ✅ **Step Functions ワークフロー**: SageMaker→並列(Bedrock+Azure)→DynamoDB→SNS の推論パイプライン
- ✅ **CloudWatch Alarms**: Lambda/Step Functionsの障害・遅延を自動検知（10個のアラーム）
- ✅ **SNS Email通知**: アラーム発報時とパイプライン完了時の通知
- ✅ **ECR コンテナリポジトリ**: FastAPI & Pipeline Worker のコンテナ管理
- ✅ **S3 CORS設定**: ブラウザからの直接アップロード対応
- ✅ **Azure Resource Provider登録手順**: 初回デプロイ時の必須手順
- ✅ **Azure OpenAIエンドポイント形式**: リージョナルエンドポイントの説明
- ✅ **S3バケット削除手順**: バージョニング対応の削除方法
- ✅ **トラブルシューティング拡充**: 実際の検証で遭遇したエラーと解決策

---

**チェックリスト最終更新**: 2025-11-22
**想定デプロイ時間**: 約15〜20分（State管理含む）
**対象環境**: AWS ap-northeast-1 / Azure eastus2
