#!/usr/bin/env bash
# Renderiza capturas PNG de la presentación (todas o un rango) para revisión visual.
#   scripts/render-check.sh [RANGO] [DIR]     p.ej.  scripts/render-check.sh 1-20 output/shots
# Requiere que el contenedor de la presentación esté corriendo en la red "kolbit"
# (lo arranca `make run`), y usa la imagen de decktape.
set -euo pipefail
RANGE="${1:-}"
OUT="${2:-output/shots}"
ENGINE="${ENGINE:-podman}"
DECKTAPE_IMAGE="${DECKTAPE_IMAGE:-ghcr.io/astefanutti/decktape:3.17.0}"
NAME="${CONTAINER_NAME:-curso-kolbit}"
mkdir -p "${OUT}"
args=(reveal --size 1280x720 --screenshots --screenshots-directory /out)
[[ -n "${RANGE}" ]] && args+=(--slides "${RANGE}")
userns=()
[[ "${ENGINE}" == "podman" ]] && userns=(--userns=keep-id)
"${ENGINE}" run --rm --network kolbit "${userns[@]}" -v "$(realpath "${OUT}")":/out:z \
  "${DECKTAPE_IMAGE}" "${args[@]}" "http://${NAME}:8080/" /out/shots.pdf >/dev/null
rm -f "${OUT}/shots.pdf"
echo "✔ Capturas en ${OUT}/"
