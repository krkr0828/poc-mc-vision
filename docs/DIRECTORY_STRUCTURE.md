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
├── .terraform-version          # Terraformバージョン指定
└── README.md                   # プロジェクト概要
```

---

## 詳細構造

### `.github/`
GitHub ActionsによるCI/CDパイプライン設定

```
.github/
└── workflows/                  # ワークフロー定義
    ├── docker-build-push.yml   # Dockerイメージ自動ビルド・ECRプッシュ
    ├── terraform-apply.yml     # Terraform自動適用（mainブランチ）
    └── terraform-plan.yml      # Terraform検証（PR）
```

**主な機能:**
- **Docker/ECR自動デプロイ**: `src/backend/`変更時、Dockerイメージを自動ビルド・ECRプッシュ・Lambda更新
- **Terraform自動検証**: PR作成時にfmt, validate, plan, tfsecを実行
- **Terraform自動適用**: mainブランチへのpush時にterraform applyを実行
- **Concurrency制御**: インフラデプロイの順序を保証（Terraform → Docker）
- **PR自動コメント**: plan結果をPRに自動投稿

### `configs/`
環境変数テンプレートやアプリケーション設定ファイル

**含まれるファイル:**
- `.env.example`: 環境変数のサンプル設定

### `docs/`
プロジェクトドキュメント

**含まれるファイル:**
- **`GETTING_STARTED.md`**: プロジェクト全体の初回セットアップガイド（**最初に読むドキュメント**）
- **`CI_CD_TESTING_GUIDE.md`**: CI/CDの運用・テスト手順書（日常的な開発フロー）
- **`DOCKER_ECR_DEPLOYMENT_GUIDE.md`**: Docker・ECR技術リファレンス + 手動デプロイ手順
- `DIRECTORY_STRUCTURE.md`: 本ドキュメント（ディレクトリ構造説明）
- `構成図スクリーンショット.png`: アーキテクチャ図
- `poc-mc-vision-architecture.drawio`: Draw.io形式のアーキテクチャ図
- `証跡/`: 画面キャプチャや検証証跡（スクリーンショット）を格納

**ドキュメントの役割分担:**
1. **GETTING_STARTED.md** → 初めてセットアップする人向け
2. **CI_CD_TESTING_GUIDE.md** → 日常的に開発する人向け
3. **DOCKER_ECR_DEPLOYMENT_GUIDE.md** → 技術詳細を知りたい人、手動デプロイが必要な人向け

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
│   ├── cloudwatch/             # CloudWatch Alarms / Dashboard
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
└── TERRAFORM_CICD_SETUP_GUIDE.md # CI/CD初期設定ガイド（GitHub Actions）
```

**主要リソース:**
- **AWS**: Step Functions, Lambda, SageMaker, Bedrock, S3, DynamoDB, CloudWatch, SNS, ECR, IAM
- **Azure**: Azure OpenAI Service（GPT-4o-mini）

**ドキュメント:**
- **SETUP_GUIDE.md**: Terraformのデプロイ手順、前提条件、ローカル開発環境セットアップ、検証環境情報
- **DEPLOYMENT_CHECKLIST.md**: デプロイ前後の確認項目チェックリスト
- **TERRAFORM_CICD_SETUP_GUIDE.md**: GitHub ActionsによるCI/CDパイプラインの初期設定ガイド（Personal Access Token作成、GitHub Secrets設定、Environment構成、検証手順、トラブルシューティング）

---

## ルートレベルの設定ファイル

### `.terraform-version`
Terraformのバージョンを指定するファイル

**用途:**
- tfenvやasdfなどのバージョン管理ツールが、このファイルを読み取り自動的に指定バージョンのTerraformを使用します
- プロジェクトで使用すべきTerraformバージョンを明示的に管理し、開発環境間での一貫性を保証します
- CI/CD環境とローカル環境でのバージョン統一を実現します

**設定値:** `1.9.8`

### `.gitattributes` / `.gitignore`
Git設定ファイル

**用途:**
- `.gitattributes`: Git属性設定（改行コード、ファイルタイプ指定など）
- `.gitignore`: バージョン管理から除外するファイル・ディレクトリの指定

---

## 注意事項

- 機密情報は `.env` ファイルに記載し、`.gitignore` で除外してください
- ビルド成果物やキャッシュファイルは `.gitignore` で除外されています
