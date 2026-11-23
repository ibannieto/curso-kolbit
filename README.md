# Curso Docker & Kubernetes & CaaS

Material del curso **Docker, Kubernetes y Containers as a Service**: 37 h
lectivas, del 23/11/2026 al 01/12/2026, por Microsoft Teams. Profesor: Iban
Nieto Castillero.

- **Presentación:** [reveal.js](https://revealjs.com/) 6 escrita en Markdown
  (`slides/`), empaquetada en un contenedor nginx sin privilegios y desplegada
  en Kubernetes.
- **Laboratorios:** guías paso a paso en [`labs/`](labs/README.md).
- **App de ejemplo:** [`examples/contador`](examples/contador), una API en
  Python con Redis que recorre todo el curso.
- **PDF para los alumnos:** `make pdf`.
- **Publicada en:** <https://curso.malaleche.xyz>, desplegada con Flux desde
  `belters-apps`.

## Inicio rápido

```bash
make install        # dependencias npm (reveal.js, fuentes, markdownlint)
make dev            # http://localhost:8000 con recarga automática
make image run      # contenedor con podman en http://localhost:8080
make pdf            # output/curso-kolbit.pdf
make help           # todos los objetivos
```

Requisitos: Node.js 24 o superior, podman (o Docker con `ENGINE=docker`) y
`make`. Para desplegar hacen falta `kubectl` y `gh`.

## Estructura

```text
slides/            Diapositivas (un .md por módulo), index.html y tema CSS
assets/img/        Logos oficiales y Phippy & friends (CNCF), ver assets/SOURCES.md
labs/              Laboratorios (lab-00 … lab-18)
examples/contador/ App de ejemplo: Dockerfile, compose.yaml y manifiestos k8s
k8s/               Despliegue didáctico de la presentación (Kustomize: base + overlay kind)
nginx/             Configuración de nginx para servir la presentación
scripts/           build, servidor de desarrollo, smoke test, PDF, assets…
docs/              Planificación, convenciones, versiones, desarrollo, despliegue, CI
.github/workflows/ CI de GitHub Actions (desactivado de momento)
.githooks/         Hook pre-commit (make hooks)
```

## Flujo de trabajo

| Tarea | Comando | Documentación |
| --- | --- | --- |
| Editar diapositivas | `make dev` | [docs/desarrollo.md](docs/desarrollo.md), [docs/convenciones-slides.md](docs/convenciones-slides.md) |
| Comprobar la calidad | `make lint` | [docs/desarrollo.md](docs/desarrollo.md) |
| Pipeline local completo | `make ci` | [docs/ci.md](docs/ci.md) |
| Publicar la imagen en GHCR | `make login` y luego `make push` | [docs/despliegue.md](docs/despliegue.md) |
| Desplegar (GitOps en `belters-apps`) | `make deploy PUSH=1` | [docs/despliegue.md](docs/despliegue.md) |
| Generar el PDF | `make pdf` | [docs/pdf.md](docs/pdf.md) |

La imagen se **construye y se publica desde el equipo local** con podman, no
desde GitHub Actions, porque los minutos de Actions están agotados. El workflow
de CI existe pero está desactivado (ver [docs/ci.md](docs/ci.md)).

## Planificación

Consulta [docs/planificacion.md](docs/planificacion.md) para el calendario
por días, el presupuesto de diapositivas y el hilo conductor. Las versiones de
referencia (Docker 29, Kubernetes 1.37, Helm 4…) están en
[docs/versiones.md](docs/versiones.md).

## Atajos de la presentación

| Tecla | Acción |
| --- | --- |
| `S` | Vista del ponente con notas y temporizador |
| `O` / `Esc` | Vista general de las diapositivas |
| `F` | Pantalla completa |
| `Ctrl+Shift+F` | Buscar |
| `Alt+clic` | Zoom |
| `?print-pdf` | Vista de impresión (la usa la exportación a PDF) |

## Licencias

Los logos y las ilustraciones pertenecen a sus respectivos propietarios. Se usan
según sus guías de marca y licencias, recogidas en
[assets/SOURCES.md](assets/SOURCES.md).
