#!/usr/bin/env bash

TAG="$(git rev-parse --short=7 HEAD)"

API_IMAGE="marcobuccidev/ristoqueue-api"
WORKER_IMAGE="marcobuccidev/ristoqueue-worker"

# build api
docker build \
  --build-arg GIT_SHA="${TAG}" \
  -t "${API_IMAGE}:${TAG}" \
  -f app/api/Dockerfile .

# build worker
docker build \
  --build-arg GIT_SHA="${TAG}" \
  -t "${WORKER_IMAGE}:${TAG}" \
  -f app/worker/Dockerfile .

{
  echo "Built:"
  echo "  ${API_IMAGE}:${TAG}"
  echo "  ${WORKER_IMAGE}:${TAG}"
} >&2

echo "${TAG}"
