# Terraform CI/CD 初期設定ガイド

このガイドでは、**Terraform CI/CDパイプライン**を動作させるために必要なGitHub Actionsの初期設定手順を説明します。

> **📌 注意**: このドキュメントはTerraform CI/CD（`terraform-plan.yml`、`terraform-apply.yml`）に特化しています。
>
> **Docker/ECR CI/CD**（`docker-build-push.yml`）については、以下のドキュメントを参照してください：
> - [docs/CI_CD_TESTING_GUIDE.md](../docs/CI_CD_TESTING_GUIDE.md) - CI/CDの運用・テスト手順
> - [docs/DOCKER_ECR_DEPLOYMENT_GUIDE.md](../docs/DOCKER_ECR_DEPLOYMENT_GUIDE.md) - Docker・ECR技術リファレンス

## 前提条件

- GitHubリポジトリ: `https://github.com/<YOUR_USERNAME>/<YOUR_REPO>`
- AWS認証情報（Access Key ID / Secret Access Key）
- リポジトリへの管理者権限

---

## 📋 設定手順

### 【手順0】Personal Access Tokenの作成（初回のみ）

ローカルからGitHubへプッシュするために必要なトークンを作成します。

#### 0-1. トークン作成ページへアクセス

1. GitHubにブラウザでログイン
2. 右上のプロフィールアイコンをクリック → **Settings**
3. 左サイドバー最下部の **Developer settings** をクリック
4. **Personal access tokens** → **Tokens (classic)** を選択
5. **Generate new token** → **Generate new token (classic)** をクリック

#### 0-2. トークン設定

以下の設定でトークンを作成します：

| 項目 | 設定値 | 説明 |
|------|-------|------|
| **Note** | `Terraform CI/CD Development` | トークンの用途説明 |
| **Expiration** | `90 days` または任意 | 有効期限 |
| **Scopes** | | |
| ☑️ **repo** | すべてにチェック | リポジトリへのフルアクセス |
| ☑️ **workflow** | チェック | GitHub Actionsワークフロー管理 |

#### 0-3. トークンの保存

1. **Generate token** をクリック
2. 表示されたトークン（`ghp_xxxxxxxxxxxx`）をコピー
   - ⚠️ **この画面を閉じると二度と表示されません**
   - 安全な場所に保存してください（パスワードマネージャー等）

#### 0-4. トークンの使用方法

ローカルから `git push` する際に使用します：

```bash
git push origin main
# Username: <YOUR_GITHUB_USERNAME>
# Password: ghp_xxxxxxxxxxxx（Personal Access Token）
```

---

### 【手順1】GitHub Secretsの登録

GitHub Actionsで使用する機密情報を登録します。

#### 1-1. Secretsページへアクセス

1. GitHubリポジトリのページを開く
2. 画面上部の **Settings** タブをクリック
3. 左サイドバーの **Secrets and variables** > **Actions** をクリック
4. **New repository secret** ボタンをクリック

#### 1-2. 3つのSecretを登録

以下の3つのSecretを登録してください：

| Name | Value（例） | 説明 |
|------|-------|------|
| `AWS_ACCESS_KEY_ID` | `AKIA****************` | AWSアクセスキーID |
| `AWS_SECRET_ACCESS_KEY` | `****************************************` | AWSシークレットアクセスキー |
| `AWS_REGION` | `ap-northeast-1` | AWSリージョン |

⚠️ **セキュリティ注意:**
- 実際の認証情報は絶対にコードやドキュメントに記載しない
- GitHub Secretsに登録した値は暗号化され、一度登録すると閲覧不可

**登録方法：**
1. **Name** に上記のSecret名を入力
2. **Secret** に対応する値を入力
3. **Add secret** ボタンをクリック
4. 上記を3回繰り返して、3つすべて登録

---

### 【手順2】Environmentの作成（手動承認用）

