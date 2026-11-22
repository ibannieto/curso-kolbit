#!/usr/bin/env bash
# Smoke test de la presentación servida por nginx.
#   scripts/smoke-test.sh http://localhost:8080
set -euo pipefail
BASE="${1:-http://localhost:8080}"
fail=0

check() {
  local path="$1" expect_type="$2" expect_body="${3:-}"
  local headers bodyfile code ctype
  headers="$(mktemp)"
  bodyfile="$(mktemp)"
  curl -sS -D "${headers}" -o "${bodyfile}" "${BASE}${path}" || { echo "✖ ${path}: sin respuesta"; fail=1; return; }
  code="$(awk 'NR==1{print $2}' "${headers}")"
  ctype="$(grep -i '^content-type:' "${headers}" | tr -d '\r' | cut -d' ' -f2-)"
  if [[ "${code}" != "200" ]]; then
    echo "✖ ${path}: HTTP ${code}"; fail=1
  elif [[ "${ctype}" != ${expect_type}* ]]; then
    echo "✖ ${path}: content-type '${ctype}' (esperado ${expect_type})"; fail=1
  elif [[ -n "${expect_body}" ]] && ! grep -qF -- "${expect_body}" "${bodyfile}"; then
    echo "✖ ${path}: no contiene '${expect_body}'"; fail=1
  else
    echo "✔ ${path} (${ctype})"
  fi
  rm -f "${headers}" "${bodyfile}"
}

check /healthz              text/plain        ok
check /                     text/html         'data-markdown="slides/00-bienvenida.md"'
check /version.json         application/json  '"sha"'
check /slides/00-bienvenida.md text/markdown  'Docker & Kubernetes'
check /css/kolbit.css       text/css          'JetBrains Mono'
check /vendor/reveal/reveal.js application/javascript
check /vendor/fonts/jetbrains-mono-latin-400-normal.woff2 font/woff2
check /assets/img/logos/kubernetes.svg image/svg+xml

# Cabeceras de seguridad
if curl -sSI "${BASE}/" | grep -qi '^content-security-policy:'; then
  echo "✔ Content-Security-Policy presente"
else
  echo "✖ Falta Content-Security-Policy"; fail=1
fi

# Todos los módulos enlazados en index.html existen
while read -r md; do
  check "/${md}" text/markdown
done < <(curl -sS "${BASE}/" | grep -o 'slides/[0-9][0-9]-[a-z0-9-]*\.md')

if (( fail )); then
  echo "SMOKE TEST: FALLO"; exit 1
fi
echo "SMOKE TEST: OK"
