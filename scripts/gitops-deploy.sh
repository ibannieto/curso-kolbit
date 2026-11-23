#!/usr/bin/env bash
# Despliegue GitOps de la presentación en el clúster belters.
#
# La app la gestiona Flux desde el repositorio belters-apps
# (apps/curso-kolbit/curso-kolbit.yaml). Un `kubectl apply` directo se revierte
# en la siguiente reconciliación, así que desplegar = cambiar el digest en git.
#
#   scripts/gitops-deploy.sh ghcr.io/ibannieto/curso-kolbit <tag>
#
# Variables:
#   BELTERS_APPS  clon local de belters-apps (por defecto ../belters-apps)
#   PUSH=1        además hace push, reconcilia Flux y espera al rollout
set -euo pipefail

IMAGE="${1:?uso: gitops-deploy.sh IMAGEN TAG}"
TAG="${2:?uso: gitops-deploy.sh IMAGEN TAG}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="${BELTERS_APPS:-${ROOT}/../belters-apps}"
MANIFEST="apps/curso-kolbit/curso-kolbit.yaml"
NS="curso-kolbit"

[[ -d "${REPO}/.git" ]] || { echo "✖ No encuentro belters-apps en ${REPO} (usa BELTERS_APPS=...)"; exit 1; }
cd "${REPO}"

branch="$(git rev-parse --abbrev-ref HEAD)"
[[ "${branch}" == "main" ]] || { echo "✖ ${REPO} está en la rama ${branch}, no en main"; exit 1; }
git diff --quiet HEAD || { echo "✖ ${REPO} tiene cambios sin commitear"; exit 1; }
git pull -q --ff-only origin main

digest="$(skopeo inspect --format '{{.Digest}}' "docker://${IMAGE}:${TAG}")" || {
  echo "✖ ${IMAGE}:${TAG} no está en el registro (o no hay login). Ejecuta: make login push"; exit 1; }
ref="${IMAGE}:${TAG}@${digest}"

current="$(grep -oE "image: ${IMAGE}:[^[:space:]]+" "${MANIFEST}" | cut -d' ' -f2)"
[[ -n "${current}" ]] || { echo "✖ No encuentro la línea image: de ${IMAGE} en ${MANIFEST}"; exit 1; }

if [[ "${current}" == "${ref}" ]]; then
  echo "✔ belters-apps ya apunta a ${TAG} (${digest:0:19}…): nada que commitear"
else
  sed -i "s|image: ${current}|image: ${ref}|" "${MANIFEST}"
  git add "${MANIFEST}"
  # Convención de belters-apps: "Deploy <app> <sha>", sin atribución de IA (hook no-ai-attribution)
  git commit -q -m "Deploy curso-kolbit ${TAG}" \
    -m "Image built locally from curso-kolbit@${TAG} and pushed to GHCR."
  echo "✔ Commit en belters-apps: $(git log --oneline -1)"
fi

if git status -sb | head -1 | grep -q 'ahead'; then
  if [[ "${PUSH:-0}" == "1" ]]; then
    git push -q origin main
    flux reconcile kustomization apps --with-source
    kubectl -n "${NS}" rollout status deploy/curso-kolbit --timeout=180s
    echo "✔ Desplegado ${TAG}"
  else
    echo
    echo "Falta publicarlo (es el repositorio GitOps de producción):"
    echo "  git -C ${REPO} push origin main && flux reconcile kustomization apps --with-source"
    echo "o vuelve a lanzar: make deploy PUSH=1"
  fi
fi
