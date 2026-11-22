#!/usr/bin/env bash
# Espera a que una URL responda 2xx (por defecto 30 s).
#   scripts/wait-for.sh http://localhost:8080/healthz [segundos]
set -euo pipefail
URL="${1:?uso: wait-for.sh URL [timeout]}"
TIMEOUT="${2:-30}"
for ((i = 0; i < TIMEOUT * 2; i++)); do
  if curl -fsS -o /dev/null "${URL}" 2>/dev/null; then
    exit 0
  fi
  sleep 0.5
done
echo "✖ ${URL} no responde tras ${TIMEOUT}s" >&2
exit 1
