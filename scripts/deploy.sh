#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-${ROOT_DIR}/artifacts}"
STACK_NAME="${STACK_NAME:-sns-sqs-project}"
PROJECT_NAME="${PROJECT_NAME:-sns-sqs-project}"
TEMPLATE_FILE="${TEMPLATE_FILE:-${ROOT_DIR}/cloudformation/infrastructure.yaml}"
PRODUCER_ZIP="${PRODUCER_ZIP:-${ARTIFACTS_DIR}/producer.zip}"
CONSUMER_ZIP="${CONSUMER_ZIP:-${ARTIFACTS_DIR}/consumer.zip}"
PRODUCER_CODE_KEY="${PRODUCER_CODE_KEY:-producer.zip}"
CONSUMER_CODE_KEY="${CONSUMER_CODE_KEY:-consumer.zip}"
LOG_RETENTION_IN_DAYS="${LOG_RETENTION_IN_DAYS:-14}"

require_file() {
  local path="$1"

  if [[ ! -f "${path}" ]]; then
    echo "Missing required file: ${path}" >&2
    exit 1
  fi
}

resolve_region() {
  if [[ -n "${AWS_REGION:-}" ]]; then
    echo "${AWS_REGION}"
    return
  fi

  if [[ -n "${AWS_DEFAULT_REGION:-}" ]]; then
    echo "${AWS_DEFAULT_REGION}"
    return
  fi

  aws configure get region || true
}

ensure_bucket() {
  local bucket="$1"
  local region="$2"

  if aws s3api head-bucket --bucket "${bucket}" >/dev/null 2>&1; then
    echo "Using existing S3 bucket: ${bucket}"
    return
  fi

  echo "Creating S3 bucket: ${bucket}"

  if [[ "${region}" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "${bucket}"
  else
    aws s3api create-bucket \
      --bucket "${bucket}" \
      --create-bucket-configuration LocationConstraint="${region}"
  fi

  aws s3api put-public-access-block \
    --bucket "${bucket}" \
    --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

  aws s3api put-bucket-encryption \
    --bucket "${bucket}" \
    --server-side-encryption-configuration \
      '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
}

resolve_account_id() {
  if ! aws sts get-caller-identity --query Account --output text; then
    echo "AWS credentials are invalid. In CircleCI, check AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN, and AWS_REGION/AWS_DEFAULT_REGION." >&2
    echo "If you are using long-lived IAM user keys, remove AWS_SESSION_TOKEN from CircleCI unless it belongs to the same active session." >&2
    exit 1
  fi
}

require_file "${TEMPLATE_FILE}"
require_file "${PRODUCER_ZIP}"
require_file "${CONSUMER_ZIP}"

AWS_REGION="$(resolve_region)"
AWS_REGION="${AWS_REGION:-us-east-1}"
export AWS_REGION
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-${AWS_REGION}}"

if [[ -z "${AWS_REGION}" ]]; then
  echo "Missing AWS region. Set AWS_REGION or AWS_DEFAULT_REGION." >&2
  exit 1
fi

if [[ -z "${LAMBDA_CODE_BUCKET:-}" ]]; then
  AWS_ACCOUNT_ID="$(resolve_account_id)"
  LAMBDA_CODE_BUCKET="${PROJECT_NAME}-lambda-code-${AWS_ACCOUNT_ID}-${AWS_REGION}"
fi

ensure_bucket "${LAMBDA_CODE_BUCKET}" "${AWS_REGION}"

echo "Uploading Lambda packages to s3://${LAMBDA_CODE_BUCKET}"
aws s3 cp "${PRODUCER_ZIP}" "s3://${LAMBDA_CODE_BUCKET}/${PRODUCER_CODE_KEY}"
aws s3 cp "${CONSUMER_ZIP}" "s3://${LAMBDA_CODE_BUCKET}/${CONSUMER_CODE_KEY}"

echo "Deploying CloudFormation stack ${STACK_NAME}"
aws cloudformation deploy \
  --template-file "${TEMPLATE_FILE}" \
  --stack-name "${STACK_NAME}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    ProjectName="${PROJECT_NAME}" \
    LambdaCodeBucket="${LAMBDA_CODE_BUCKET}" \
    ProducerCodeKey="${PRODUCER_CODE_KEY}" \
    ConsumerCodeKey="${CONSUMER_CODE_KEY}" \
    LogRetentionInDays="${LOG_RETENTION_IN_DAYS}"

echo "Deployment complete"
