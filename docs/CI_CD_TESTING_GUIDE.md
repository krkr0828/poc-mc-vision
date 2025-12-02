# CI/CD テスト手順書

> **📌 このドキュメントの位置付け**
>
> このドキュメントは**CI/CDの運用・テスト手順書**です。日常的な開発で使用します。
>
> **各ドキュメントの役割**:
> - **初回セットアップ**: [GETTING_STARTED.md](./GETTING_STARTED.md) を参照
> - **このドキュメント**: CI/CDの使い方、テスト手順、日常的な開発フロー
> - **手動デプロイ・技術詳細**: [DOCKER_ECR_DEPLOYMENT_GUIDE.md](./DOCKER_ECR_DEPLOYMENT_GUIDE.md) を参照
>
> **前提**: 初回セットアップが完了していること（ECRにイメージが存在し、CI/CDが設定済み）

---

このドキュメントでは、実装済みのCI/CDパイプラインの使い方とテスト手順を説明します。

## 目次

- [前提条件](#前提条件)
- [初回セットアップ](#初回セットアップ)
- [テストシナリオ](#テストシナリオ)
  - [シナリオ1: アプリケーションコードのみ変更](#シナリオ1-アプリケーションコードのみ変更)
  - [シナリオ2: Terraformのみ変更](#シナリオ2-terraformのみ変更)
  - [シナリオ3: 両方同時に変更](#シナリオ3-両方同時に変更)
- [GitHub Actionsでの確認方法](#github-actionsでの確認方法)
- [ワークフロー実行結果の確認](#ワークフロー実行結果の確認)
- [トラブルシューティング](#トラブルシューティング)

---

## 前提条件

> **初回セットアップ**: GitHub Secretsの設定やEnvironmentの作成など、CI/CDの初期設定は [../Terraform/TERRAFORM_CICD_SETUP_GUIDE.md](../Terraform/TERRAFORM_CICD_SETUP_GUIDE.md) を参照してください。
>
> このドキュメントは**初期設定が完了していることを前提**とした運用ガイドです。

### 1. GitHub Secretsの確認

以下のSecretsが設定済みであることを確認：

```
✅ AWS_ACCESS_KEY_ID
✅ AWS_SECRET_ACCESS_KEY
✅ AWS_REGION (ap-northeast-1)
```

確認方法: リポジトリの Settings → Secrets and variables → Actions

### 2. AWSリソースの確認

以下のリソースがTerraformで作成済みであることを確認：

```bash
# ECRリポジトリの確認
aws ecr describe-repositories --repository-names poc-mc-vision-fastapi --region ap-northeast-1

# Lambda関数の確認
aws lambda get-function --function-name poc-mc-vision-fastapi --region ap-northeast-1
aws lambda get-function --function-name poc-mc-vision-pipeline-worker --region ap-northeast-1
```

もしリソースが存在しない場合は、先にTerraformを実行してください：

```bash
cd Terraform/aws
terraform init
terraform plan
terraform apply
```

### 3. ECRイメージの確認

ECRにイメージが既に存在するか確認：

```bash
aws ecr describe-images \
  --repository-name poc-mc-vision-fastapi \
  --region ap-northeast-1
```

**イメージが存在しない場合**: [初回セットアップ](#初回セットアップ) を実行してください。

---

## 初回セットアップ

ECRにイメージがまだ存在しない場合、**初回のみ手動でDockerイメージをプッシュ**する必要があります。  
併せて、リポジトリ `poc-mc-vision-fastapi` 自体が存在しない場合は AWS コンソール等で先に作成しておいてください（Terraform で Lambda 作成が失敗するのを防ぐため）。 repo 作成後は以下の手順でイメージをビルド・プッシュします。

### ステップ1: AWSアカウントIDを取得

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: ${AWS_ACCOUNT_ID}"
```

### ステップ2: ECRにログイン

```bash
aws ecr get-login-password --region ap-northeast-1 \
  | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com
```

**期待される出力**:
```
Login Succeeded
```

### ステップ3: Dockerイメージをビルド

```bash
cd src/backend

docker build --platform linux/amd64 \
  -t ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest \
  -f Dockerfile .
```

**期待される出力**:
```
[+] Building 45.2s (10/10) FINISHED
...
Successfully tagged 851725351287.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest
```

### ステップ4: ECRにプッシュ

```bash
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest
```

**期待される出力**:
```
The push refers to repository [851725351287.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi]
latest: digest: sha256:abc123... size: 1234
```

### ステップ5: Lambda関数を更新

```bash
aws lambda update-function-code \
  --function-name poc-mc-vision-fastapi \
  --image-uri ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest \
  --region ap-northeast-1

aws lambda update-function-code \
  --function-name poc-mc-vision-pipeline-worker \
  --image-uri ${AWS_ACCOUNT_ID}.dkr.ecr.ap-northeast-1.amazonaws.com/poc-mc-vision-fastapi:latest \
  --region ap-northeast-1
```

### ステップ6: Lambda関数の状態確認

```bash
aws lambda get-function --function-name poc-mc-vision-fastapi --region ap-northeast-1 \
  --query 'Configuration.[State,LastUpdateStatus]' --output table

aws lambda get-function --function-name poc-mc-vision-pipeline-worker --region ap-northeast-1 \
  --query 'Configuration.[State,LastUpdateStatus]' --output table
```

**期待される出力**:
```
--------------------
|  GetFunction     |
+--------+-----------+
|  Active|  Successful|
+--------+-----------+
```

初回セットアップが完了したら、以降はCI/CDで自動的にデプロイされます。

---

## テストシナリオ

### シナリオ1: アプリケーションコードのみ変更

このシナリオでは、`src/backend/`配下のファイルを変更し、Dockerワークフローのみが実行されることを確認します。

#### ステップ1: テスト用の変更を加える

```bash
# リポジトリのルートディレクトリで実行
cd /path/to/poc-mc-vision

# main.pyにコメントを追加（軽微な変更）
echo "# CI/CD Test - $(date)" >> src/backend/main.py
```

#### ステップ2: 変更をコミット＆プッシュ

```bash
git add src/backend/main.py
git commit -m "test: CI/CD test for Docker workflow"
git push origin main
```

#### ステップ3: GitHub Actionsで確認

1. ブラウザでGitHubリポジトリを開く
2. **Actions** タブをクリック
3. 以下を確認：
   - ✅ **"Build and Push Docker Image"** ワークフローが実行されている
   - ❌ **"Terraform Apply"** ワークフローは実行されない（pathsフィルタで除外）

#### 期待される動作

```
時刻 0:00 - git push
    ↓
時刻 0:01 - "Build and Push Docker Image" 実行開始
    ├─ Checkout code
    ├─ Configure AWS credentials
    ├─ Login to Amazon ECR
    ├─ Build, tag, and push image
    ├─ Update Lambda FastAPI function
    ├─ Update Lambda Pipeline Worker function
    ├─ Wait for Lambda updates
    └─ Summary
    ↓
時刻 0:04-0:06 - ワークフロー完了 ✅

所要時間: 3-5分
```

#### ステップ4: 結果確認

```bash
# Lambda関数が更新されたことを確認
aws lambda get-function --function-name poc-mc-vision-fastapi --region ap-northeast-1 \
  --query 'Configuration.[LastModified,CodeSha256]' --output table

# ECRに新しいイメージがプッシュされたことを確認
aws ecr describe-images \
  --repository-name poc-mc-vision-fastapi \
  --region ap-northeast-1 \
  --query 'sort_by(imageDetails,& imagePushedAt)[-1].[imageTags[0],imagePushedAt]' \
  --output table
```

---

### シナリオ2: Terraformのみ変更

このシナリオでは、`Terraform/`配下のファイルを変更し、Terraformワークフロー完了後にDockerワークフローも実行されることを確認します。

#### ステップ1: テスト用の変更を加える

```bash
# Terraform設定に軽微な変更を加える（例: コメント追加）
echo "# CI/CD Test - $(date)" >> Terraform/aws/variables.tf
```

または、実際の設定変更（例: Lambda環境変数の追加）：

```bash
# variables.tfを編集
vim Terraform/aws/variables.tf

# 例: 新しい環境変数を追加
# variable "test_env_var" {
#   description = "Test environment variable"
#   type        = string
#   default     = "test-value"
# }
```

#### ステップ2: 変更をコミット＆プッシュ

```bash
git add Terraform/aws/variables.tf
git commit -m "test: CI/CD test for Terraform workflow"
git push origin main
```

#### ステップ3: GitHub Actionsで確認

1. ブラウザでGitHubリポジトリを開く
2. **Actions** タブをクリック
3. 以下を確認：
   - ✅ **"Terraform Apply"** ワークフローが先に実行される
   - ✅ Terraform完了後、**"Build and Push Docker Image"** が自動実行される（workflow_runトリガー）

#### 期待される動作

```
時刻 0:00 - git push (Terraform/)
    ↓
時刻 0:01 - "Terraform Apply" 実行開始
    ├─ concurrency group獲得: infrastructure-deployment
    ├─ Terraform Init
    ├─ Terraform Format Check
    ├─ Terraform Validate
    ├─ Run tfsec
    ├─ Terraform Plan
    └─ Terraform Apply
    ↓
時刻 0:03 - "Terraform Apply" 完了 ✅
    ↓ concurrency group 解放
    ↓ workflow_run トリガー発火
    ↓
時刻 0:03 - "Build and Push Docker Image" 実行開始
    ├─ concurrency group獲得: infrastructure-deployment
    ├─ Docker build & push
    └─ Lambda update
    ↓
時刻 0:07 - "Build and Push Docker Image" 完了 ✅

所要時間: 5-8分
```

#### ステップ4: 結果確認

```bash
# GitHub Actionsのログで順序を確認
# ブラウザで Actions タブ → Workflowsの実行時刻を確認

# Terraformの変更が適用されたことを確認
cd Terraform/aws
terraform show

# Lambdaも更新されたことを確認
aws lambda get-function --function-name poc-mc-vision-fastapi --region ap-northeast-1 \
  --query 'Configuration.LastModified' --output text
```

---

### シナリオ3: 両方同時に変更

このシナリオでは、`src/backend/`と`Terraform/`の両方を変更し、Concurrency制御により無駄な実行が防止されることを確認します。

#### ステップ1: 両方のファイルに変更を加える

```bash
# アプリケーションコードの変更
echo "# CI/CD Test Both - $(date)" >> src/backend/main.py

# Terraform設定の変更
echo "# CI/CD Test Both - $(date)" >> Terraform/aws/variables.tf
```

#### ステップ2: 変更をコミット＆プッシュ

```bash
git add src/backend/main.py Terraform/aws/variables.tf
git commit -m "test: CI/CD test for both workflows with concurrency"
git push origin main
```

#### ステップ3: GitHub Actionsで確認

1. ブラウザでGitHubリポジトリを開く
2. **Actions** タブをクリック
3. 以下の動作を確認：
   - ✅ **"Terraform Apply"** が先に実行開始
   - ⏸️ **"Build and Push Docker Image"** (pushトリガー) がキュー待機
   - ✅ Terraform完了後、キュー待ちのDockerジョブがキャンセルされる
   - ✅ workflow_runトリガーで新しいDockerジョブが実行される

#### 期待される動作（Concurrency制御あり）

```
時刻 0:00 - git push (Terraform/ + src/backend/)
    ↓
時刻 0:01 - 両方のワークフローがトリガー検知
    │
    ├─ "Terraform Apply" 実行開始
    │   └─ concurrency group獲得: infrastructure-deployment
    │       ↓ Terraform処理中...
    │
    └─ "Build and Push Docker Image" (pushトリガー)
        └─ concurrency group獲得待ち（キュー）
            ⏸️ 待機中...

時刻 0:03 - "Terraform Apply" 完了 ✅
    ↓ concurrency group 解放
    ↓ workflow_run トリガー発火
    ↓
    ├─ キュー待ちのDockerジョブ → キャンセル
    └─ workflow_runトリガーのDockerジョブ → 実行開始
        └─ concurrency group獲得: infrastructure-deployment
            ↓ Docker処理...

時刻 0:07 - "Build and Push Docker Image" 完了 ✅

所要時間: 5-8分
Docker実行回数: 1回のみ（無駄な実行なし）
```

#### ステップ4: Concurrency動作の確認

GitHub Actionsの画面で以下を確認：

1. **Terraform Apply** のステータス
   - Status: "Completed"
   - Conclusion: "Success"

2. **Build and Push Docker Image** のステータス
   - pushトリガーのジョブ: "Cancelled" または "Skipped"
   - workflow_runトリガーのジョブ: "Completed" / "Success"

3. タイムスタンプの確認
   - Dockerジョブが Terraformジョブの完了後に開始されていること

---

## GitHub Actionsでの確認方法

### ワークフロー実行画面の見方

1. **リポジトリページ** → **Actions** タブをクリック

2. **左サイドバー**で確認したいワークフローを選択：
   - "Build and Push Docker Image"
   - "Terraform Apply"

3. **実行履歴**で最新のワークフローをクリック

4. **ジョブの詳細**を確認：
   - 各ステップの実行時間
   - ログ出力
   - 成功/失敗ステータス

### 重要な確認ポイント

#### 1. トリガーの確認

ワークフロー詳細画面の上部に表示される：

```
Triggered via push by <username>
Triggered via workflow_run by <username>
Triggered via workflow_dispatch by <username>
```

#### 2. Concurrencyの確認

ワークフローログの最初に表示される：

```
Waiting for concurrency group 'infrastructure-deployment' to be free...
```

または

```
Running with concurrency group 'infrastructure-deployment'
```

#### 3. 条件分岐の確認

Dockerワークフローのジョブ開始時に：

```
if: github.event_name == 'push' || ...
Result: true
```

Terraform失敗時は：

```
if: ... github.event.workflow_run.conclusion == 'success'
Result: false (skipped)
```

---

## ワークフロー実行結果の確認

### 1. GitHubのUI上での確認

#### Summary（サマリー）の確認

各ワークフロー実行の最後に、カスタムサマリーが表示されます：

**Terraform Apply の Summary**:
```
### Terraform Apply Successful ✅

**Commit:** abc123def456...
**Triggered by:** @your-username
**Workflow Run:** View logs
```

**Build and Push Docker Image の Summary**:
```
### Docker Image Build & Push Successful ✅

**Image Tag:** abc123def456...
**ECR Repository:** poc-mc-vision-fastapi
**Updated Functions:**
- poc-mc-vision-fastapi
- poc-mc-vision-pipeline-worker

**Trigger:** push
```

#### Annotations（注釈）の確認

エラーや警告がある場合、コードに直接アノテーションが表示されます。

### 2. AWS CLIでの確認

#### ECRイメージの確認

```bash
# 最新のイメージを確認
aws ecr describe-images \
  --repository-name poc-mc-vision-fastapi \
  --region ap-northeast-1 \
  --query 'sort_by(imageDetails,& imagePushedAt)[-5:].[imageTags[0],imagePushedAt,imageSizeInBytes]' \
  --output table
```

**期待される出力**:
```
--------------------------------------------------------
|                   DescribeImages                     |
+------------------+----------------------+-------------+
|  latest          |  2025-11-26T10:30:00 |  456789012  |
|  abc123def456... |  2025-11-26T10:30:00 |  456789012  |
+------------------+----------------------+-------------+
```

#### Lambda関数の確認

```bash
# 最終更新時刻を確認
aws lambda get-function --function-name poc-mc-vision-fastapi --region ap-northeast-1 \
  --query 'Configuration.[FunctionName,LastModified,State,LastUpdateStatus]' \
  --output table

aws lambda get-function --function-name poc-mc-vision-pipeline-worker --region ap-northeast-1 \
  --query 'Configuration.[FunctionName,LastModified,State,LastUpdateStatus]' \
  --output table
```

**期待される出力**:
```
-------------------------------------------------------------------
|                         GetFunction                             |
+-------------------------------+----------+--------+-------------+
|  poc-mc-vision-fastapi        |  2025... |  Active|  Successful |
+-------------------------------+----------+--------+-------------+
```

#### Lambda関数のテスト実行

```bash
# FastAPI Lambda のテスト
aws lambda invoke \
  --function-name poc-mc-vision-fastapi \
  --payload '{"test": "data"}' \
  --region ap-northeast-1 \
  response.json

cat response.json
```

### 3. CloudWatch Logsでの確認

```bash
# Lambda関数のログを確認
aws logs tail /aws/lambda/poc-mc-vision-fastapi --follow --region ap-northeast-1

# エラーログのみを確認
aws logs tail /aws/lambda/poc-mc-vision-fastapi --filter-pattern "ERROR" --region ap-northeast-1
```

### 4. CloudWatch ダッシュボードでの確認

運用監視用のダッシュボードで、システム全体の状態を視覚的に確認できます：

```bash
# ダッシュボードの存在確認
aws cloudwatch list-dashboards --region ap-northeast-1 | grep poc-mc-vision-operations

# AWSコンソールでダッシュボードを開く
# CloudWatch → Dashboards → poc-mc-vision-operations
```

**ダッシュボードで確認できる項目**:
- Step Functions の実行状況（成功/失敗数、実行時間）
- SageMaker エンドポイントのメトリクス（呼び出し数、エラー、レイテンシ）
- Lambda 関数のメトリクス（Pipeline Worker、FastAPI）
- DynamoDB のメトリクス（書き込み容量、スロットリング、レイテンシ）

---

## トラブルシューティング

### 問題1: ワークフローが実行されない

#### 症状
```
git pushしても GitHub Actionsが実行されない
```

#### 原因と対処法

**原因1**: pathsフィルタに該当しない

```bash
# 変更したファイルのパスを確認
git diff --name-only HEAD~1

# 期待されるパス:
# - src/backend/**  → Dockerワークフローがトリガー
# - Terraform/**    → Terraformワークフローがトリガー
```

**原因2**: ブランチが異なる

```bash
# 現在のブランチを確認
git branch --show-current

# mainブランチでない場合、mainにマージ
git checkout main
git merge your-branch
git push origin main
```

**原因3**: GitHub Actionsが無効

1. リポジトリの **Settings** → **Actions** → **General**
2. "Actions permissions" が "Allow all actions and reusable workflows" になっているか確認

---

### 問題2: Terraform Applyが失敗してDockerワークフローが実行されない

#### 症状
```
Terraform Apply: ❌ Failed
Build and Push Docker Image: ⏸️ Skipped
```

#### 原因と対処法

これは**正常な動作**です（オプションBの実装）。

Terraform Applyが成功するまでDockerワークフローは実行されません。

**対処法**:

1. Terraform Applyのログを確認
2. エラーを修正
3. 修正をコミット＆プッシュ
4. Terraform成功後、Dockerワークフローが自動実行される

---

### 問題3: Docker buildが失敗

#### 症状
```
Error: failed to solve: failed to fetch ...
```

#### 原因と対処法

**原因1**: Dockerfileの構文エラー

```bash
# ローカルでDockerfileを検証
cd src/backend
docker build --platform linux/amd64 -f Dockerfile .
```

**原因2**: requirements.txtのパッケージがインストールできない

```bash
# requirements.txtを確認
cat src/backend/requirements.txt

# ローカルでインストールテスト
pip install -r src/backend/requirements.txt
```

**修正後**:

```bash
git add src/backend/Dockerfile src/backend/requirements.txt
git commit -m "fix: Fix Docker build issues"
git push origin main
```

---

### 問題4: ECR pushが失敗

#### 症状
```
Error: denied: Your authorization token has expired
```

#### 原因と対処法

GitHub ActionsのAWS認証情報が正しくない可能性があります。

**対処法**:

1. **GitHub Secrets の確認**
   - Settings → Secrets and variables → Actions
   - `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` が正しいか確認

2. **IAMポリシーの確認**

```bash
# 使用しているIAMユーザー/ロールの権限を確認
aws iam get-user-policy --user-name <your-user> --policy-name <policy-name>
```

必要な権限:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    }
  ]
}
```

---

### 問題5: Lambda updateが失敗

#### 症状
```
Error: ResourceConflictException: The operation cannot be performed at this time.
An update is in progress for resource: arn:aws:lambda:...
```

#### 原因と対処法

Lambdaが別の更新処理中です。

**対処法**:

1. **待機して再実行**

GitHub Actionsの画面で "Re-run failed jobs" をクリック

2. **手動で更新状態を確認**

```bash
aws lambda get-function --function-name poc-mc-vision-fastapi --region ap-northeast-1 \
  --query 'Configuration.[State,LastUpdateStatus]'

# 出力が ["Active", "Successful"] になるまで待つ
```

---

### 問題6: Concurrencyが期待通りに動作しない

#### 症状
```
両方のワークフローが同時に実行され、Dockerが2回実行される
```

#### 原因と対処法

**原因**: concurrencyグループ名が一致していない

**確認方法**:

```bash
# 両ワークフローのconcurrencyグループを確認
grep -A 2 "concurrency:" .github/workflows/terraform-apply.yml
grep -A 2 "concurrency:" .github/workflows/docker-build-push.yml
```

**期待される出力**:
```
.github/workflows/terraform-apply.yml:concurrency:
.github/workflows/terraform-apply.yml-  group: infrastructure-deployment
.github/workflows/terraform-apply.yml-  cancel-in-progress: false
--
.github/workflows/docker-build-push.yml:concurrency:
.github/workflows/docker-build-push.yml-  group: infrastructure-deployment
.github/workflows/docker-build-push.yml-  cancel-in-progress: false
```

両方の`group`が一致していることを確認してください。

---

### 問題7: workflow_runトリガーが発火しない

#### 症状
```
Terraform Apply完了後、Dockerワークフローが実行されない
```

#### 原因と対処法

**原因1**: ワークフロー名が一致していない

```bash
# terraform-apply.ymlのnameを確認
grep "^name:" .github/workflows/terraform-apply.yml

# docker-build-push.ymlのworkflows指定を確認
grep "workflows:" .github/workflows/docker-build-push.yml
```

**期待される出力**:
```
.github/workflows/terraform-apply.yml:name: Terraform Apply
.github/workflows/docker-build-push.yml:    workflows: ["Terraform Apply"]
```

名前が完全一致していることを確認してください。

**原因2**: ブランチが一致していない

workflow_runトリガーは`branches: - main`に限定されています。

```bash
# 現在のブランチを確認
git branch --show-current
# → main であることを確認
```

---

## まとめ

### CI/CD実装の全体像

```
開発フロー:
  ① コード編集（src/backend/ または Terraform/）
  ② git commit & push to main
  ③ GitHub Actions 自動実行
     ├─ src/backend/ 変更 → Dockerワークフローのみ
     ├─ Terraform/ 変更 → Terraform → Docker（連鎖）
     └─ 両方変更 → Terraform → Docker（直列、1回のみ）
  ④ AWS自動デプロイ
  ⑤ Lambda関数が最新コードで稼働
```

### テストの推奨順序

1. ✅ **シナリオ1** から開始（最もシンプル）
2. ✅ 成功したら **シナリオ2** を実行（workflow_run動作確認）
3. ✅ 最後に **シナリオ3** を実行（concurrency動作確認）

### 重要なポイント

- 初回のみ手動でECRにイメージをプッシュ
- GitHub Secretsの設定が必須
- Terraform成功時のみDockerワークフローが実行される（安全性）
- Concurrencyにより無駄な実行が防止される

---
