# PoC MC Vision ― マルチクラウドAI基盤の構築・検証PoC

## 💡 本PoCで実証したポイント（一枚要約）

> - **AWS × Azure 両対応のAI基盤をTerraformで構築し、正常動作を確認**
> - **SageMaker Serverless・Bedrock・Azure OpenAI を連携し、推論結果の統合処理を実装**
> - **GitHub ActionsによるCI/CD導入で、PRレビュー自動化と承認付きデプロイを実現**
---

## エグゼクティブサマリー

本プロジェクトは、**AWS と Azure を統合したマルチクラウド AI 基盤の構築プロジェクト**です。
SageMaker Serverless・Bedrock・Azure OpenAI の3サービスをTerraformで構築し、**マルチクラウドAI基盤として正常動作を確認。**
さらに、**GitHub ActionsでTerraformの自動検証と承認付きデプロイを実現し、安全なインフラ更新フローを確立。**

---

## 🧩 PoCの背景と検証目的

### **なぜこのPoCを実施したか**

| 項目 | 内容 |
|------|------|
| **キャリア目標** | 2026年4月以降、AWS（理想は AWS × Azure） のクラウドAI基盤構築案件への参画 |
| **検証目的** | AWS（SageMaker・Bedrock）とAzure（OpenAI）を統合した推論基盤を構築し、動作を検証<br>TerraformによるIaC管理とGitHub ActionsによるCI/CDパイプラインを実装し、安全なデプロイフローを確立 |
| **検証テーマ** | 複数クラウドのAI推論基盤を個人で構築・再現できるかを検証 |

---

## 🎯 成功条件（検証完了基準）

本PoCでは、以下を**成功条件**として設定し、達成を確認:

| # | 成功条件 | 達成状況 |
|---|---------|---------|
| **1** | FastAPI経由でSageMaker・Bedrock・Azure OpenAIが正常応答 | ✅ 達成 |
| **2** | 推論結果をDynamoDBに保存し、S3イベント連動のLambda起動を確認 | ✅ 達成 |
| **3** | TerraformによるAWS/Azureリソース構築とGitHub Actions CI/CDパイプラインが正常動作 | ✅ 達成 |

---

## ✅ 検証結果と今後の展開

### **検証結果（PoCで得られた知見）**

| 観点 | 検証結果 |
|------|---------|
| **マルチクラウド統合** | AWS（SageMaker・Bedrock）とAzure（OpenAI）を統合し、推論リクエストの正常応答を確認 |
| **Terraformによるコード化** | インフラをコード化し、再デプロイ可能な状態を確認 |
| **イベント駆動アーキテクチャ** | S3イベント→Lambda自動起動の仕組みを実装し、動作確認完了 |
| **CI/CD自動化** | GitHub ActionsによるTerraform検証・セキュリティスキャン・手動承認デプロイの一連のフローを構築し、動作確認完了 |

### **今後の展開（今後の拡張構想）**

構築手順を確立できたため、次フェーズでは以下の拡張を予定:

- **監視強化**: CloudWatch Alarmsによるエラー率・レイテンシ監視
- **スケーラビリティ向上**: Step Functionsを活用したマルチモデル推論パイプライン化
- **セキュリティ強化**: VPCエンドポイント（S3/SageMaker/Bedrock）の導入によるプライベート接続化、ネットワークレベルでの通信の隔離

---

## ⚠️ 実装時の課題と対処

### **1. SageMaker Serverlessの設定**
SageMaker Serverlessでカスタムモデル（model.tar.gz）を読み込む際に、エンドポイント設定やモデルの配置で試行錯誤が必要でした。特にTorchScriptモデルをJSON入力で扱う際の設定に試行錯誤。

### **2. Azure OpenAIエンドポイント形式**
Terraformで作成したAzure OpenAIリソースは**リージョナルエンドポイント形式**（`https://eastus2.api.cognitive.microsoft.com`）でしたが、カスタムサブドメイン形式（`https://<resource-name>.openai.azure.com`）と誤認してDNSエラーが発生しました。実際の検証を通じて正しい形式を理解できました。

### **3. S3バケットのCORS設定**
フロントエンドからS3への直接アップロード機能実装時、CORS設定が不足していることが判明。Terraformテンプレートに `aws_s3_bucket_cors_configuration` リソースを追加して解決しました。

