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

docker build --platform $PLATFORM -t hkr/import-worker:latest ../import-worker
docker build --platform $PLATFORM -t hkr/krebs-api:latest ../krebs-api
docker build --platform $PLATFORM -t hkr/krebs-web:latest ../krebs-web

docker build --platform $PLATFORM -t hkr/krebs-db-migrations:latest ../krebs-db-migrations
docker build --platform $PLATFORM -t hkr/main-db-migrations:latest ../main-db-migrations


echo ">> Built Docker images for" $PLATFORM
