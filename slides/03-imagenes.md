<!-- .slide: class="module center-v" -->

<span class="kicker">Módulo 3 · Día 3</span>

# Construcción de imágenes Docker

<div class="agenda">

Empaquetar aplicaciones · Dockerfile · Caché y BuildKit · Multi-stage · Imágenes base · Datos · Buenas prácticas

</div>

---

<!-- .slide: class="docker" -->

## Empaquetar una aplicación

¿Qué necesita la app **contador** para ejecutarse?

<div class="cols">
<div>

1. Un **runtime**: Python 3.15
2. **Dependencias**: `redis==8.1.0`
3. El **código**: `app.py`
4. **Cómo arrancar**: `python app.py`
5. **Configuración**: variables de entorno

</div>
<div>

<div class="box tip">

El Dockerfile es la **receta reproducible** que convierte esta lista en una imagen.

</div>

</div>
</div>

---

<!-- .slide: class="docker" -->

## Un primer Dockerfile (ingenuo)

```dockerfile
FROM python:3.15
COPY . /app
WORKDIR /app
RUN pip install -r requirements.txt
CMD python app.py
```

```bash
docker build -t contador:naive .
docker image ls contador
```

<div class="fragment">

Funciona… pero ocupa **1,17 GB**, corre como **root**, rompe la caché en cada cambio y no recibe bien las señales.

</div>

---

<!-- .slide: class="docker" -->

## Instrucciones básicas

| Instrucción | Para qué |
| --- | --- |
| `FROM` | Imagen base (y nombre de etapa: `AS build`) |
| `RUN` | Ejecuta comandos en build y crea una capa |
| `COPY` | Copia ficheros del contexto a la imagen |
| `WORKDIR` | Directorio de trabajo (lo crea si no existe) |
| `ENV` / `ARG` | Variables de runtime / variables de build |
| `EXPOSE` | Documenta el puerto (no lo publica) |
| `USER` | Usuario con el que corre el proceso |
| `ENTRYPOINT` / `CMD` | Qué se ejecuta al arrancar |

---

<!-- .slide: class="docker" -->

## `COPY` vs. `ADD`

<div class="cols">
<div>

**`COPY`** ✔

- Copia ficheros y directorios
- Predecible
- `--chown`, `--chmod`, `--from=etapa`

</div>
<div>

**`ADD`** ⚠

- Además, **descomprime** tar locales
- Y descarga **URLs** (y desde git)
- Úsalo solo cuando necesites eso, con `--checksum`

</div>
</div>

<p class="meme-caption">¿Dudas entre <code>ADD</code> y <code>COPY</code>? Es <code>COPY</code>.</p>

---

<!-- .slide: class="docker" -->

## `ENV` vs. `ARG`

```dockerfile
ARG PYTHON_VERSION=3.15.2            # solo en build (antes de FROM: parametriza la base)
FROM python:${PYTHON_VERSION}-slim

ARG APP_VERSION=dev                  # docker build --build-arg APP_VERSION=1.0.0
ENV APP_VERSION=${APP_VERSION} \
    PYTHONUNBUFFERED=1               # disponible en runtime
```

- `ARG` desaparece tras el build (aunque queda en `docker history`)
- `ENV` persiste en la imagen y se puede sobrescribir con `docker run -e`
- **Nunca** pases secretos por `ARG` ni `ENV`

---

<!-- .slide: class="docker" -->

## `ENTRYPOINT` y `CMD`

```dockerfile
ENTRYPOINT ["python", "app.py"]      # el ejecutable fijo
CMD ["--port", "8080"]               # argumentos por defecto (sobrescribibles)
```

```bash
docker run contador                  # python app.py --port 8080
docker run contador --port 9090      # python app.py --port 9090
docker run --entrypoint sh -it contador
```

<div class="box warn">

Usa la **forma exec** (`["..."]`). La forma shell (`CMD python app.py`) lanza `/bin/sh -c`: tu app no es PID 1 y **no recibe SIGTERM**.

