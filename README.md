# PoC MC Vision ― マルチクラウドAI基盤の構築・検証PoC

## 💡 本PoCで実証したポイント（一枚要約）

> - **AWS × Azure 両対応のAI基盤をTerraformにて10分で構築し、動作確認完了**
> - **SageMaker Serverless・Bedrock・Azure OpenAI の3つのAIサービスを統合**
> - **個人で構築し、マルチクラウドAI基盤の実装フローを確認**
---

## エグゼクティブサマリー

本プロジェクトは、**AWS と Azure を統合したマルチクラウド AI 基盤の構築プロジェクト**です。
SageMaker Serverless・Bedrock・Azure OpenAI の3つのAIサービスをTerraformで構築し、
実際に動作させ、**マルチクラウドAI基盤の構築から動作検証までの一連のプロセスを通して、実装・再現**を行いました。

---

## 🧩 PoCの背景と検証目的

### **なぜこのPoCを実施したか**

| 項目 | 内容 |
|------|------|
| **キャリア目標** | 2026年4月以降、AWS（理想は AWS × Azure） のクラウドAI基盤構築案件への参画 |
| **検証目的** | AWS（SageMaker・Bedrock）とAzure（OpenAI）の実際の構築手順を把握し、実装を通じて理解を深める |
| **検証テーマ** | 複数クラウドのAIサービスを統合した推論基盤を個人で構築できるか |

---

## 🎯 成功条件（検証完了基準）

本PoCでは、以下を**成功条件**として設定し、達成を確認:

| # | 成功条件 | 達成状況 |
|---|---------|---------|
| **1** | FastAPI → SageMaker/Bedrock/Azure OpenAI の3つのAIサービスが正常動作 | ✅ 達成 |
| **2** | 推論結果をDynamoDBに保存し、S3イベント連動のLambda起動を確認 | ✅ 達成 |

---

## ✅ 検証結果と今後の展開

### **検証結果（PoCで得られた知見）**

| 観点 | 検証結果 |
|------|---------|
| **マルチクラウド統合** | AWS（SageMaker・Bedrock）とAzure（OpenAI）の3つのAIサービスを統合し、正常動作を確認 |
| **Terraformによるコード化** | インフラをコード化し、再デプロイ可能な状態を確認 |
| **イベント駆動アーキテクチャ** | S3イベント→Lambda自動起動の仕組みを実装し、動作確認完了 |

### **今後の展開（今後の拡張構想）**

本PoCでマルチクラウドAI基盤の構築手順を確認できたため、今後は以下の拡張を検討しています:

- **CI/CD統合**: GitHub Actionsによる自動デプロイ化
- **監視強化**: CloudWatch Alarmsによるエラー率・レイテンシ監視
- **スケーラビリティ向上**: Step Functionsを活用したマルチモデル推論パイプライン化

---

## ⚠️ 実装時の課題と対処

### **1. SageMaker Serverlessの設定**
SageMaker Serverlessでカスタムモデル（model.tar.gz）を読み込む際に、エンドポイント設定やモデルの配置で試行錯誤が必要でした。特にTorchScriptのモデルをJSON入力で受け取る設定に苦労しました。

### **2. Azure OpenAIエンドポイント形式**
Terraformで作成したAzure OpenAIリソースは**リージョナルエンドポイント形式**（`https://eastus2.api.cognitive.microsoft.com`）でしたが、カスタムサブドメイン形式（`https://<resource-name>.openai.azure.com`）と誤認してDNSエラーが発生しました。実際の検証を通じて正しい形式を理解できました。

### **3. S3バケットのCORS設定**
フロントエンドからS3への直接アップロード機能実装時、CORS設定が不足していることが判明。Terraformテンプレートに `aws_s3_bucket_cors_configuration` リソースを追加して解決しました。

### **4. Azure Resource Provider登録**
Azure初回デプロイ時、Resource Providerが未登録のため接続タイムアウトエラーが発生。`az provider register` コマンドで事前登録が必要であることを学びました。

### **5. S3バケット削除時のバージョニング対応**
`terraform destroy` 実行時、バージョニング有効なS3バケットが削除できず失敗。すべてのオブジェクトバージョンと削除マーカーを事前削除する必要があることを理解しました。

---

## 🧪 検証環境

本PoCは、以下の環境で実施しました:

| 項目 | 内容 |
|------|------|
| **実施期間** | 2025年9月〜10月（約2ヶ月） |
| **実行環境** | AWS（東京リージョン: ap-northeast-1）＋ Azure（米国東部2: East US 2） |
| **Terraform** | 1.9.8 |
| **Python** | 3.12 |
| **Node.js** | 18.x |

---

## プロジェクトの位置づけと訴求ポイント

