#!/usr/bin/env bash
# Uso: ./scripts/deploy.sh <TAG>
set -euo pipefail                             

TAG="${1:?Uso: $0 <TAG>}"                     # se manca il tag: messaggio ed errore
CHART="$(dirname "$0")/../k8s/ristoqueue"     # percorso del chart, da qualsiasi cartella

helm upgrade --install ristoqueue "$CHART" \
  --namespace ristoqueue --create-namespace \
  --set-string tag="$TAG" \
  --wait --timeout 2m
