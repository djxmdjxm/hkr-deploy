#!/usr/bin/env bash
set -euo pipefail

## Choose chip architecture
case "$(uname -m)" in
  x86_64)        CURRENT_ARCH="amd64" ;;
  aarch64|arm64) CURRENT_ARCH="arm64" ;;
  *)             CURRENT_ARCH="$(uname -m)" ;;
esac
ARCH=${1:-$CURRENT_ARCH}
PLATFORM="linux/${ARCH}"

docker build --platform $PLATFORM -t hkr/central-db:latest ./central-db
docker build --platform $PLATFORM -t hkr/job-queue:latest ./job-queue
docker build --platform $PLATFORM -t hkr/ingress:latest ./ingress
docker build --platform $PLATFORM --build-arg SUDO_PASSWORD=123456 --build-arg USER_PASSWORD=1234 -t hkr/krebs-code:latest ./code-server

docker build --platform $PLATFORM -t hkr/import-worker:latest ../import-worker
docker build --platform $PLATFORM -t hkr/krebs-api:latest ../krebs-api
docker build --platform $PLATFORM -t hkr/krebs-web:latest ../krebs-web

docker build --platform $PLATFORM -t hkr/krebs-db-migrations:latest ../krebs-db-migrations
docker build --platform $PLATFORM -t hkr/main-db-migrations:latest ../main-db-migrations

echo ">> Built Docker images for $PLATFORM platform"

## Archive and compress all images
DEPLOY_DIR="../kika"

DUMP_FILE_DIR="$DEPLOY_DIR/$ARCH"
mkdir -p "$DUMP_FILE_DIR"

DUMP_FILE="$DUMP_FILE_DIR/hkr-images.tar"

echo ">> Saving Docker images to " $DUMP_FILE
docker save -o $DUMP_FILE $(docker images --filter=reference='hkr/*' --format '{{.Repository}}:{{.Tag}}')

if command -v zstd >/dev/null 2>&1; then
  echo ">> Compressing with zstd"
  zstd -19 -T0 --rm -f $DUMP_FILE   # produces hkr-images.tar.zst, keeps original
elif command -v xz >/dev/null 2>&1; then
  echo ">> Compressing with xz"
  xz -T0 -9 -f $DUMP_FILE      # produces hkr-images.tar.xz, keeps original
elif command -v gzip >/dev/null 2>&1; then
  echo ">> Compressing with gzip"
  gzip -9 -f $DUMP_FILE        # produces hkr-images.tar.gz, keeps original
else
  echo "Error: no compression tool (zstd/xz/gzip) found." >&2
  exit 1
fi

## Copy supporting files
echo ">> Copying supporting scripts to $DEPLOY_DIR"
cp clear-all.sh run-all.sh $DEPLOY_DIR

echo ">> Copying docker-compose.prd.yml to $DEPLOY_DIR"
cp docker-compose.prd.yml $DEPLOY_DIR/docker-compose.yml

## Clean Up
echo ">> Removing hkr/* Docker images"
IMAGES=$(docker images 'hkr/*' -q)
if [ -n "$IMAGES" ]; then
  docker image rm $IMAGES
else
  echo "No hkr/* images found"
fi

echo "✅ Done."