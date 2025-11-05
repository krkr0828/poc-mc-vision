# Terraform State Backend Setup

このディレクトリには、Terraform State管理用のS3バケットとDynamoDBテーブルを作成するスクリプトが含まれています。

## 前提条件

- AWS CLI がインストール済み
- AWS認証情報が設定済み（`aws configure` または環境変数）
- 適切な権限（S3/DynamoDB作成権限）

## 使用方法

### 1. スクリプトに実行権限を付与

```bash
chmod +x create-state-backend.sh
```

### 2. スクリプトを実行

```bash
./create-state-backend.sh
```

### 3. 作成されるリソース

- **S3バケット (AWS用)**: `poc-mc-vision-terraform-state-aws`
  - バージョニング有効
  - AES256暗号化有効

- **S3バケット (Azure用)**: `poc-mc-vision-terraform-state-azure`
  - バージョニング有効
  - AES256暗号化有効

- **DynamoDBテーブル**: `poc-mc-vision-terraform-locks`
  - State ロック管理用
  - PAY_PER_REQUEST課金モード

## トラブルシューティング

### バケット名の競合

S3バケット名がグローバルで既に使用されている場合：

1. `create-state-backend.sh` を編集
2. `STATE_BUCKET_AWS` と `STATE_BUCKET_AZURE` の値を変更
3. 各 `backend.tf` ファイルのバケット名も合わせて変更

### 権限エラー

以下の権限が必要です：

- `s3:CreateBucket`
- `s3:PutBucketVersioning`
- `s3:PutEncryptionConfiguration`
- `dynamodb:CreateTable`
- `dynamodb:DescribeTable`

## 削除方法

State管理用リソースを削除する場合（**慎重に実行**）：

```bash
# DynamoDBテーブル削除
aws dynamodb delete-table \
    --table-name poc-mc-vision-terraform-locks \
    --region ap-northeast-1

# S3バケット削除（空にしてから）
aws s3 rb s3://poc-mc-vision-terraform-state-aws --force
aws s3 rb s3://poc-mc-vision-terraform-state-azure --force
```

**注意**: State ファイルが含まれる場合、削除前に必ずバックアップを取ってください。