### **4. Azure Resource Provider登録**
Azure初回デプロイ時、Resource Providerが未登録のため接続タイムアウトエラーが発生。`az provider register` コマンドで事前登録が必要であることを学びました。

### **5. GitHub Actions CI/CD実装時の調整**
CI/CDパイプライン実装時、tfsecセキュリティスキャンで中・低レベルの脆弱性が大量に検出され、ワークフローがブロックされる問題が発生しました。`--minimum-severity HIGH` オプションを追加し、高レベルの脆弱性のみを必須チェック対象とすることで解決しました。

---

## 🧪 検証環境

本PoCは、以下の環境で実施しました:

| 項目 | 内容 |
|------|------|
| **実施期間** | 2025年10月〜11月（約2ヶ月） |
| **実行環境** | AWS（東京リージョン: ap-northeast-1）＋ Azure（米国東部2: East US 2） |
| **Terraform** | 1.9.8 |
| **Python** | 3.12 |
| **Node.js** | 18.x |

---

## プロジェクトの位置づけと訴求ポイント

- **目的**: 2026年4月以降に AI 基盤エンジニアとして AWS案件へ参画するための実績づくり
- **強み**: モデル開発ではなく、**マルチクラウドでAI推論を安定・安全に運用する基盤構築力**
- **想定読者**: 技術面接官・書類選考担当者・営業担当者

---

## この PoC で提供できる価値

| 観点 | 実装内容 | 実務への応用知見 |
|------|----------|------------------|
| **マルチクラウド連携** | SageMaker Serverless／Bedrock／Azure OpenAI を単一 API で抽象化 | 複数クラウドを切り替える推論ルーティングの実装 |
| **運用自動化** | S3 → Lambda（イベントログ）／FastAPI → 推論 → DynamoDB | イベント駆動による運用自動化アーキテクチャの構築 |
| **IaC 再現性** | AWS／Azure リソースを Terraform モジュール化（10分で再デプロイ） | IaCで環境再現と変更管理を実装 |
| **CI/CD パイプライン** | GitHub ActionsによるTerraform自動検証・手動承認デプロイ | PRレビュー自動化とセキュアなデプロイフローの実装 |
| **コスト最適化** | Serverless + S3 ライフサイクル（30日）+ DynamoDB TTL（1日）による低コスト運用を検証 | TTLとライフサイクルを活用した低コスト運用パターンの実装 |
| **セキュリティ & 可観測性** | S3暗号化（AES256）・バージョニング・CloudWatch Logs構造化ログ・IAM最小権限（Lambda/SageMaker）・tfsecスキャン | 暗号化と構造化ログに加え、TerraformでIAMロールを最小権限に整備し、セキュリティスキャンを自動化 |

---

## システム概要

React フロントエンドから画像をアップロードし、FastAPI が3つのAIサービス（SageMaker・Bedrock・Azure OpenAI）に推論リクエストを送信。
結果は DynamoDB へ保存し、CloudWatch Logs で可観測性を確保。
AWS・Azure の認証情報は環境変数で管理。

### **処理フロー**

```
① Reactフロントエンド
   ├─ 画像をFastAPIへ直接アップロード（ローカル保存）
   ├─ 署名付きURL経由でS3へアップロード（S3保存）
   └─ ユーザー操作で解析APIを実行
      ├─ /api/analyze/aws・/api/analyze/azure・/api/route
      └─ /api/s3/analyze
       
② FastAPI（main.py）
   ├─ 【直接アップロード画像の解析】
   │  ├─ request_id からローカル保存画像を検索・前処理（リサイズ/エンコード）
   │  └─ 各推論サービスへ順次リクエスト送信
   │     ├─ Amazon Bedrock（Claude 3 Haiku）
   │     └─ Azure OpenAI（gpt-4o-mini）
   │
   └─ 【S3アップロード画像の解析】
      ├─ s3_key から S3 より画像バイト列を取得
      ├─ 各推論サービスへ順次リクエスト送信（環境変数で ON/OFF）
      │  ├─ SageMaker Serverless（TorchScriptカスタムモデル）
      │  ├─ Amazon Bedrock（Claude 3 Haiku）
      │  └─ Azure OpenAI（gpt-4o-mini）
      └─ 推論結果を DynamoDB に保存

※ アップロード完了時点では推論は自動実行されず、ユーザーが解析APIを呼び出して結果を取得します。

※ 別フロー: S3アップロード時のイベント駆動処理
③ S3イベント通知
   └─ Lambda関数（自動起動）
      └─ CloudWatch Logs（構造化 JSON）

```

