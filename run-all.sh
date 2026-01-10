#!/usr/bin/env bash
set -euo pipefail

## Choose chip architecture
case "$(uname -m)" in
  x86_64)        CURRENT_ARCH="amd64" ;;
  aarch64|arm64) CURRENT_ARCH="arm64" ;;
  *)             CURRENT_ARCH="$(uname -m)" ;;
esac

BASENAME="${CURRENT_ARCH}/hkr-images.tar"
TAR="$BASENAME"
ZST="$BASENAME.zst"
XZ="$BASENAME.xz"
GZ="$BASENAME.gz"

echo ">> Looking for archive: $ZST | $XZ | $GZ | $TAR"

# Decompress to .tar only if .tar doesn't already exist
if [ ! -f "$TAR" ]; then
  if [ -f "$ZST" ]; then
    command -v zstd >/dev/null 2>&1 || { echo "ERROR: zstd not installed"; exit 1; }
    echo ">> Decompressing $ZST -> $TAR"
    zstd -dc "$ZST" > "$TAR"
  elif [ -f "$XZ" ]; then
    command -v xz >/dev/null 2>&1 || { echo "ERROR: xz not installed"; exit 1; }
    echo ">> Decompressing $XZ -> $TAR"
    xz -dc "$XZ" > "$TAR"
  elif [ -f "$GZ" ]; then
    command -v gzip >/dev/null 2>&1 || { echo "ERROR: gzip not installed"; exit 1; }
    echo ">> Decompressing $GZ -> $TAR"
    gzip -dc "$GZ" > "$TAR"
  elif [ -f "$TAR" ]; then
    : # already have tar
  else
    echo "ERROR: No archive found (expected one of: $ZST, $XZ, $GZ, $TAR)"
    exit 1
  fi
else
  echo ">> Found existing $TAR; skipping decompression"
fi

echo ">> Loading images into Docker from $TAR"
docker load -i "$TAR"

echo ">> Starting services with docker compose"
docker compose up -d

echo "✅ Done."