Terraform Applyの実行前に手動承認を求める仕組みを設定します。

#### 2-1. Environmentsページへアクセス

1. GitHubリポジトリのページを開く
2. 画面上部の **Settings** タブをクリック
3. 左サイドバーの **Environments** をクリック
4. **New environment** ボタンをクリック

#### 2-2. Environment作成

1. **Name** に `production` と入力
2. **Configure environment** ボタンをクリック

#### 2-3. 承認者の設定

1. **Required reviewers** にチェックを入れる
2. **Add reviewers** をクリックし、自分のGitHubユーザー名を追加
3. （オプション）**Wait timer** は `0` のまま（即座に承認可能）
4. **Save protection rules** ボタンをクリック

---

## ✅ 設定完了の確認

### 確認項目

- [ ] Personal Access Token を作成・保存済み
- [ ] AWS_ACCESS_KEY_ID がSecretsに登録されている
- [ ] AWS_SECRET_ACCESS_KEY がSecretsに登録されている
- [ ] AWS_REGION がSecretsに登録されている
- [ ] `production` Environmentが作成されている
- [ ] Required reviewersが設定されている

---

## 🧪 動作確認方法（詳細手順）

設定完了後、実際にCI/CDパイプラインが動作するか確認します。

### **フェーズ1: テストブランチの作成とプッシュ**

#### ステップ1-1: Git設定（初回のみ）

```bash
# Gitユーザー設定
git config --global user.email "your-email@example.com"
git config --global user.name "Your Name"
```

#### ステップ1-2: テストブランチ作成

```bash
# リポジトリディレクトリへ移動
cd /path/to/your/repository

# テストブランチ作成
git checkout -b test/cicd-verification
```

#### ステップ1-3: テスト用の変更

Terraformファイルに軽微な変更を加えます：

```bash
# variables.tfにコメント追加
echo "# CI/CD test" >> Terraform/aws/variables.tf

# ステージング
git add Terraform/aws/variables.tf

# コミット
git commit -m "test: CI/CD verification"
```

#### ステップ1-4: プッシュ

```bash
# プッシュ
git push origin test/cicd-verification

# Username: <YOUR_GITHUB_USERNAME>
# Password: ghp_xxxxxxxxxxxx（Personal Access Token）
```

**⚠️ 注意:**
- パスワード欄にはPersonal Access Tokenを入力
- GitHubのログインパスワードでは認証エラーになります

---

### **フェーズ2: Pull Request作成とPlanワークフロー確認**

#### ステップ2-1: PR作成

1. ブラウザでGitHubリポジトリを開く
2. 画面上部に表示される **Compare & pull request** ボタンをクリック
3. PR作成画面で以下を確認：
   - Base: `main`
   - Compare: `test/cicd-verification`
4. **Create pull request** ボタンをクリック

#### ステップ2-2: GitHub Actions実行確認

PR作成から**2-3分後**に以下が自動実行されます。

**確認場所①: Checksタブ**

1. PRページの **Checks** タブをクリック
2. 「Terraform Plan」ワークフローが表示される
3. 各ステップの実行状況を確認：
   - 🟡 黄色の丸: 実行中
   - ✅ 緑のチェック: 成功
   - ❌ 赤いバツ: 失敗

**実行されるステップ:**
```
✅ Terraform Format Check
✅ Terraform Init
✅ Terraform Validate
✅ Run tfsec (セキュリティスキャン)
✅ Terraform Plan
✅ Comment PR
```

**確認場所②: Conversationタブ**

1. PRページの **Conversation** タブをクリック
2. ボットからのコメントが自動投稿される：

```markdown
#### Terraform Format and Style 🖌 success
#### Terraform Initialization ⚙️ success
#### Terraform Validation 🤖 success
#### tfsec Security Check 🔒 success
#### Terraform Plan 📖 success

<details><summary>Show Plan</summary>

```terraform
[Terraform Planの詳細結果]
```

</details>
```

