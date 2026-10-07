#!/usr/bin/env bash
# Phase 2 hybrid dev: fetch the macOS arm64 ONNX Runtime library (owner-approved,
# SHA256-verified) and the exported e5 model out of the already-built dev image.
set -euo pipefail
cd "$(dirname "$0")"

ORT_VERSION="1.23.2"
ORT_LIB="onnxruntime/lib/libonnxruntime.dylib"
MODEL_DIR="lm_model/onnx-e5"
ORT_ASSET="onnxruntime-osx-arm64-${ORT_VERSION}.tgz"
ORT_URL="https://github.com/microsoft/onnxruntime/releases/download/v${ORT_VERSION}/${ORT_ASSET}"
SHA_FILE="${ORT_SHA256_FILE:-onnxruntime.sha256}"
DEV_IMAGE="${DEV_IMAGE:-dashboard-be-dev:latest}"

ARCH="${NATIVE_ARCH:-$(uname -m)}"
[ "$ARCH" = "arm64" ] || { echo "unsupported arch: $ARCH (macOS arm64 only)" >&2; exit 1; }

if [ -f "$ORT_LIB" ]; then
  echo "onnxruntime already installed at $ORT_LIB"
else
  echo "About to download: $ORT_ASSET"
  echo "Source: $ORT_URL"
  if [ "${ORT_DOWNLOAD_APPROVED:-}" != "yes" ]; then
    echo "Not approved: ask the owner first, then rerun with ORT_DOWNLOAD_APPROVED=yes" >&2
    exit 2
  fi
  EXPECTED="$(tr -d '[:space:]' < "$SHA_FILE" 2>/dev/null || true)"
  if [ -z "$EXPECTED" ] || [ "$EXPECTED" = "UNSET" ]; then
    echo "missing, empty or placeholder $SHA_FILE: paste the official SHA256 from the release page first" >&2
    exit 3
  fi

  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  curl -fL "$ORT_URL" -o "$TMP/ort.tgz"
  ACTUAL="$(shasum -a 256 "$TMP/ort.tgz" | cut -d' ' -f1)"
  if [ "$ACTUAL" != "$EXPECTED" ]; then
    rm -f "$TMP/ort.tgz"
    echo "SHA256 mismatch for $ORT_ASSET (expected $EXPECTED, got $ACTUAL); nothing extracted" >&2
    exit 4
  fi
  mkdir -p onnxruntime
  tar -xzf "$TMP/ort.tgz" -C onnxruntime --strip-components=1
  echo "installed onnxruntime -> $ORT_LIB (SHA256 verified)"
fi

if [ -f "$MODEL_DIR/model.onnx" ] && [ -f "$MODEL_DIR/tokenizer.json" ]; then
  echo "model already present at $MODEL_DIR"
else
  mkdir -p "$MODEL_DIR"
  CID="$(docker create "$DEV_IMAGE")"
  docker cp "$CID:/opt/lm_model/onnx-e5/." "$MODEL_DIR/"
  docker rm "$CID" >/dev/null
  echo "copied model files from $DEV_IMAGE -> $MODEL_DIR"
fi
