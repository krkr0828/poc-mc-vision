# PoC MC Vision ― AWS中心のAI推論基盤PoC（Azure連携の検証付き）

## 🚀 エグゼクティブサマリー ＆ 主要技術成果

本PoCでは、**AWSを中心としたAI推論基盤**に、検証用としてAzure OpenAIを組み合わせた構成を試しました。Terraform + CI/CDによる再現可能なインフラ管理、Step Functionsでワークフローを組み立て、CloudWatch AlarmsとBedrock Guardrailsで監視・セキュリティまわりも構築しました。

| 観点 | 実装内容 |
| :--- | :--- |
| **IaCによる再現性** | AWS／Azureの全リソースをTerraformでコード化し、約10分で再構築が可能。 |
| **ワークフロー自動化** | Step Functions で SageMaker→並列(Bedrock+Azure)→DynamoDB→SNS の推論パイプラインを実装。 |
| **マルチクラウド連携** | 単一のAPIエンドポイントからAzure OpenAIも呼び出せるようにし、マルチクラウド構成もあわせて実装。  |
| **CI/CDパイプライン** | GitHub Actionsで`tfsec`セキュリティスキャン・`plan`結果のPRコメント投稿・手動承認付き`apply`を自動化。 |
| **監視・アラート** | CloudWatch AlarmsとSNS Email通知により、主要サービスの障害や遅延を検知できるように設定。 |
| **AIの安全性確保** | Bedrock GuardrailsでPII（個人識別情報）検知・有害コンテンツフィルタリングを実装。 |

---

## 🎯 PoCの背景と目的

2026年以降に想定している「AWS上のAI推論基盤／MLOps案件」を意識して、モデル開発ではなく、インフラ構成・ワークフロー・監視・セキュリティといった基盤周りを一通り手を動かして整理したPoCです。

---

## 🛠 システム概要

本PoCで構築したシステムは、Reactフロントエンドからアップロードした画像を、主に AWS（SageMaker Serverless / Bedrock）で推論し、必要に応じて Azure OpenAI も利用する AI 推論基盤です。

推論の実行には、目的別に次の2つの経路があります。

1.  **APIトリガーによる非同期実行（メインフロー）**
    *   ユーザーがAPIを呼び出すと、**Step Functionsが起動**します。
    *   Step Functionsが推論パイプライン（SageMaker → 並列(Bedrock + Azure) → DynamoDB保存 → SNS通知）を自動で実行します。
2.  **FastAPIによる同期実行（個別推論用）**
    *   各AIサービスを個別に推論するため、FastAPI経由で直接推論APIを実行して結果を表示します。

AWS・Azureの認証情報は環境変数で管理します。Bedrock GuardrailsでPII（個人識別情報）検知と有害コンテンツフィルタリングを実行し、CloudWatch Alarmsで主要サービスの障害や遅延を検知してSNS Email通知を送信します。

### **処理フロー**

```
【ユーザー操作】
React フロントエンド
│
├── ① FastAPI直接実行（同期処理）
│   ├── 解析API実行
│   │   └── FastAPI (Lambda)
│   ├── 推論実行
│   │   ├── SageMaker
│   │   ├── Bedrock
│   │   └── Azure OpenAI
│   └── DynamoDB保存
│
└── ② Step Functions自動実行（非同期処理）
    ├── API呼び出し（S3キー指定）
    │   └── Step Functions起動
    │       ├── SageMaker推論（順次）
    │       ├── Bedrock + Azure（並列）
    │       │   └── Guardrails適用
    │       ├── DynamoDB保存
    │       ├── SNS Email通知
    │       └── CloudWatch Logs記録

【監視・アラート】
CloudWatch Alarms（10個）+ SNS Email通知
├── Lambda監視（7個）
│   ├── FastAPI Lambda
│   │   ├── エラー検知（Errors ≥ 1）
│   │   ├── レイテンシ監視（Duration P95 > 閾値）
│   │   └── スロットリング検知（Throttles ≥ 1）
│   ├── Pipeline Worker Lambda
│   │   ├── エラー検知（Errors ≥ 1）
│   │   └── レイテンシ監視（Duration P95 > 閾値）
│   └── S3 Ingest Lambda
│       ├── エラー検知（Errors ≥ 1）
│       └── レイテンシ監視（Duration P95 > 閾値）
└── Step Functions監視（3個）
    ├── 実行失敗検知（ExecutionsFailed ≥ 1）
    ├── タイムアウト検知（ExecutionsTimedOut ≥ 1）
    └── スロットリング検知（ExecutionThrottled ≥ 1）
```

### **アーキテクチャ図**

![構成図](./docs/構成図スクリーンショット.png)

*Draw.ioファイル: [poc-mc-vision-architecture.drawio](./docs/poc-mc-vision-architecture.drawio)*

### **動作デモ**

実際の動作画面は **`docs/PoC動作画面録画.mp4`** を参照してください。

- ✅ フロントエンドからの画像アップロード
- ✅ Azure OpenAI, AWS Bedrock, AWS SageMaker それぞれによる推論実行
- ✅ S3への直接アップロードと解析

