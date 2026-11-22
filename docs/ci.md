# Integración continua

## Situación actual: CI local

Los minutos de GitHub Actions están agotados, así que **todo se ejecuta en
local**:

```bash
make ci        # lint, build, imagen, contenedor y smoke test
make release   # ci y push a GHCR
make hooks     # hook pre-commit: markdownlint, yamllint, shellcheck y gitleaks sobre lo que va en stage
```

| Paso | Herramienta |
| --- | --- |
| Markdown | markdownlint-cli2 (`.markdownlint-cli2.jsonc`) |
| YAML | yamllint (`.yamllint.yaml`) |
| Dockerfile | hadolint 2.15 (`.hadolint.yaml`) |
| Manifiestos | kubeconform contra Kubernetes 1.37 |
| Shell | shellcheck |
| Workflows | actionlint |
| Secretos | gitleaks (`make secrets-scan` y hook) |
| Imagen | `podman build` y smoke test HTTP (`scripts/smoke-test.sh`) |

## GitHub Actions (desactivado)

`.github/workflows/ci.yml` hace lo mismo que `make ci` y puede además publicar
la imagen y adjuntar el PDF como artefacto. Está desactivado de dos formas:

1. **Solo tiene el disparador `workflow_dispatch`**: los disparadores
   `push` y `pull_request` están comentados.
2. **El workflow está deshabilitado** en GitHub (`gh workflow disable ci.yml`).

### Activarlo más adelante

```bash
gh workflow enable ci.yml
# Mueve los disparadores push/pull_request comentados dentro de "on:" en ci.yml
gh workflow run ci.yml -f push_image=true    # ejecución manual
```

Al activarlo, el paquete de GHCR debe dar permiso de escritura al repositorio:
Package settings → Manage Actions access → `curso-kolbit` (Write).