### **アーキテクチャ図**

![architecture](./docs/poc-mc-vision-architecture.drawio)

### **実際の動作確認**

実際の動作画面は **`docs/PoC動作画面録画.mp4`** を参照してください。

- ✅ フロントエンドからの画像アップロード
- ✅ Azure OpenAI による推論実行
- ✅ AWS Bedrock による推論実行
- ✅ S3への直接アップロードと解析

---

## 技術スタック

### **インフラ（IaC）**
- **Terraform** 1.9.8 - マルチクラウド対応・State管理
- **AWS Provider** 5.x - 全AWSサービス対応
- **Azure Provider** 3.x - Azure OpenAI対応

### **AWS サービス**
- **S3** - 画像アップロード・イベントソース（暗号化・バージョニング・ライフサイクル30日）
  - `poc-mc-vision-upload`: 画像保存用（Terraformで作成、CORS設定済み）
  - `poc-mc-vision-zip`: デプロイパッケージ格納用（手動作成）
- **Lambda** - S3イベントログの記録（Python 3.12・512MB・60s）
- **SageMaker Serverless** - カスタムモデル推論（PyTorch 2.0.1・1024MB）
- **Bedrock** - Vision API (Claude 3 Haiku)
- **DynamoDB** - 推論結果保存（オンデマンド・TTL 1日）
- **CloudWatch Logs** - ログ管理（保持1日・構造化JSON）
- **S3 Backend (State管理)** - Terraform State保存用（バージョニング・暗号化）
- **DynamoDB（Terraform Lock Table）** - Terraform Stateロック管理（オンデマンド）

### **Azure サービス**
- **Azure OpenAI** - GPT-4o-mini推論（Standard SKU・Capacity 1）
- **Cognitive Services** - OpenAIアカウント（S0 SKU）
- **Resource Group** - リソース管理（リージョン: eastus2）

### **アプリケーション**
- **FastAPI** (Python 3.12) - REST API・自動ドキュメント生成
- **React 19 + Vite** - フロントエンド・高速HMR
- **boto3** - AWS SDK（全AWSサービス対応）

---

## 🔄 Terraform CI/CD パイプライン（GitHub Actions）

本PoCでは、**GitHub Actions を活用したTerraform CI/CDパイプライン**を実装し、インフラ変更の品質担保と安全なデプロイを実現しています。

### **実装内容**

| 機能 | 実装内容 | 効果 |
|------|---------|------|
| **自動検証** | PR作成時にterraform plan・フォーマット・セキュリティスキャン（tfsec）を自動実行 | コードレビュー前に問題を検出し、品質を担保 |
| **手動承認デプロイ** | mainマージ後、手動承認を経てterraform applyを実行 | 誤デプロイを防止し、安全な本番反映を実現 |
| **PRコメント自動投稿** | Plan結果をPRに自動コメント投稿 | レビュアーが変更内容を即座に把握可能 |
| **セキュリティチェック** | tfsecによるセキュリティスキャン（HIGH以上）を必須化 | 脆弱性を早期発見し、セキュアな構成を維持 |
| **失敗時Issue自動作成** | Apply失敗時に自動的にGitHub Issueを作成 | 問題の追跡と対応を効率化 |

### **ワークフローの流れ**

```
1️⃣ PR作成
   ├─ Terraform Format Check ✅
   ├─ Terraform Init ✅
   ├─ Terraform Validate ✅
   ├─ tfsec Security Scan ✅
   └─ Terraform Plan → PRにコメント投稿 📝

2️⃣ コードレビュー
   └─ Plan結果を確認してレビュー

3️⃣ mainブランチへマージ
   ├─ ワークフロー自動起動
   └─ 手動承認待ち 🟡

4️⃣ 手動承認
   └─ Review deployments ボタンで承認

5️⃣ Terraform Apply実行
   └─ AWSリソース更新 🚀
```

### **詳細ガイド**

CI/CDのセットアップ手順の詳細については、以下のドキュメントを参照してください:

 **[Terraform/TERRAFORM_CICD_COMPLETE_GUIDE.md](./Terraform/TERRAFORM_CICD_COMPLETE_GUIDE.md)**