---

## ✨ 技術スタックと主要機能

### **インフラ（IaC）**
- **Terraform** (1.9.8): 主にAWS（一部Azure）のインフラをコードで定義・管理。
- **State管理**: S3バックエンドに状態を保存し、DynamoDBでロックを管理。

### **AWS サービス**
- **Step Functions**: メインの推論パイプラインをオーケストレーション。
- **Lambda**:
    - **FastAPIコンテナ**: APIエンドポイントを提供 (ECR経由)。
    - **Pipeline Worker**: Step Functionsから呼び出され、各AIサービスへのリクエストを実行。
    - **S3 Event Logger**: S3へのアップロードイベントをログに記録する補助機能。
- **AI / ML**:
    - **SageMaker Serverless**: カスタムPyTorchモデル（ResNet18）のホスティング。
        - 画像分類タスクとして十分な精度がありつつ比較的軽量なモデルのため、Serverless Inference のメモリや起動時間と相性が良いと判断して採用。
        - 本PoCでは、S3へのアップロードをきっかけに不定期に推論を行う構成のため、常時起動のエンドポイントではなく Serverless を選択し、待機コストを抑える構成としている。
    - **Bedrock**: Claude 3 Haikuモデルを利用（Guardrails適用）。
- **データストア**:
    - **S3**: 画像アップロード先（暗号化, バージョニング, ライフサイクル設定）。
    - **DynamoDB**: 推論結果の保存（オンデマンド, TTL設定）。
- **監視 & 通知**:
    - **CloudWatch Alarms**: 10個のアラームで主要コンポーネントを監視。
    - **SNS**: アラーム発報時やパイプライン完了時にEメールで通知。
- **その他**: **ECR** (コンテナリポジトリ), **IAM** (権限管理)

### **Azure サービス**
- **Azure OpenAI**: GPT-4o-miniモデルのホスティング。

### **アプリケーション**
- **FastAPI** (Python 3.12): APIサーバーを実装。
- **React 19 + Vite**: フロントエンドUIを構築。

### **CI/CD パイプライン（GitHub Actions）**
- **自動検証**: PR作成時に`terraform plan`・フォーマット・セキュリティスキャン（`tfsec`）を自動実行。
- **手動承認デプロイ**: `main`ブランチへのマージ後、手動承認を経て`terraform apply`を実行するデプロイフロー。
- **Plan結果の自動コメント**: 実行計画をPRへ自動投稿し、レビューの効率を向上。

---

## 🔧 実装時の技術課題と解決策

### **1. Bedrock GuardrailsのIAM権限不足**
- **課題**: Step Functions経由でBedrock Guardrailsを適用した際、`AccessDeniedException` が発生。
- **原因と解決**: Pipeline Worker LambdaのIAMロールに `bedrock:ApplyGuardrail` 権限が不足していました。これは2024年後半の新機能となり既存の管理ポリシーに含まれていなかったためで、TerraformのIAM定義に権限を明示的に追加し、解決しました。
- **※設計方針**: Guardrails の設定はアプリケーションコードではなく Terraform 側で管理し、モデルを切り替えても同じ出力制御ポリシー（PII検知・有害コンテンツフィルタリング）を適用できるようにしています。

### **2. Azure OpenAIのレート制限（HTTP 429）**
- **課題**: 連続テスト実行時にAzure OpenAI APIが `429 Too Many Requests` を返し、Lambdaがタイムアウト。
- **原因と解決**: Azure Portal からクオータを増加させることで、継続的なエラーは解消しました。あわせて、Step Functionsのタスクにリトライ設定(Bedrock含む)を追加し、一定回数まではワークフロー内で自動的にリトライするようにしています。

### **3. CI/CD実装時のtfsecセキュリティチェック調整**
- **課題**: CI/CDパイプラインに`tfsec`を導入した際、影響度が低いチェック項目まで含めていたため、軽微な指摘が頻発してPRのワークフローが阻害されました。
- **原因と解決**: 初期設定では全ての重要度レベル（LOW/MEDIUM/HIGH）をチェック対象としていたため、影響度の低い警告が多発しました。`tfsec`の設定を調整し、HIGH重要度のみをチェック対象とすることで、セキュリティ上重要な問題に絞り込むことで解決しました。

### **その他の技術課題**
上記の他に、SageMaker Serverlessのカスタムモデル設定、S3のCORS設定、Azure Resource Provider登録等の実装中に発生した技術課題に対処しました。

---

## ✅ 実績サマリー

- ✅ **マルチクラウド設計**: AWS（SageMaker / Bedrock）を中心に、必要に応じて Azure OpenAI も呼び出せる推論フローを実装
- ✅ **IaC による再現性**: AWS/Azureを単一コードベースで管理し、約10分で再構築可能
- ✅ **ワークフローオーケストレーション**: Step Functionsで SageMaker→並列(Bedrock+Azure)→DynamoDB→SNS の推論フローが自動実行されるように構成
- ✅ **監視・アラート**: CloudWatch Alarms + SNS Email通知で、Lambda / StepFunctions / SageMaker の障害や遅延を検知できるように設定
- ✅ **AI出力の安全性への配慮**: Bedrock GuardrailsによるPII検知・有害コンテンツフィルタリングを実装
- ✅ **CI/CD パイプライン**: GitHub Actionsによる自動検証・手動承認デプロイを実装
- ✅ **セキュリティ基盤**: S3暗号化・バージョニング・構造化ログ・tfsecスキャンなど、基本的なセキュリティ設定を実装

