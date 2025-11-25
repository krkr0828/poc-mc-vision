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
| **セキュリティ基盤** | S3暗号化・バージョニング・構造化ログ・tfsecスキャンなど、基本的なセキュリティ設定を実装。 |

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

### **アーキテクチャ図**

![構成図](./docs/構成図スクリーンショット.png)

*Draw.ioファイル: [poc-mc-vision-architecture.drawio](./docs/poc-mc-vision-architecture.drawio)*

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
CloudWatch Alarms + SNS Email通知
├── Lambda監視
│   ├── FastAPI Lambda
│   │   └── エラー/スロットリング検知,レイテンシ監視
│   ├── Pipeline Worker Lambda
│   │   └── レイテンシ監視,エラー検知
│   └── S3 Ingest Lambda
│       └── レイテンシ監視,エラー検知
└── Step Functions監視
    └── 実行失敗/スロットリング/タイムアウト検知
```

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

## 💡 実装のポイント

本PoCでは、以下の観点を意識して構成を組んでいます。

### マルチクラウド環境でのAI基盤構成
- AWS SageMaker Serverless・Bedrock と Azure OpenAI を、単一の API エンドポイントから呼び出せる構成としました。
- AWS を中心としつつ、既存システムで Azure OpenAI を利用しているケースも想定し、マルチクラウド連携パターンを一通り確認できるようにしています。

### Terraform + CI/CD によるインフラ自動化
- AWS / Azure の主要リソースを Terraform でコード化し、GitHub Actions から `fmt` / `validate` / `tfsec` / `plan` を PR ごとに自動実行するフローを組んでいます。
- 本番相当の環境を想定し、手動承認付きの `apply` とすることで、インフラ変更をレビュー経由で反映する運用イメージを持てるようにしています。

### Step Functions を使った推論パイプライン
- Step Functions で SageMaker → 並列 (Bedrock + Azure) → DynamoDB → SNS 通知のフローを構成し、複数の AI サービスを組み合わせて扱う前提で設計しました。
- Azure OpenAI のレート制限（429）など一時的なエラーを想定し、リトライ設定を入れてワークフロー全体が落ちにくいようにしています。

### 監視・アラート設計
- Lambda・Step Functions・SageMaker のエラーや遅延を検知できるよう、CloudWatch Alarms と SNS Email 通知を設定しています。
- P95 レイテンシやエラー率といった指標を中心に見ることで、外れ値ではなく全体傾向を把握する前提で監視を組んでいます。

---

## 📂 ディレクトリ構造

プロジェクトの詳細なディレクトリ構造については、[docs/DIRECTORY_STRUCTURE.md](./docs/DIRECTORY_STRUCTURE.md) を参照してください。

---

## 📚 セットアップ手順

インフラのデプロイ手順やローカル開発環境のセットアップについては、[Terraform/SETUP_GUIDE.md](./Terraform/SETUP_GUIDE.md) を参照してください。