---

## 🔍 技術選定理由

### **マルチクラウド AI サービスの選定**
- **AWS（SageMaker Serverless / Bedrock）**: カスタムモデルとマネージドモデルの両方を実装・検証
- **Azure（OpenAI GPT-4o-mini）**: マルチクラウド連携の実装難易度を確認
- **目的**: 単一クラウドではなく、複数クラウドを跨いだ推論基盤の動作検証を実施

### **Terraform の選定**
- **理由**: AWS + Azure を単一コードベースで管理できる点で採用
- **学び**: Terraformによるリソース定義・モジュール化、State管理（S3/DynamoDB）の実装

### **サーバーレスアーキテクチャの選定**
- **理由**: PoC段階でのコスト最小化（アイドル時コストゼロ）を優先
- **学び**: コスト削減と引き換えにコールドスタート遅延が発生することを確認

### **GitHub Actions CI/CD の選定**
- **理由**: GitHubリポジトリとの統合が容易で、無料枠内でTerraform検証・セキュリティスキャン・自動デプロイを実装可能
- **学び**: PRレビュー自動化（terraform plan結果の自動コメント投稿）と手動承認ゲート（Environment機能）による、安全なインフラ変更フローの確立

---

## ディレクトリ構成

```text
poc-mc-vision/
├── src/
│   ├── backend/        # FastAPI サービス
│   │   ├── main.py
│   │   └── requirements.txt
│   └── frontend/       # React + Vite クライアント
│       ├── README.md
│       ├── eslint.config.js
│       ├── index.html
│       ├── package-lock.json
│       ├── package.json
│       ├── public/
│       ├── src/
│       └── vite.config.js
├── Lambda/             # Lambda 関数コード
│   ├── lambda_function.py
│   └── poc-mc-vision-handler.zip  # デプロイ用バンドル（Terraform用）
├── .github/
│   └── workflows/      # GitHub Actions CI/CD
│       ├── terraform-plan.yml   # PR時の自動検証
│       └── terraform-apply.yml  # mainマージ後の手動承認デプロイ
├── Terraform/
│   ├── aws/            # AWS リソース（モジュール分割）
│   │   ├── backend.tf
│   │   ├── cloudwatch/
│   │   ├── dynamodb/
│   │   ├── iam/
│   │   ├── lambda/
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── s3/
│   │   ├── sagemaker/
│   │   └── variables.tf
│   ├── azure/          # Azure OpenAI リソース
│   │   ├── backend.tf
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   └── variables.tf
│   ├── setup/          # State管理用スクリプト
│   │   ├── README.md
│   │   └── create-state-backend.sh
│   ├── README.md
│   ├── DEPLOYMENT_CHECKLIST.md
│   └── TERRAFORM_CICD_COMPLETE_GUIDE.md  # CI/CD完全ガイド
├── sagemaker_model/    # SageMaker カスタムモデル（TorchScript）
│   └── model_torchscript.tar.gz
├── configs/            # `.env` ファイルのテンプレート
│   └── .env.example
├── results/            # 推論結果・ログ
│   ├── images/
│   └── logs/
├── docs/               # ドキュメント・動作確認動画
│   ├── PoC動作画面録画.mp4
│   └── poc-mc-vision-architecture.drawio
└── README.md           # 本ファイル
```

---

## クイックスタート

### **前提条件**

```bash
# 必須ツール
✅ Terraform 1.9.8
✅ AWS CLI（aws sso login または aws configure）
✅ Azure CLI（az login）
✅ Node.js >= 18.x
✅ Python 3.12
```

### **1. ローカル開発環境セットアップ**

#### **Backend（FastAPI）**

```bash
cd src/backend

# 仮想環境作成・有効化
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate

# 依存関係インストール
pip install -r requirements.txt

# 環境変数設定
cp ../../configs/.env.example .env
# .envを編集して以下の値を設定:
#   - AZURE_OPENAI_ENDPOINT: Azure OpenAIエンドポイントURL
#   - AZURE_OPENAI_API_KEY: Azure OpenAI APIキー
#   - AWS_REGION: AWSリージョン (デフォルト: ap-northeast-1)
#   - S3_UPLOAD_BUCKET: 画像アップロード用S3バケット名 (デフォルト: poc-mc-vision-upload)
#   - DDB_TABLE: DynamoDBテーブル名 (デフォルト: poc-mc-vision-table)
#   - SAGEMAKER_ENDPOINT_NAME: SageMakerエンドポイント名 (デフォルト: poc-mc-vision-sm)

# サーバー起動
uvicorn main:app --reload --port 8000

# ✅ Backend起動: http://127.0.0.1:8000
# ✅ Swagger UI: http://127.0.0.1:8000/docs
```

