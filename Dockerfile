# syntax=docker/dockerfile:1
# -----------------------------------------------------------------------------
# Presentación del curso "Docker & Kubernetes & CaaS" (reveal.js)
#
#   podman build -t ghcr.io/ibannieto/curso-kolbit:dev .
#   podman run --rm -p 8080:8080 ghcr.io/ibannieto/curso-kolbit:dev
#
# Etapa 1 (build): instala dependencias npm y genera la web estática en /src/dist
# Etapa 2 (runtime): nginx sin privilegios (UID 101, puerto 8080), solo ficheros
# estáticos. Todo el material (reveal.js, fuentes, imágenes) va dentro de la imagen.
# -----------------------------------------------------------------------------

ARG NODE_IMAGE=docker.io/library/node:26.13.1-alpine
ARG NGINX_IMAGE=docker.io/nginxinc/nginx-unprivileged:1.30.6-alpine-slim

FROM ${NODE_IMAGE} AS build
WORKDIR /src
COPY package.json package-lock.json ./
RUN --mount=type=cache,target=/root/.npm npm ci --omit=dev --no-audit --no-fund
COPY scripts/build.mjs scripts/
COPY slides/ slides/
COPY assets/ assets/
ARG VERSION=dev
ARG GIT_SHA=unknown
ENV VERSION=${VERSION} GIT_SHA=${GIT_SHA}
RUN node scripts/build.mjs

FROM ${NGINX_IMAGE}
ARG VERSION=dev
ARG GIT_SHA=unknown
ARG CREATED=unknown
LABEL org.opencontainers.image.title="curso-kolbit" \
      org.opencontainers.image.description="Presentación del curso Docker & Kubernetes & CaaS (reveal.js)" \
      org.opencontainers.image.source="https://github.com/ibannieto/curso-kolbit" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.created="${CREATED}" \
      org.opencontainers.image.licenses="NOASSERTION"
COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /src/dist /usr/share/nginx/html
USER 101
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD ["wget", "-q", "-O", "/dev/null", "http://127.0.0.1:8080/healthz"]
