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

require_env() {
  local name="$1"

  if [[ -z "${!name:-}" ]]; then
    echo "Missing required environment variable: ${name}" >&2
    exit 1
  fi
}

require_file() {
  local path="$1"

  if [[ ! -f "${path}" ]]; then
    echo "Missing required file: ${path}" >&2
    exit 1
  fi
}

require_env LAMBDA_CODE_BUCKET
require_file "${TEMPLATE_FILE}"
require_file "${PRODUCER_ZIP}"
require_file "${CONSUMER_ZIP}"

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
