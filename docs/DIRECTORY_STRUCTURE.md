# プロジェクトディレクトリ構造

本ドキュメントでは、PoC MC Vision プロジェクトのディレクトリ構造とその役割を説明します。

## ルートディレクトリ

```
poc-mc-vision/
├── .github/                    # GitHub設定
├── configs/                    # 環境変数テンプレート
├── docs/                       # ドキュメント
├── Lambda/                     # Lambda関数
├── sagemaker_model/            # SageMaker用カスタムモデル
├── scripts/                    # 運用スクリプト
├── src/                        # アプリケーションソースコード
├── Terraform/                  # インフラ定義（IaC）
├── .gitattributes              # Git属性設定
├── .gitignore                  # Git除外設定
└── README.md                   # プロジェクト概要
```

---

## 詳細構造

### `.github/`
GitHub ActionsによるCI/CDパイプライン設定

```
.github/
└── workflows/                  # ワークフロー定義
```

**主な機能:**
- Terraform自動検証（fmt, validate, plan）
- セキュリティスキャン（tfsec）
- 手動承認付きデプロイ（terraform apply）
- PR へのplan結果自動コメント

### `configs/`
環境変数テンプレートやアプリケーション設定ファイル

**含まれるファイル:**
- `.env.example`: 環境変数のサンプル設定

### `docs/`
プロジェクトドキュメント

**含まれるファイル:**
- `DOCKER_ECR_DEPLOYMENT_GUIDE.md`: Docker・ECRデプロイメントガイド
- `DIRECTORY_STRUCTURE.md`: 本ドキュメント（ディレクトリ構造説明）
- `構成図スクリーンショット.png`: アーキテクチャ図
- `poc-mc-vision-architecture.drawio`: Draw.io形式のアーキテクチャ図

### `Lambda/`
Lambda関数のソースコード

**用途:**
- S3イベント処理
- ログ記録

### `sagemaker_model/`
SageMaker Serverlessで使用するカスタムモデル

**含まれるもの:**
- PyTorchモデル（ResNet18ベース）
- 推論スクリプト
- モデル設定ファイル

### `scripts/`
運用・管理用スクリプト

**含まれるスクリプト:**
- Bedrock Guardrails作成スクリプト

### `src/`
アプリケーションのソースコード

```
src/
├── backend/                    # FastAPI（Python 3.12）
└── frontend/                   # React 19 + Vite
    ├── public/                 # 静的ファイル
    ├── src/                    # フロントエンドソース
    │   └── assets/             # 画像・スタイルなどのアセット
    └── README.md               # フロントエンド説明
```

**Backend（FastAPI）:**
- AI推論APIエンドポイント
- AWS・Azure連携ロジック
- Lambda Container Imageとしてデプロイ

**Frontend（React + Vite）:**
- 画像アップロードUI
- 推論結果表示
- API呼び出し制御

### `Terraform/`
インフラストラクチャ定義（Infrastructure as Code）

```
Terraform/
├── aws/                        # AWSリソース定義
│   ├── cloudwatch/             # CloudWatch Alarms
│   ├── dynamodb/               # DynamoDB（推論結果保存）
│   ├── ecr/                    # ECR（コンテナリポジトリ）
│   ├── iam/                    # IAMロール・ポリシー
│   ├── lambda/                 # Lambda（Pipeline Worker）
│   ├── lambda_fastapi/         # Lambda（FastAPI）
│   ├── s3/                     # S3（画像保存）
│   ├── sagemaker/              # SageMaker Serverless
│   ├── sns/                    # SNS（通知）
│   └── step_functions/         # Step Functions（ワークフロー）
├── azure/                      # Azureリソース（OpenAI）
├── setup/                      # Terraform State管理リソース
├── DEPLOYMENT_CHECKLIST.md     # デプロイチェックリスト
├── SETUP_GUIDE.md              # セットアップガイド（デプロイ手順）
└── TERRAFORM_CICD_COMPLETE_GUIDE.md # CI/CD完全ガイド（GitHub Actions）
```

**主要リソース:**
- **AWS**: Step Functions, Lambda, SageMaker, Bedrock, S3, DynamoDB, CloudWatch, SNS, ECR, IAM
- **Azure**: Azure OpenAI Service（GPT-4o-mini）

**ドキュメント:**
- **SETUP_GUIDE.md**: Terraformのデプロイ手順、前提条件、ローカル開発環境セットアップ、検証環境情報
- **DEPLOYMENT_CHECKLIST.md**: デプロイ前後の確認項目チェックリスト
- **TERRAFORM_CICD_COMPLETE_GUIDE.md**: GitHub ActionsによるCI/CDパイプラインの完全ガイド（Personal Access Token作成、GitHub Secrets設定、Environment構成、検証手順、トラブルシューティング）

---

## 注意事項

- 機密情報は `.env` ファイルに記載し、`.gitignore` で除外してください
- ビルド成果物やキャッシュファイルは `.gitignore` で除外されています