#### ステップ2-3: チェックポイント

以下をすべて確認してください：

- [ ] Checksタブで「Terraform Plan」が緑色（成功）
- [ ] すべてのステップが緑色のチェックマーク
- [ ] Conversationタブにplan結果のコメントが投稿されている
- [ ] Plan結果の詳細が「Show Plan」で展開できる

**⚠️ エラーが出た場合:**
- Checksタブで失敗したステップをクリック
- ログを確認してエラー内容を特定
- トラブルシューティングセクションを参照

---

### **フェーズ3: PRマージとApplyワークフロー確認**

#### ステップ3-1: PRマージ

すべてのチェックが成功したら：

1. PRページに戻る
2. **Merge pull request** ボタンをクリック
3. **Confirm merge** をクリック

#### ステップ3-2: Applyワークフロー起動確認

マージ後、自動的に `Terraform Apply` ワークフローが起動します。

**確認手順:**

1. リポジトリのトップページに移動
2. **Actions** タブをクリック
3. 「Terraform Apply」ワークフローが表示される
4. ワークフロー名をクリックして詳細を開く

#### ステップ3-3: 手動承認画面

ワークフローは**手動承認待ち**の状態で停止します。

**画面表示:**
```
🟡 Waiting for approval
Review deployments
This workflow is waiting for approval to deploy to production
```

**承認ボタンが表示される:**
- **Review deployments** ボタン

#### ステップ3-4: 手動承認の実施

⚠️ **重要:** テスト目的の場合、以下のどちらかを選択：

**オプションA: 承認してApply実行**
1. **Review deployments** ボタンをクリック
2. `production` にチェックを入れる
3. コメント欄に「Test approval」等を入力（オプション）
4. **Approve and deploy** ボタンをクリック
5. Terraform Applyが実行される

**オプションB: キャンセル（テスト用の場合推奨）**
1. 承認せずにワークフローを放置
2. または、ワークフローの右上の「・・・」から「Cancel workflow」

#### ステップ3-5: Apply実行結果確認（承認した場合）

承認後、以下のステップが実行されます：

```
✅ Terraform Init
✅ Terraform Format Check
✅ Terraform Validate
✅ Run tfsec
✅ Terraform Plan
✅ Terraform Apply
```

**実行結果の確認:**
1. Actionsタブでワークフローの詳細を開く
2. 各ステップの実行ログを確認
3. 成功時: 緑色のチェックマークが表示
4. 失敗時: 自動的にGitHub Issueが作成される

---

### **フェーズ4: クリーンアップ**

テスト完了後、テストブランチを削除します：

```bash
# mainブランチに戻る
git checkout main

# 最新を取得
git pull origin main

# テストコメントを削除
git restore Terraform/aws/variables.tf

# ローカルブランチ削除
git branch -d test/cicd-verification

# リモートブランチ削除
git push origin --delete test/cicd-verification
```

---

## 🔄 日常的な開発フロー

設定完了後の通常の開発フローは以下の通りです：

### 1️⃣ 機能開発・修正

```bash
# フィーチャーブランチ作成
git checkout -b feature/new-lambda-function

# Terraformファイルを修正
vim Terraform/aws/lambda/main.tf

# コミット
git add Terraform/aws/lambda/main.tf
git commit -m "feat: Add new Lambda function for data processing"

# プッシュ
git push origin feature/new-lambda-function
```

### 2️⃣ PR作成・レビュー

1. GitHubでPR作成
2. **自動実行:** Terraform Plan
3. PRコメントでplan結果を確認
4. コードレビュー実施
5. 必要に応じて修正

### 3️⃣ マージ・デプロイ

1. PRをmainにマージ
2. **自動起動:** Terraform Applyワークフロー
3. **手動承認:** Review deploymentsボタンをクリック
4. **自動実行:** Terraform Apply
5. AWSリソースが更新される

---

