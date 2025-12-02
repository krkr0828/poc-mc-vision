# PoC MC Vision - Getting Started

このドキュメントは、PoC MC Visionプロジェクトを初めてセットアップする方向けの**初回セットアップガイド**です。

## 📚 ドキュメント構成

| ドキュメント | 対象読者 | 内容 |
|------------|---------|------|
| **このドキュメント**<br>(GETTING_STARTED.md) | プロジェクト全体の初回セットアップ手順 |
| [CI_CD_TESTING_GUIDE.md](./CI_CD_TESTING_GUIDE.md) | CI/CDの使い方、テスト手順 |
| [DOCKER_ECR_DEPLOYMENT_GUIDE.md](./DOCKER_ECR_DEPLOYMENT_GUIDE.md) | システムアーキテクチャ<br>手動デプロイ手順 |
| [Terraform/SETUP_GUIDE.md](../Terraform/SETUP_GUIDE.md) | Terraform特化のセットアップ |

---

## 全体フロー

```
ステップ1: 前提条件の確認
    ↓
ステップ2: AWSリソースの作成（Terraform）
    ↓
ステップ3: 初回Dockerイメージのプッシュ
    ↓
ステップ4: CI/CD設定の確認
    ↓
ステップ5: 開発開始
```

---

## ステップ1: 前提条件の確認

### 必要なツール

以下がインストールされていることを確認してください：

```bash
# Terraform
terraform version
# 推奨: 1.9.8以上

# AWS CLI
aws --version
# 推奨: 2.x以上

# Docker
docker --version
# 推奨: 20.x以上

# Git
git --version
```

### AWSアカウントとアクセス設定

```bash
# AWSアカウントIDの確認
aws sts get-caller-identity

# 出力例:
# {
#     "UserId": "AIDAI...",
#     "Account": "851725351287",
#     "Arn": "arn:aws:iam::851725351287:user/your-user"
# }
```

**必要な権限**:
- EC2、Lambda、ECR、S3、DynamoDB、IAM、Step Functions、SageMakerへのアクセス権限
- 詳細は [Terraform/SETUP_GUIDE.md](../Terraform/SETUP_GUIDE.md) を参照

---

## ステップ2: AWSリソースの作成（Terraform）

> **初回のみ: ECR を手動で作成**
>
> 初回は ECR リポジトリ `poc-mc-vision-fastapi` が存在しないため、そのまま Terraform を最後まで実行すると Lambda 作成で失敗します。  
> 先に AWS コンソール等で空のリポジトリを作成しておくか、Terraform を `-target=module.ecr` で部分適用したあとに Docker イメージを push してください。2 回目以降は通常どおり `terraform apply` を実行すれば問題ありません。

### 2-1. リポジトリのクローン

```bash
git clone <repository-url>
cd poc-mc-vision
```

### 2-2. Terraformでインフラを作成

```bash
cd Terraform/aws

# 初期化
terraform init

# 実行計画の確認
terraform plan

# インフラの作成
terraform apply
```

**作成されるリソース**:
- ECRリポジトリ（`poc-mc-vision-fastapi`）
- Lambda関数（`poc-mc-vision-fastapi`、`poc-mc-vision-pipeline-worker`）
- S3バケット、DynamoDB、Step Functions、その他

**詳細な手順**: [Terraform/SETUP_GUIDE.md](../Terraform/SETUP_GUIDE.md) を参照

**⚠️ 注意**: この時点でLambda関数はエラー状態になります（ECRにイメージがないため）。次のステップで解決します。

---

## ステップ3: 初回Dockerイメージのプッシュ

初回のみ、手動でDockerイメージをECRにプッシュする必要があります（前ステップで ECR リポジトリを用意済みであることが前提です）。

### 方法A: 手動プッシュ（推奨）

```bash
# AWSアカウントIDを取得
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# ECRにログイン
aws ecr get-login-password --region ap-northeast-1 \
  | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com

# Dockerイメージをビルド
cd src/backend
docker build --platform linux/amd64 \
  -t ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest \
  -f Dockerfile .

# ECRにプッシュ
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest

# Lambda関数を更新
aws lambda update-function-code \
  --function-name poc-mc-vision-fastapi \
  --image-uri ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest \
  --region ap-northeast-1

aws lambda update-function-code \
  --function-name poc-mc-vision-pipeline-worker \
  --image-uri ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest \
  --region ap-northeast-1
```

**期待される結果**: Lambda関数のステータスが "Active" になる

### 方法B: GitHub Actionsで手動実行

GitHub Actionsで手動実行することも可能です（CI/CD設定後）：

