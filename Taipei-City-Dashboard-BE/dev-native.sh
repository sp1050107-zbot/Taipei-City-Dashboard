#!/usr/bin/env bash
# Phase 2 hybrid dev: run the BE natively on the host against the Dockerized
# DB/Redis/Qdrant. Takes the secrets from the existing Docker environment file
# (never printed), then overrides only the values that differ for host
# networking. Starts no container.
set -euo pipefail
cd "$(dirname "$0")"

ENV_FILE="${DEV_NATIVE_ENV_FILE:-../docker/.env}"
if [ ! -f "$ENV_FILE" ]; then
  echo "dev-native: environment file missing: $ENV_FILE (create it first; see docs/agent-workflow/make-env.sh)" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

export DB_DASHBOARD_HOST=localhost
export DB_DASHBOARD_PORT=5433
export DB_MANAGER_HOST=localhost
export DB_MANAGER_PORT=5432
export REDIS_HOST=localhost
export REDIS_PORT=6379
export QDRANT_URL=http://localhost:6333
export GIN_DOMAIN=localhost
export GIN_PORT=8088
# Defaults are where the native model setup script puts the files; this
# script neither runs nor depends on it.
export ORT_LIBRARY_PATH="${ORT_LIBRARY_PATH:-$(pwd)/onnxruntime/lib/libonnxruntime.dylib}"
export LM_MODEL_PATH="${LM_MODEL_PATH:-$(pwd)/lm_model/onnx-e5/}"

if [ ! -f "$ORT_LIBRARY_PATH" ]; then
  echo "dev-native: ONNX Runtime library not found: $ORT_LIBRARY_PATH (set ORT_LIBRARY_PATH or run the native model setup)" >&2
  exit 1
fi
if [ ! -f "${LM_MODEL_PATH%/}/model.onnx" ]; then
  echo "dev-native: embedding model not found: ${LM_MODEL_PATH%/}/model.onnx (set LM_MODEL_PATH or run the native model setup)" >&2
  exit 1
fi

export GOTOOLCHAIN=local
exec go run main.go "$@"