</div>

---

<!-- .slide: class="docker" -->

## `HEALTHCHECK` y etiquetas OCI

```dockerfile
LABEL org.opencontainers.image.title="contador" \
      org.opencontainers.image.source="https://github.com/ibannieto/curso-kolbit" \
      org.opencontainers.image.version="1.0.0"

HEALTHCHECK --interval=10s --timeout=2s --retries=3 \
  CMD ["python", "-c", \
       "import urllib.request as u; u.urlopen('http://127.0.0.1:8080/healthz')"]
```

- `docker ps` mostrará `(healthy)` / `(unhealthy)`
- **Kubernetes ignora `HEALTHCHECK`**: allí se usan *probes* (día 5)
- Las etiquetas OCI enlazan la imagen con su código fuente (GHCR las usa)

---

<!-- .slide: class="docker" -->

## Contexto de build y `.dockerignore`

```bash
docker build -t contador:dev .        # «.» es el CONTEXTO: se envía al builder
```

```text
# .dockerignore
.git
__pycache__/
*.pyc
.venv/
.env
compose.yaml
k8s/
```

- Lo que no está en el contexto no se puede `COPY`
- Contexto pequeño = build más rápido y **sin secretos** colados (`.env`, `.git`)

---

<!-- .slide: class="docker" -->

## La caché de capas

- Cada instrucción genera una capa **cacheada**
- Si una instrucción cambia (o los ficheros que copia), **se invalidan esa capa y todas las siguientes**
- Ordena de **lo que menos cambia** a **lo que más cambia**

```dockerfile
COPY requirements.txt .              # cambia poco → caché
RUN pip install -r requirements.txt  # solo se repite si cambian las dependencias
COPY app.py .                        # cambia mucho → al final
```

---

<!-- .slide: class="meme" -->

<div class="meme-two">
<div>
<span class="tag">Yo cambiando una coma en app.py</span>

`COPY . /app`

`RUN pip install …`

</div>
<div>
<span class="tag">El builder</span>

Reinstalando **todas** las dependencias.

Otra vez. ☕☕☕

</div>
</div>

<p class="meme-caption">El orden de las instrucciones importa.</p>

---

<!-- .slide: class="docker" -->

## BuildKit: cache mounts y secretos

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.15.2-slim
WORKDIR /app
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

# El secreto se monta solo durante este RUN: no queda en ninguna capa
RUN --mount=type=secret,id=pip_token \
    PIP_INDEX_URL="https://user:$(cat /run/secrets/pip_token)@pypi.example.com/simple" \
    pip install paquete-privado
```

```bash
docker build --secret id=pip_token,src=./token.txt -t contador:dev .
```

---

<!-- .slide: class="docker" -->

## Multi-plataforma con buildx

```bash
docker buildx create --name multi --use
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/USUARIO/contador:1.0.0 \
  --push .

docker buildx imagetools inspect ghcr.io/USUARIO/contador:1.0.0
```

- Una misma etiqueta y un **índice** con una imagen por arquitectura
- Útil para Mac con Apple Silicon, nodos Graviton/Ampere y Raspberry Pi
- Emula con QEMU o usa builders nativos

---

<!-- .slide: class="docker" -->

## Multi-stage builds

```dockerfile
FROM python:3.15.2-slim AS build
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.15.2-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY --from=build /install /usr/local
COPY app.py .
USER 10001:10001
EXPOSE 8080
CMD ["python", "app.py"]
```

<small>`examples/contador/Dockerfile` · las herramientas de build se quedan en la etapa `build`</small>

---

<!-- .slide: class="docker" -->

## Multi-stage brilla con lenguajes compilados

```dockerfile
FROM golang:1.27 AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /app ./cmd/server

