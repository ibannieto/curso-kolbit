#!/usr/bin/env bash
# Descarga las imágenes oficiales usadas en la presentación.
# Las imágenes se versionan en el repositorio (assets/img) para que el build
# del contenedor sea reproducible y no dependa de Internet en tiempo de ejecución.
# Fuentes y licencias: assets/SOURCES.md
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${ROOT}/assets/img"
CNCF="https://raw.githubusercontent.com/cncf/artwork/main"
DOCKER_DOCS="https://raw.githubusercontent.com/docker/docs/main"

fetch() {
  local url="$1" out="$2"
  mkdir -p "$(dirname "${out}")"
  echo "→ ${out#"${ROOT}/"}"
  curl -fsSL --retry 3 -o "${out}" "${url}"
}

# Logos oficiales
fetch "${DOCKER_DOCS}/assets/icons/Whale.svg"                                         "${DEST}/logos/docker.svg"
fetch "${CNCF}/projects/kubernetes/icon/color/kubernetes-icon-color.svg"              "${DEST}/logos/kubernetes.svg"
fetch "${CNCF}/projects/kubernetes/horizontal/color/kubernetes-horizontal-color.svg"  "${DEST}/logos/kubernetes-horizontal.svg"
fetch "${CNCF}/projects/containerd/horizontal/color/containerd-horizontal-color.svg"  "${DEST}/logos/containerd.svg"
fetch "${CNCF}/projects/podman-container-tools/icon/color/podman-icon-color.svg"      "${DEST}/logos/podman.svg"
fetch "${CNCF}/projects/helm/icon/color/helm-icon-color.svg"                          "${DEST}/logos/helm.svg"
fetch "${CNCF}/projects/cilium/icon/color/cilium_icon-color.svg"                      "${DEST}/logos/cilium.svg"
fetch "${CNCF}/projects/prometheus/icon/color/prometheus-icon-color.svg"              "${DEST}/logos/prometheus.svg"
fetch "${CNCF}/other/cncf/horizontal/color/cncf-color.svg"                            "${DEST}/logos/cncf.svg"

# El icono de la documentación de Docker no trae color: aplicamos el azul de marca
sed -i 's|<svg |<svg fill="#1D63ED" |' "${DEST}/logos/docker.svg"

# Phippy & friends (CNCF) — personajes oficiales para explicar Kubernetes
for p in phippy captain_kube zee goldie; do
  fetch "${CNCF}/other/phippy-and-friends/${p}_full.svg" "${DEST}/phippy/${p}.svg"
done
fetch "${CNCF}/other/phippy-and-friends/group/color/group-color.svg" "${DEST}/phippy/group.svg"

echo "✔ Assets descargados en ${DEST}"
