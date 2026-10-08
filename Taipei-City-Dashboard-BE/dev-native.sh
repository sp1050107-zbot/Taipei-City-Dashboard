#!/usr/bin/env bash
# Phase 2 hybrid dev: run the BE natively on the host against the Dockerized
# DB/Redis/Qdrant. Takes the secrets from the existing Docker environment file
# (never printed), then overrides only the values that differ for host
# networking. Starts no container.
set -euo pipefail
cd "$(dirname "$0")"

ENV_FILE="${DEV_NATIVE_ENV_FILE:-../docker/.env}"
if [ ! -f "$ENV_FILE" ]; then
  echo "dev-native: environment file missing: $ENV_FILE (the Docker environment file must exist; create it from its template first)" >&2
  exit 1
fi

# Phase 1 and Phase 2 never run at the same time (decision 0002): refuse when
# something already listens on the backend port. DEV_NATIVE_PORT_CHECK is a
# test hook: a command run as `<cmd> <host> <port>`, exit 0 means "in use".
port_in_use() {
  if [ -n "${DEV_NATIVE_PORT_CHECK:-}" ]; then
    "$DEV_NATIVE_PORT_CHECK" 127.0.0.1 8088
  else
    nc -z 127.0.0.1 8088 >/dev/null 2>&1
  fi
}
if port_in_use; then
  echo "dev-native: 127.0.0.1:8088 is already in use (is the Phase 1 dashboard-be container still running?). Phase 1 and Phase 2 run one at a time; see docs/decisions/0002-phase1-phase2-one-stack-at-a-time.md" >&2
  exit 1
fi

# The caller's own model/library locations win over everything. The Docker
# environment file carries container paths for these two names, so it must
# never decide them.
CALLER_ORT_LIBRARY_PATH="${ORT_LIBRARY_PATH:-}"
CALLER_LM_MODEL_PATH="${LM_MODEL_PATH:-}"

# Read the environment file as plain data, never as shell code: no source,
# no eval, so $, backticks, ; and quotes in a value stay literal. Each line is
# KEY=VALUE (split at the first =); one pair of matching surrounding quotes is
# stripped. Blank lines, comments and invalid key names are skipped.
while IFS= read -r line || [ -n "$line" ]; do
  line="${line%$'\r'}"
  case "$line" in ''|'#'*) continue ;; esac
  case "$line" in *=*) ;; *) continue ;; esac
  key="${line%%=*}"
  value="${line#*=}"
  if ! [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    echo "dev-native: skipping a line with an invalid variable name in $ENV_FILE" >&2
    continue
  fi
  if [ "${#value}" -ge 2 ]; then
    first="${value:0:1}"
    last="${value: -1}"
    if { [ "$first" = '"' ] || [ "$first" = "'" ]; } && [ "$first" = "$last" ]; then
      value="${value:1:${#value}-2}"
    fi
  fi
  export "$key=$value"
done < "$ENV_FILE"

export ORT_LIBRARY_PATH="${CALLER_ORT_LIBRARY_PATH:-$(pwd)/onnxruntime/lib/libonnxruntime.dylib}"
export LM_MODEL_PATH="${CALLER_LM_MODEL_PATH:-$(pwd)/lm_model/onnx-e5/}"

export DB_DASHBOARD_HOST=localhost
export DB_DASHBOARD_PORT=5433
export DB_MANAGER_HOST=localhost
export DB_MANAGER_PORT=5432
export REDIS_HOST=localhost
export REDIS_PORT=6379
export QDRANT_URL=http://localhost:6333
export GIN_DOMAIN=localhost
export GIN_PORT=8088
# Defaults (set above) are where the native model setup script puts the
# files; this script neither runs nor depends on it.

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