FROM gcr.io/distroless/static-debian13:nonroot
COPY --from=build /app /app
ENTRYPOINT ["/app"]
```

<small>Imagen de ~1 GB con el compilador → imagen final de **~10 MB**</small>

---

<!-- .slide: class="docker" -->

## Resultado: de ingenuo a optimizado

| | `contador:naive` | `contador:dev` |
| --- | --- | --- |
| Base | `python:3.15` | `python:3.15.2-slim` multi-stage |
| Tamaño | **1,17 GB** | **133 MB** |
| Usuario | root | 10001 (no root) |
| Caché de dependencias | Se rompe con cada cambio | Se reutiliza |
| Señales (SIGTERM) | `sh -c` se las come | Forma exec + manejador |
| Healthcheck | No | Sí |

<small>Medido en el portátil del profesor con Podman 6.2</small>

---

<!-- .slide: class="meme" -->

<div class="meme-bubble">
  <img src="assets/img/phippy/goldie.svg" alt="Goldie">
  <div class="bubble">
    ¿1,17 GB para un «hola mundo»?<br>
    Eso no es una imagen, es una mudanza.
    <small>Goldie · Phippy and Friends · CNCF</small>
  </div>
</div>

---

<!-- .slide: class="docker" -->

## Elegir la imagen base

| Base | Tamaño | Shell / gestor de paquetes | Notas |
| --- | --- | --- | --- |
| `debian` / `python:3.15` | Grande | Sí | Cómoda, muchas CVE |
| `*-slim` | Media | Sí | Buen equilibrio (glibc) |
| `alpine` | Pequeña | Sí (apk) | musl: ojo con wheels y DNS |
| `distroless` | Muy pequeña | **No** | Solo runtime; `:debug` para depurar |
| `scratch` | 0 | No | Binarios estáticos |

- Imágenes endurecidas con pocas CVE: **Chainguard Images**, **Docker Hardened Images**
- Lo importante: **base mínima, actualizada y de origen fiable**… y **medir** (más pequeña ≠ menos CVE)

---

<!-- .slide: class="docker" -->

## Fija versiones… de verdad

```dockerfile
FROM python:3.15                       # ✖ cambia cuando sale la 3.15.x
FROM python:3.15.2-slim                # ✔ versión concreta
FROM python:3.15.2-slim@sha256:9d2c…   # ✔✔ inmutable (Renovate/Dependabot lo actualizan)
```

<div class="box warn">

**Lección de 2025:** Bitnami retiró su catálogo gratuito de imágenes versionadas (lo movió a `bitnamilegacy`). Quien dependía de `bitnami/postgresql:latest` se encontró los despliegues rotos de un día para otro.

</div>

Note:
Moraleja: fija versiones, replica las imágenes críticas en un registro propio (Harbor, GHCR) y vigila de quién dependes.

---

<!-- .slide: class="lab" -->

## Lab 06 · Escribir el Dockerfile de contador

- Partir del Dockerfile ingenuo y medirlo
- Reordenar para aprovechar la caché
- Forma exec, `HEALTHCHECK` y etiquetas OCI
- Comprobar que `docker stop` es inmediato

<small>⏱ 75 min · `labs/lab-06-dockerfile.md`</small>

---

<!-- .slide: class="docker" -->

## Datos en contenedores: estrategias

- **Stateless por diseño**: el contenedor no guarda nada importante
- El estado vive **fuera**: base de datos, Redis, almacenamiento de objetos (S3)
- Si hay estado local: **volumen** montado en una ruta conocida (`VOLUME /data` lo documenta)
- **Configuración**: variables de entorno o ficheros montados, nunca horneada
- **Logs**: a stdout/stderr, no a ficheros dentro del contenedor

---

<!-- .slide: class="docker" -->

## Backup y restauración de un volumen

```bash
# Backup: un contenedor auxiliar monta el volumen y lo empaqueta
docker run --rm \
  -v redis-data:/data:ro \
  -v "$PWD":/backup \
  alpine:3.24 tar czf /backup/redis-data.tgz -C /data .

