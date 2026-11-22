#!/usr/bin/env bash
# Exporta la presentación a PDF con decktape (Chromium headless en contenedor).
# Requiere el contenedor de la presentación corriendo en la red $NETWORK
# (lo arranca `make run`; `make pdf` lo hace automáticamente).
#   scripts/pdf.sh [output/curso-kolbit.pdf]
set -euo pipefail
OUT="${1:-output/curso-kolbit.pdf}"
ENGINE="${ENGINE:-podman}"
NETWORK="${NETWORK:-kolbit}"
CONTAINER="${CONTAINER:-curso-kolbit}"
DECKTAPE_IMAGE="${DECKTAPE_IMAGE:-ghcr.io/astefanutti/decktape:3.17.0}"

dir="$(dirname "${OUT}")"
file="$(basename "${OUT}")"
mkdir -p "${dir}"

userns=()
# En podman rootless, keep-id permite que decktape escriba en el directorio montado
[[ "${ENGINE}" == "podman" ]] && userns=(--userns=keep-id)

echo "→ Generando ${OUT} desde http://${CONTAINER}:8080/ ..."
"${ENGINE}" run --rm --network "${NETWORK}" "${userns[@]}" \
  -v "$(realpath "${dir}")":/out:z \
  "${DECKTAPE_IMAGE}" reveal \
  --size 1280x720 \
  --pause 300 \
  --load-pause 1500 \
  "http://${CONTAINER}:8080/" "/out/${file}" | tail -n 1

echo "✔ PDF: ${OUT} ($(du -h "${OUT}" | cut -f1))"