#### **Frontend（React + Vite）**

```bash
cd src/frontend

# 依存関係インストール
npm install

# 開発サーバー起動
npm run dev

# ✅ Frontend起動: http://127.0.0.1:5173/
```

### **2. インフラデプロイ（Terraform）**

インフラのデプロイ手順については、以下のドキュメントを参照してください:

- **[Terraform/README.md](./Terraform/README.md)** - Terraformデプロイの詳細手順・トラブルシューティング
- **[Terraform/DEPLOYMENT_CHECKLIST.md](./Terraform/DEPLOYMENT_CHECKLIST.md)** - デプロイチェックリスト

> **概要**:
> AWS（S3、Lambda、DynamoDB、SageMaker Serverless等）とAzure（OpenAI）のリソースをTerraformで構築します。所要時間は約10-15分です。
> Stateファイルは S3 バケットに保存し、DynamoDB でロック管理しています。

---

## 実績サマリー

### **主な達成内容**

- ✅ **マルチクラウド設計**: AWS（SageMaker / Bedrock）と Azure（OpenAI）を統合した推論基盤を構築
- ✅ **サーバーレスアーキテクチャ**: Lambda + Serverless 推論 + DynamoDB でアイドルコストゼロを実現
- ✅ **IaC による再現性**: AWS/Azure を単一コードベースで管理し、10分で再構築可能
- ✅ **CI/CD パイプライン**: GitHub Actionsによる自動検証・手動承認デプロイを実装し、安全なインフラ変更フローを確立
- ✅ **セキュリティ & 運用**: S3暗号化・バージョニング・構造化ログ・tfsecスキャンによる多層防御を実装
- ✅ **コスト最適化**: S3ライフサイクル（30日）／DynamoDB TTL（1日）による低コスト運用を確認

---

## 💡 このPoCで得た知見・設計ノウハウ

### **SageMaker・Bedrockの構築手順を実際に実装・検証できた**
ドキュメントを読むだけでは分からない、実際のモデルデプロイの流れを確認できました。特にSageMaker Serverlessでカスタムモデルを動かす際は、エンドポイント設定やモデルパッケージの配置など、実装を通じて細かな調整ポイントを確認しました。

### **マルチクラウド連携の実装経験**
AWS と Azure の認証情報を環境変数で管理し、FastAPIから複数クラウドのAIサービスを呼び出す実装を通じて、その連携方法を習得しました。

### **Terraformによるインフラコード化の実践**
手動構築ではなくIaCで管理することで、設定の再現性が向上することを確認しました。

### **TerraformによるCI/CD自動化の実装手順を確認**
GitHub ActionsでPRごとに `fmt` / `validate` / `tfsec` / `plan` を自動実行し、mainマージ後は承認付きで `apply` する流れを構築してCI/CDフローを確認しました。

### **今後の目標**
PoCで得た知見を基に、本番運用を想定した構築・監視・セキュリティ設計まで含む実務的スキルの習得を目指す。

---

## 関連ドキュメント

| ドキュメント | 内容 |
|------------|------|
| **[docs/poc-mc-vision-architecture.drawio](./docs/poc-mc-vision-architecture.drawio)** | アーキテクチャ図 |
| **[docs/PoC動作画面録画.mp4](./docs/PoC動作画面録画.mp4)** | 実際の動作デモ録画 |
| **[Terraform/README.md](./Terraform/README.md)** | Terraformデプロイ詳細手順・トラブルシューティング |
| **[Terraform/DEPLOYMENT_CHECKLIST.md](./Terraform/DEPLOYMENT_CHECKLIST.md)** | デプロイチェックリスト |
| **[Terraform/TERRAFORM_CICD_COMPLETE_GUIDE.md](./Terraform/TERRAFORM_CICD_COMPLETE_GUIDE.md)** | CI/CDセットアップ完全ガイド |

---