- **目的**: 2026年4月以降に AI 基盤エンジニアとして AWS案件へ参画するための実績づくり
- **強み**: AIモデル開発そのものではなく、**マルチクラウドで推論を安全・効率的に運用する基盤構築力**
- **想定読者**: 技術面接官・書類選考担当者・営業担当者

---

## この PoC で提供できる価値

| 観点 | 実装内容 | 得られた知見・設計上の学び |
|------|----------|------------------|
| **マルチクラウド連携** | SageMaker Serverless／Bedrock／Azure OpenAI を単一 API で抽象化 | 複数クラウドを切り替える推論ルーティングの実装 |
| **運用自動化** | S3 → Lambda（イベントログ）／FastAPI → 推論 → DynamoDB | イベント駆動による運用自動化アーキテクチャの構築 |
| **IaC 再現性** | AWS／Azure リソースを Terraform モジュール化（10分で再デプロイ） | IaCで環境再現と変更管理を実装 |
| **コスト最適化** | Serverless + S3 ライフサイクル（30日）+ DynamoDB TTL（1日）による低コスト運用を検証 | TTLとライフサイクルを活用した低コスト運用パターンの実装 |
| **セキュリティ & 可観測性** | S3暗号化（AES256）・バージョニング・CloudWatch Logs構造化ログ・IAM最小権限（Lambda/SageMaker） | 暗号化と構造化ログに加え、TerraformでIAMロールを最小権限に整備 |

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

## 🔍 技術選定理由

本PoCは、特定の技術に依存せず**複数クラウドのAI基盤構成を実装を通じて理解を深める**ために選定しました:

### **マルチクラウド AI サービスの選定**
- **AWS（SageMaker Serverless / Bedrock）**: カスタムモデルとマネージドモデルの両方を実際に触っての構築方法の把握
- **Azure（OpenAI GPT-4o-mini）**: マルチクラウド連携の実装難易度感の確認
- **目的**: 単一クラウドではなく、複数クラウドを跨いだ推論基盤の動作検証を実施

### **Terraform の選定**
- **理由**: AWS + Azure を単一コードベースで管理できる点で採用
- **学び**: Terraformテンプレートの作成方法（リソース定義・モジュール化）や実行方法（init・plan・apply）の基本的なモジュール構成と実行手順を理解

### **サーバーレスアーキテクチャの選定**
- **理由**: PoC段階でのコスト最小化（アイドル時コストゼロ）を優先
- **学び**: コスト削減と引き換えにコールドスタート遅延が発生することを確認

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
│   └── DEPLOYMENT_CHECKLIST.md
├── sagemaker_model/    # SageMaker カスタムモデル（TorchScript）
│   └── model_torchscript.tar.gz
├── configs/            # `.env` 実ファイルとテンプレート
│   ├── .env
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
✅ Terraform >= 1.6.0
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
- ✅ **セキュリティ & 運用**: S3暗号化・バージョニング・構造化ログによる運用ベースラインの実装
- ✅ **コスト最適化**: S3ライフサイクル（30日）／DynamoDB TTL（1日）による低コスト運用を確認

---

## 💡 このPoCで得た学び・気づき

### **SageMaker・Bedrockの構築手順を実際に実装・検証できた**
ドキュメントを読むだけでは分からない、実際のエンドポイント設定やモデルデプロイの流れを確認できました。特にSageMaker Serverlessでカスタムモデルを動かす手順は、実際に手を動かさないと理解できなかった部分が多かったです。

### **マルチクラウド連携の実装経験**
AWS と Azure の認証情報を環境変数で管理し、FastAPIから複数クラウドのAIサービスを呼び出す実装を通じて、その連携方法を習得しました。

### **Terraformによるインフラコード化の実践**
手動構築ではなくIaCで管理することで、設定の再現性が向上することを確認しました。

### **今後の目標**
本PoCでAI基盤の基本的な構築手順は再現できたため、今後は実務案件でCI/CDや監視設計まで含めた実務的スキル習得を目指しています。

---

## 関連ドキュメント

| ドキュメント | 内容 |
|------------|------|
| **[docs/poc-mc-vision-architecture.drawio](./docs/poc-mc-vision-architecture.drawio)** | アーキテクチャ図 |
| **[docs/PoC動作画面録画.mp4](./docs/PoC動作画面録画.mp4)** | 実際の動作デモ録画 |
| **[Terraform/README.md](./Terraform/README.md)** | Terraformデプロイ詳細手順・トラブルシューティング |
| **[Terraform/DEPLOYMENT_CHECKLIST.md](./Terraform/DEPLOYMENT_CHECKLIST.md)** | デプロイチェックリスト |

---