---

## 💡 このPoCで得た知見・設計ノウハウ

### **マルチクラウド環境でのAI基盤構築**
AWS・Azure の認証、API連携、エラーハンドリングなどを一通り実装してみました。SageMaker Serverlessでのカスタムモデルデプロイや Bedrock Guardrails の設定など、本番運用を意識した構成も試しました。

### **Terraform + CI/CDによるインフラ自動化**
IaC と GitHub Actions でデプロイフローを組み、PRごとに `fmt` / `validate` / `tfsec` / `plan` を自動実行するようにしました。手動承認ゲートも合わせて設定し、インフラ変更の流れを具体的にイメージできるようになりました。

### **Step Functionsによるワークフローオーケストレーション**
複数のAIサービスを並列実行しつつ、エラー時の挙動やリトライ方法をStep Functionsで実装しました。SageMaker→並列(Bedrock+Azure)→DynamoDB→SNS通知という流れを通して、ワークフロー設計の勘所をつかむことができました。

### **監視・アラート体制の構築**
CloudWatch Alarms（10個）と SNS Email 通知を組み合わせて、Lambda・Step Functions・SageMaker の障害やレイテンシを検知する仕組みを作りました。本番運用を想定したときに、どの指標を見ておくべきかを整理する良い機会になりました。

---

## 🧪 検証環境

| 項目 | 内容 |
|------|------|
| **実施期間** | 2025年10月〜11月（約2ヶ月） |
| **実行環境** | AWS（東京リージョン: ap-northeast-1）＋ Azure（米国東部2: East US 2） |
| **Terraform** | 1.9.8 |
| **Python** | 3.12 |
| **Node.js** | 18.x |

---

## 📂 ディレクトリ構造

```
poc-mc-vision/
├── Terraform/                   # インフラ定義（AWS/Azure）
│   ├── aws/                     # AWSリソース定義
│   ├── azure/                   # Azureリソース（OpenAI）
│   └── setup/                   # State管理用リソース作成スクリプト
├── src/
│   ├── backend/                 # FastAPI（Python 3.12）
│   └── frontend/                # React 19 + Vite
├── .github/workflows/           # CI/CDパイプライン（GitHub Actions）
├── sagemaker_model/             # SageMaker用カスタムモデル
├── scripts/                     # 運用スクリプト（Guardrail作成等）
├── Lambda/                      # Lambda（S3イベント処理）
├── configs/                     # 環境変数テンプレート
└── docs/                        # アーキテクチャ図・動作デモ動画
```

---

## 📚 クイックスタート

**構築の流れ**: ローカル開発環境をセットアップし、TerraformでAWS/Azureリソースをデプロイ、DockerイメージをECRにプッシュすることで、約15分でマルチクラウドAI基盤が構築できます。詳細な手順は以降のセクションおよび関連ドキュメントを参照してください。

---

#### **前提条件**
以下のツールをインストールしてください。
- **Terraform** (1.9.8以上)
- **AWS CLI** (v2) + 認証情報設定済み
- **Azure CLI** + ログイン済み
- **Python** (3.12以上)
- **Node.js** (18.x以上)
- **Docker** (Lambda Container Image ビルド用、オプション)

#### **ローカル開発環境のセットアップ**

**Backend（FastAPI）**
```bash
cd src/backend
pip install -r requirements.txt
cp ../../configs/.env.example .env
# .envファイルに AWS/Azure の認証情報を設定
uvicorn main:app --reload  # http://localhost:8000 で起動
```

**Frontend（React + Vite）**
```bash
cd src/frontend
npm install
npm run dev  # http://localhost:5173 で起動
```

#### **インフラデプロイ**
TerraformコマンドでAWSとAzureの全リソースを約10分で構築可能です。
```bash
cd Terraform/aws
terraform init
terraform plan
terraform apply
```

**関連ドキュメント**:
- **Terraformデプロイ手順**: [Terraform/README.md](./Terraform/README.md)
- **デプロイチェックリスト**: [Terraform/DEPLOYMENT_CHECKLIST.md](./Terraform/DEPLOYMENT_CHECKLIST.md)
- **Docker & ECRデプロイメント**: [docs/DOCKER_ECR_DEPLOYMENT_GUIDE.md](./docs/DOCKER_ECR_DEPLOYMENT_GUIDE.md)
- **CI/CD完全ガイド**: [Terraform/TERRAFORM_CICD_COMPLETE_GUIDE.md](./Terraform/TERRAFORM_CICD_COMPLETE_GUIDE.md)

### **今後の目標**
PoCで得た経験を活かし、本番運用を想定した構築・監視・セキュリティ設計を含む実務経験を積んでいきたいと考えています。
