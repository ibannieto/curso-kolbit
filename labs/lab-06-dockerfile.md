# Lab 06 · Escribir el Dockerfile de contador

## Objetivos

- Empaquetar la app contador partiendo de un Dockerfile ingenuo.
- Medir y aprovechar la **caché de capas**.
- Usar la forma exec, `HEALTHCHECK`, `LABEL` y `ARG`/`ENV`.
- Entender por qué importa el manejo de señales (PID 1).

**Duración:** 75 min · **Requisitos:** Labs 04 y 05.

## Pasos

### 1. Directorio de trabajo

```bash
mkdir -p ~/lab06 && cp examples/contador/{app.py,requirements.txt} ~/lab06/
cd ~/lab06
```

### 2. Versión 1: ingenua

```dockerfile
FROM python:3.15
COPY . /app
WORKDIR /app
RUN pip install -r requirements.txt
CMD python app.py
```

```bash
time docker build -t contador:v1 .
docker image ls contador:v1          # ≈ 1,17 GB
```

### 3. Probar la v1

```bash
docker network create lab06 2>/dev/null
docker run -d --name redis --network lab06 redis:8.10.3-alpine
docker run -d --name api --network lab06 -p 8080:8080 -e REDIS_HOST=redis contador:v1
curl -s localhost:8080/
docker exec api id                   # uid=0(root) 😬
time docker stop api                 # ¿cuánto tarda?
docker rm api
```

> `CMD python app.py` (forma shell) se ejecuta como `/bin/sh -c "python app.py"`.

### 4. Romper la caché a propósito

Cambia el mensaje por defecto en `app.py` (busca `APP_MESSAGE`) y reconstruye:

```bash
time docker build -t contador:v1 .
```

Observa que **se repite `pip install`**: `COPY . /app` ha cambiado y BuildKit
invalida esa capa y todas las siguientes.

### 5. Versión 2: orden pensado para la caché

```dockerfile
FROM python:3.15.2-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
CMD ["python", "app.py"]
```

```bash
docker build -t contador:v2 .
# edita app.py otra vez
docker build -t contador:v2 .        # ahora pip install aparece como CACHED
docker image ls contador
```

### 6. `.dockerignore`

```bash
cat > .dockerignore <<'EOF'
__pycache__/
*.pyc
.venv/
.env
.git
Dockerfile*
EOF
```

Prueba a crear un `.env` con un «secreto» y comprueba que **no** llega a la
imagen: `docker run --rm contador:v2 ls -la /app`.

### 7. Versión 3: metadatos, configuración y healthcheck

```dockerfile
# syntax=docker/dockerfile:1
ARG PYTHON_VERSION=3.15.2
FROM python:${PYTHON_VERSION}-slim
ARG APP_VERSION=dev
LABEL org.opencontainers.image.title="contador" \
      org.opencontainers.image.version="${APP_VERSION}"
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 APP_VERSION=${APP_VERSION}
WORKDIR /app
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip pip install -r requirements.txt
COPY app.py .
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=2s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/healthz')"]
CMD ["python", "app.py"]
```

```bash
docker build --build-arg APP_VERSION=1.0.0 -t contador:v3 .
docker image inspect contador:v3 -f '{{json .Config.Labels}}'
docker run -d --name api --network lab06 -p 8080:8080 -e REDIS_HOST=redis contador:v3
sleep 15 && docker ps --filter name=api --format '{{.Status}}'   # (healthy)
```

### 8. Señales: `docker stop` inmediato

```bash
time docker stop api      # < 1 s
docker logs api | tail -2
```

Salida esperada:

```text
recibida señal SIGTERM, saliendo
```

`app.py` registra un manejador de SIGTERM (`signal.signal`). Sin él, Python,
siendo PID 1, **ignora** SIGTERM y Docker acaba matándolo con SIGKILL a los 10 s.
Pruébalo comentando las dos líneas `signal.signal(...)` de `app.py`.

### 9. `ENTRYPOINT` + `CMD`

```bash
docker run --rm --entrypoint python contador:v3 --version
docker run --rm contador:v3 python -c "print('CMD sobrescrito')"
```

### 10. Historial de la imagen

```bash
docker image history contador:v3
```

¿Aparece `APP_VERSION` en el historial? Por eso **los secretos no van en `ARG`**.

## Retos extra

1. Añade `USER 10001:10001` a la v3. ¿Funciona? ¿Qué devuelve `docker exec api id`?
2. Mide el tiempo de un build sin caché: `docker build --no-cache …`.
3. Construye para arm64: `docker buildx build --platform linux/arm64 -t contador:arm64 .`

## Limpieza

```bash
docker rm -f api redis
docker network rm lab06
docker rmi contador:v1 contador:v2 contador:v3
```