## 🚨 トラブルシューティング

### エラー: "Authentication failed"（Git push時）

**原因:** Personal Access Tokenが正しくない、または期限切れ

**解決方法:**
1. Personal Access Tokenを再確認
2. 有効期限を確認（Settingsで確認可能）
3. 期限切れの場合は新しいトークンを作成

---

### エラー: "AWS credentials not found"

**原因:** GitHub Secretsが正しく登録されていない

**解決方法:**
1. Settings > Secrets and variables > Actions を確認
2. 3つのSecretが登録されているか確認
3. Secret名のスペルミスがないか確認（大文字・小文字を区別）

---

### エラー: "Environment not found"

**原因:** `production` Environmentが作成されていない

**解決方法:**
1. Settings > Environments を確認
2. `production` という名前のEnvironmentを作成
3. Required reviewersを設定

---

### エラー: "S3 bucket does not exist"

**原因:** TerraformのStateバケットが存在しない

**解決方法:**
1. AWSコンソールでS3バケットを確認
2. `poc-mc-vision-terraform-state-aws` バケットを作成
3. DynamoDBテーブル `poc-mc-vision-terraform-locks` も作成

---

### エラー: "tfsec security check failed"

**原因:** セキュリティ問題が検出された

**解決方法:**
1. Checksタブでtfsecのログを確認
2. 検出された問題を修正
3. PoC環境で許容可能な場合は `.tfsec.yml` で除外設定

---

### Plan/Applyが実行されない

**原因:** Terraformファイルに変更がない、またはパス設定が誤っている

**解決方法:**
1. `Terraform/` ディレクトリ配下のファイルを変更
2. `.github/workflows/` ファイル自体を変更してもトリガーされる
3. README等の変更では実行されない（pathsフィルター設定済み）

---

### ワークフローが途中で止まる

**原因:** 手動承認待ちの状態

**解決方法:**
- これは正常動作です
- **Review deployments** ボタンで承認してください
- 承認しない限りApplyは実行されません

---

## 📚 参考情報

### ワークフローの構成

#### **terraform-plan.yml**: PR作成時に自動実行
- トリガー: `pull_request` to `main`
- 実行内容:
  - フォーマットチェック
  - 構文検証
  - セキュリティスキャン（tfsec）
  - 実行計画の生成
  - PRにplan結果を自動コメント

#### **terraform-apply.yml**: mainブランチへのマージ時に実行
- トリガー: `push` to `main`
- 実行内容:
  - 手動承認待ち（Environment保護）
  - フォーマット・検証・セキュリティチェック
  - インフラのデプロイ
  - 失敗時にIssue自動作成

---

### セキュリティベストプラクティス

#### ✅ 実施済み
- GitHub Secretsで認証情報を暗号化保存
- 手動承認制によるデプロイ制御
- tfsecによるセキュリティスキャン
- 最小権限の原則（必要な権限のみ付与）

#### 🔒 推奨事項
- Personal Access Tokenは定期的にローテーション
- IAMユーザーのAccess Keyも定期的にローテーション
- 本番環境では複数人の承認を必須化
- AWS CloudTrailでAPI実行履歴を監視

---

## 📞 サポート

### 問題が解決しない場合

以下を確認してください：

1. **GitHub Actionsの実行ログ**
   - Actionsタブ → ワークフローをクリック → 各ステップのログを確認

2. **AWSのIAM権限設定**
   - 作成したIAMユーザーの権限を確認
   - 必要な権限: S3, DynamoDB, Lambda, SageMaker, IAM, CloudWatch

3. **S3バックエンドの存在確認**
   - バケット: `poc-mc-vision-terraform-state-aws`
   - DynamoDBテーブル: `poc-mc-vision-terraform-locks`

4. **GitHub設定の再確認**
   - Secrets: 3つすべて登録済みか
   - Environment: `production` が存在するか
   - Required reviewers: 設定済みか

---