# Restaurar en un volumen nuevo
docker volume create redis-data-restore
docker run --rm -v redis-data-restore:/data -v "$PWD":/backup \
  alpine:3.24 tar xzf /backup/redis-data.tgz -C /data
```

<small>Para bases de datos, mejor su herramienta nativa (`pg_dump`, `redis-cli --rdb`…): consistencia garantizada.</small>

---

<!-- .slide: class="docker" -->

## Buenas prácticas (I): seguridad

- **No root**: `USER 10001` (y en Kubernetes, `runAsNonRoot: true`)
- **Sin secretos** en la imagen: ni `ENV`, ni `ARG`, ni ficheros copiados
- **Base mínima** y actualizada: menos paquetes, menos CVE
- **Fija versiones** de la base y de las dependencias
- **Sistema de ficheros de solo lectura** cuando sea posible (`--read-only`)

---

<!-- .slide: class="docker" -->

## Buenas prácticas (II): diseño

- **Un proceso por contenedor** (y que sea PID 1 o use `--init`/`tini`)
- **Inmutable**: misma imagen en todos los entornos, configuración por entorno
- **Logs a stdout/stderr**
- **Arranque rápido y parada limpia** (manejar SIGTERM)
- Capas pequeñas: limpia en el **mismo** `RUN` (`apt-get … && rm -rf /var/lib/apt/lists/*`)

---

<!-- .slide: class="docker" -->

## Lint y escaneo

```bash
# Lint del Dockerfile
docker run --rm -i ghcr.io/hadolint/hadolint:v2.15.1 < Dockerfile

# Vulnerabilidades (CVE) de la imagen
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:0.76.2 image --severity HIGH,CRITICAL contador:dev

docker scout cves contador:dev        # integrado en Docker Desktop / CLI
```

<small>Intégralos en CI: el build falla si hay CVE críticas o malas prácticas.</small>

---

<!-- .slide: class="docker" -->

## Cadena de suministro: SBOM y attestations

```bash
docker buildx build \
  --sbom=true --provenance=mode=max \
  -t ghcr.io/USUARIO/contador:1.0.0 --push .

docker buildx imagetools inspect ghcr.io/USUARIO/contador:1.0.0 \
  --format '{{json .SBOM}}' | head
```

- **SBOM**: inventario de paquetes de la imagen (SPDX)
- **Provenance**: cómo, dónde y desde qué commit se construyó (SLSA)
- Firmar imágenes: **cosign** (Sigstore) · verificar en el clúster con Kyverno o Connaisseur

---

<!-- .slide: class="docker" -->

## Checklist de una buena imagen

<div class="cols">
<div>

- ✔ Base mínima con versión fijada
- ✔ Multi-stage
- ✔ `.dockerignore`
- ✔ Orden de capas pensado para la caché
- ✔ Usuario no root

</div>
<div>

- ✔ `CMD`/`ENTRYPOINT` en forma exec
- ✔ Maneja SIGTERM
- ✔ Logs a stdout
- ✔ Sin secretos
- ✔ Lint + escaneo en CI

</div>
</div>

---

<!-- .slide: class="lab" -->

## Lab 07 · Buenas prácticas

- Multi-stage y usuario no root
- Comparar tamaños: naive vs. slim vs. multi-stage
- `hadolint` y `trivy` desde contenedores
- Un `.dockerignore` que evite colar secretos

<small>⏱ 75 min · `labs/lab-07-buenas-practicas.md`</small>

---

<!-- .slide: class="docker" -->

## Resumen del módulo

- El **Dockerfile** es la receta reproducible de la imagen
- **Caché**: lo que menos cambia, arriba
- **Multi-stage**: herramientas en build, solo lo necesario en runtime
- **Base mínima, versiones fijadas, no root, sin secretos**
- **Lint, escaneo y SBOM** en CI

<div class="box tip">

Mañana: ¿y si tenemos 200 contenedores? **Kubernetes**.

</div>
