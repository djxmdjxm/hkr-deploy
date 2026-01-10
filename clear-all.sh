#!/usr/bin/env bash
set -euo pipefail

echo ">> Stopping running Docker containers"
docker compose down

echo ">> Removing hkr/* Docker images"
IMAGES=$(docker images 'hkr/*' -q)

if [ -n "$IMAGES" ]; then
  docker image rm $IMAGES
else
  echo "No hkr/* images found"
fi

echo ">> Removing krebs-db image"
if docker volume inspect krebs-db >/dev/null 2>&1; then
  docker volume rm krebs-db
else
  echo "No such volume: krebs-db"
fi
