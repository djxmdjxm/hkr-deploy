#!/usr/bin/env bash
# deploy.sh — KIKA Deployment-Skript (laeuft auf ubuntu-ai)
# Aufruf: ~/deploy.sh [web|api|worker|all]
set -euo pipefail

REPO_BASE="/media/christopher-mangels/4TB/projectClones/kika"
COMPOSE_DIR="$REPO_BASE/kika"
COMPOSE_OPTS="-p hkr-clean -f $COMPOSE_DIR/docker-compose.yml"

deploy_web() {
  echo ">> Deploying krebs-web..."
  cd "$REPO_BASE/hkr-krebs-web"
  git stash || true
  git pull
  BUILD_VERSION=$(date +%Y%m%d-%H%M)
  docker build --build-arg BUILD_VERSION="$BUILD_VERSION" -t hkr/krebs-web:latest .
  docker compose $COMPOSE_OPTS up -d --force-recreate --no-build krebs-web
  echo "✅ krebs-web Version: $BUILD_VERSION deployed"
}

deploy_api() {
  echo ">> Deploying krebs-api..."
  cd "$REPO_BASE/hkr-krebs-api"
  git stash || true
  git pull
  docker build -t hkr/krebs-api:latest .
  docker compose $COMPOSE_OPTS up -d --force-recreate --no-build krebs-api
  echo "✅ krebs-api deployed"
}

deploy_worker() {
  echo ">> Deploying import-worker..."
  cd "$REPO_BASE/hkr-import-worker"
  git stash || true
  git pull
  docker build -t hkr/import-worker:latest .
  docker compose $COMPOSE_OPTS up -d --force-recreate --no-build import-worker
  echo "✅ import-worker deployed"
}

deploy_rstudio() {
  echo ">> Deploying rstudio-server..."
  cd "$REPO_BASE/hkr-deploy"
  git stash || true
  git pull
  docker build -t hkr/rstudio-server:latest ./rstudio-server/
  docker compose $COMPOSE_OPTS up -d --force-recreate --no-build krebs-code
  echo "✅ rstudio-server deployed"
}

case "${1:-}" in
  web)     deploy_web ;;
  api)     deploy_api ;;
  worker)  deploy_worker ;;
  rstudio) deploy_rstudio ;;
  all)     deploy_web && deploy_api && deploy_worker && deploy_rstudio ;;
  *)
    echo "Usage: deploy.sh [web|api|worker|rstudio|all]"
    exit 1
    ;;
esac
