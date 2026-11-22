# Desarrollo local

## Requisitos

- Node.js 24 o superior. La imagen de build usa Node 26 LTS.
- podman 5 o superior (o Docker con `ENGINE=docker`).
- Opcionales: `yamllint`, `shellcheck`, `kubeconform`, `hadolint`, `actionlint`
  y `gitleaks`. Si no están instalados, el `Makefile` usa sus imágenes de
  contenedor con versión fijada.

## Editar la presentación

```bash
make install   # npm ci
make dev       # build y servidor en http://localhost:8000 que reconstruye al guardar
```

- Cada módulo es un fichero `slides/NN-nombre.md`. Se cargan en orden
  alfabético, así que para añadir uno basta con crear el fichero.
- Las reglas de formato, las clases CSS y los memes están en
  [convenciones-slides.md](convenciones-slides.md).
- El tema está en `slides/css/kolbit.css`, como capa sobre el tema `black` de
  reveal.js.
- `make stats` cuenta las diapositivas y estima la duración. El objetivo es
  mantener unas 200 diapositivas, que dan unas 9 o 10 h de exposición.

## Cómo se genera la web

`scripts/build.mjs` (sin dependencias) crea `dist/`:

1. Copia `reveal.js/dist` (JS, CSS, temas y plugins) a `dist/vendor/reveal`.
2. Copia las fuentes woff2 de `@fontsource` a `dist/vendor/fonts`. Son
   **Atkinson Hyperlegible Next** para el texto y **JetBrains Mono** para el
   código.
3. Copia `slides/*.md`, `slides/css` y `assets/`.
4. Inyecta en `index.html` una `<section data-markdown>` por módulo.
5. Genera `healthz` y `version.json` para Kubernetes y los smoke tests.

Todo lo necesario va dentro de la imagen: no se carga nada de CDNs ni de Google
Fonts en tiempo de ejecución.

## Imágenes oficiales

`make assets` vuelve a descargar los logos y las ilustraciones de sus fuentes
oficiales (`scripts/fetch-assets.sh`). Los ficheros se versionan en
`assets/img` para que el build sea reproducible. Las fuentes y licencias están
en [assets/SOURCES.md](../assets/SOURCES.md).

## Calidad

```bash
make lint          # markdownlint, yamllint, hadolint, kubeconform, shellcheck y actionlint
make hooks         # activa .githooks/pre-commit (lint de los ficheros en stage y gitleaks)
make secrets-scan  # gitleaks sobre todo el historial
```

## Probar el contenedor

```bash
make image         # podman build (TAG = commit corto, con -dirty si hay cambios sin commitear)
make run           # contenedor de solo lectura, sin capabilities, en http://localhost:8080
make smoke         # comprueba los endpoints, los content-types y las cabeceras de seguridad
make shots         # capturas PNG de todas las diapositivas en output/shots
make shots SLIDES=40-60
make stop
```

## Problemas conocidos

- **Podman rootless y decktape:** los scripts usan `--userns=keep-id` para que
  Chromium pueda escribir el PDF en el directorio montado.
- **nginx y `types {}`:** un bloque `types` a nivel de `server` sustituye todo
  `mime.types` y hace que el HTML se sirva como descarga. Por eso el tipo
  `text/markdown` se define solo en `location ~* \.md$`.
- **nginx y `add_header`:** un `add_header` dentro de un `location` anula los
  heredados. Por eso `Cache-Control` se calcula con un `map`.