1. GitHubリポジトリの **Actions** タブを開く
2. **"Build and Push Docker Image"** を選択
3. **"Run workflow"** をクリック → **"Run workflow"** ボタンをクリック

**詳細な手順**: [DOCKER_ECR_DEPLOYMENT_GUIDE.md - 初回セットアップ](./DOCKER_ECR_DEPLOYMENT_GUIDE.md#初回セットアップ) を参照

---

## ステップ4: CI/CD設定の確認

### 4-1. GitHub Secretsの設定

リポジトリの **Settings** → **Secrets and variables** → **Actions** で以下を設定：

```
AWS_ACCESS_KEY_ID       = <あなたのAWSアクセスキー>
AWS_SECRET_ACCESS_KEY   = <あなたのAWSシークレットキー>
AWS_REGION              = ap-northeast-1
```

### 4-2. CI/CDワークフローの確認

以下のワークフローファイルが存在することを確認：

```bash
ls -la .github/workflows/
# 期待される出力:
# - docker-build-push.yml
# - terraform-apply.yml
# - terraform-plan.yml
```

### 4-3. 動作確認（オプション）

簡単なテスト変更を行い、CI/CDが動作することを確認：

```bash
# テスト用の変更
echo "# CI/CD Test - $(date)" >> src/backend/main.py

# コミット＆プッシュ
git add src/backend/main.py
git commit -m "test: CI/CD動作確認"
git push origin main
```

GitHubの **Actions** タブで "Build and Push Docker Image" ワークフローが実行されることを確認。

---

## ステップ5: 開発開始

セットアップが完了しました！以降は通常の開発フローで作業できます。

### 日常的な開発フロー

```
コード編集（src/backend/ または Terraform/）
    ↓
git commit & push to main
    ↓
GitHub Actions 自動実行
    ↓
AWS自動デプロイ
```

**詳細**: [CI_CD_TESTING_GUIDE.md](./CI_CD_TESTING_GUIDE.md) を参照

### 開発時の主要コマンド

```bash
# Lambda関数の状態確認
aws lambda get-function --function-name poc-mc-vision-fastapi --region ap-northeast-1

# ECRイメージの確認
aws ecr describe-images --repository-name poc-mc-vision-fastapi --region ap-northeast-1

# Lambda関数のログ確認
aws logs tail /aws/lambda/poc-mc-vision-fastapi --follow --region ap-northeast-1

# CloudWatch ダッシュボードでシステム全体を監視
# AWSコンソール: CloudWatch → Dashboards → poc-mc-vision-operations
```

**運用監視**: CloudWatch ダッシュボード（`poc-mc-vision-operations`）で、Step Functions、SageMaker、Lambda、DynamoDBの状態を一画面で確認できます。詳細は [aws-console-setup-guide.md](../aws-console-setup-guide.md#35-cloudwatch-ダッシュボードの作成運用監視画面) を参照。

---

## トラブルシューティング

### Lambda関数がエラー状態

**症状**: `State: Failed` または `LastUpdateStatus: Failed`

**原因**: ECRにイメージがない、またはイメージが壊れている

**解決策**:
1. [ステップ3](#ステップ3-初回dockerイメージのプッシュ) を再実行
2. 詳細: [DOCKER_ECR_DEPLOYMENT_GUIDE.md - トラブルシューティング](./DOCKER_ECR_DEPLOYMENT_GUIDE.md#トラブルシューティング)

### Terraform applyが失敗

**原因**: AWSリソースの制限、権限不足、既存リソースとの競合など

**解決策**:
1. エラーメッセージを確認
2. 詳細: [Terraform/SETUP_GUIDE.md](../Terraform/SETUP_GUIDE.md) を参照

### Docker buildが失敗

**原因**: Dockerfileの構文エラー、requirements.txtのパッケージ問題など

**解決策**:
1. ローカルでビルドテスト: `docker build -f src/backend/Dockerfile src/backend`
2. 詳細: [DOCKER_ECR_DEPLOYMENT_GUIDE.md - トラブルシューティング](./DOCKER_ECR_DEPLOYMENT_GUIDE.md#トラブルシューティング)

### CI/CDが実行されない

**原因**: pathsフィルタ、ブランチ、GitHub Actionsの設定など

**解決策**:
1. 変更したファイルのパスを確認: `git diff --name-only HEAD~1`
2. ブランチを確認: `git branch --show-current` → `main` であること
3. 詳細: [CI_CD_TESTING_GUIDE.md - トラブルシューティング](./CI_CD_TESTING_GUIDE.md#トラブルシューティング)

---
