#!/bin/bash
# Terraform State管理用のS3バケットとDynamoDBテーブルを作成するスクリプト

set -e

# 設定値
AWS_REGION="ap-northeast-1"
STATE_BUCKET_AWS="poc-mc-vision-terraform-state-aws"
STATE_BUCKET_AZURE="poc-mc-vision-terraform-state-azure"
LOCK_TABLE="poc-mc-vision-terraform-locks"

echo "=========================================="
echo "Terraform State Backend Setup"
echo "=========================================="
echo ""
echo "AWS Region: ${AWS_REGION}"
echo "State Bucket (AWS): ${STATE_BUCKET_AWS}"
echo "State Bucket (Azure): ${STATE_BUCKET_AZURE}"
echo "Lock Table: ${LOCK_TABLE}"
echo ""

# S3バケット作成（AWS用）
echo "[1/4] Creating S3 bucket for AWS state: ${STATE_BUCKET_AWS}..."
if aws s3 ls "s3://${STATE_BUCKET_AWS}" 2>/dev/null; then
    echo "  → Bucket already exists. Skipping."
else
    aws s3api create-bucket \
        --bucket "${STATE_BUCKET_AWS}" \
        --region "${AWS_REGION}" \
        --create-bucket-configuration LocationConstraint="${AWS_REGION}"

    # バージョニング有効化
    aws s3api put-bucket-versioning \
        --bucket "${STATE_BUCKET_AWS}" \
        --versioning-configuration Status=Enabled

    # 暗号化有効化
    aws s3api put-bucket-encryption \
        --bucket "${STATE_BUCKET_AWS}" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }'

    echo "  ✓ Bucket created and configured."
fi

# S3バケット作成（Azure用）
echo "[2/4] Creating S3 bucket for Azure state: ${STATE_BUCKET_AZURE}..."
if aws s3 ls "s3://${STATE_BUCKET_AZURE}" 2>/dev/null; then
    echo "  → Bucket already exists. Skipping."
else
    aws s3api create-bucket \
        --bucket "${STATE_BUCKET_AZURE}" \
        --region "${AWS_REGION}" \
        --create-bucket-configuration LocationConstraint="${AWS_REGION}"

    # バージョニング有効化
    aws s3api put-bucket-versioning \
        --bucket "${STATE_BUCKET_AZURE}" \
        --versioning-configuration Status=Enabled

    # 暗号化有効化
    aws s3api put-bucket-encryption \
        --bucket "${STATE_BUCKET_AZURE}" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }]
        }'

    echo "  ✓ Bucket created and configured."
fi

# DynamoDBテーブル作成（ロック管理用）
echo "[3/4] Creating DynamoDB table for state locking: ${LOCK_TABLE}..."
if aws dynamodb describe-table --table-name "${LOCK_TABLE}" --region "${AWS_REGION}" 2>/dev/null; then
    echo "  → Table already exists. Skipping."
else
    aws dynamodb create-table \
        --table-name "${LOCK_TABLE}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "${AWS_REGION}"

    echo "  → Waiting for table to become active..."
    aws dynamodb wait table-exists \
        --table-name "${LOCK_TABLE}" \
        --region "${AWS_REGION}"

    echo "  ✓ Table created."
fi

# 確認
echo "[4/4] Verifying resources..."
echo ""
echo "✓ S3 Bucket (AWS): $(aws s3 ls s3://${STATE_BUCKET_AWS} --region ${AWS_REGION} && echo 'OK' || echo 'FAILED')"
echo "✓ S3 Bucket (Azure): $(aws s3 ls s3://${STATE_BUCKET_AZURE} --region ${AWS_REGION} && echo 'OK' || echo 'FAILED')"
echo "✓ DynamoDB Table: $(aws dynamodb describe-table --table-name ${LOCK_TABLE} --region ${AWS_REGION} --query 'Table.TableStatus' --output text)"
echo ""
echo "=========================================="
echo "Setup completed successfully!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Update backend.tf files with these values:"
echo "   - AWS:   bucket = \"${STATE_BUCKET_AWS}\""
echo "   - Azure: bucket = \"${STATE_BUCKET_AZURE}\""
echo "   - Both:  dynamodb_table = \"${LOCK_TABLE}\""
echo ""
echo "2. Run terraform init in aws/ and azure/ directories"
echo ""
