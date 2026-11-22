# contador

API mínima en Python que cuenta visitas y las guarda en **Redis**. Es la app de
ejemplo que recorre todo el curso: `docker run` → Compose → Dockerfile →
Kubernetes.

Solo usa la librería estándar de Python más el cliente `redis`. La imagen final
es multi-stage, corre sin root (UID 10001), maneja SIGTERM y tiene healthcheck.

## Endpoints

| Ruta | Descripción |
| --- | --- |
| `GET /` | Incrementa el contador y devuelve `visits`, `message`, `color` y `host` |
| `GET /healthz` | Liveness: el proceso responde |
| `GET /readyz` | Readiness: Redis responde a `PING` (503 si no) |
| `GET /load` | Quema CPU durante `LOAD_SECONDS`, para probar el HPA |
| `GET /info` | Configuración visible y hostname del contenedor o Pod |

## Variables de entorno

| Variable | Por defecto | Uso |
| --- | --- | --- |
| `PORT` | `8080` | Puerto HTTP |
| `REDIS_HOST` | `redis` | Host de Redis |
| `REDIS_PORT` | `6379` | Puerto de Redis |
| `REDIS_PASSWORD` | *(vacía)* | Contraseña de Redis (Secret en Kubernetes) |
| `APP_MESSAGE` | `¡Hola desde un contenedor!` | Mensaje (ConfigMap en Kubernetes) |
| `APP_COLOR` | `blue` | Color (para demos de rolling update) |
| `LOAD_SECONDS` | `2` | Duración de `/load` |
| `FAIL_ON_START` | *(vacía)* | Si tiene valor, la app sale con error al arrancar (lab de troubleshooting) |

## Ejecutar con Docker

```bash
docker build -t contador:dev .
docker network create contador-net
docker run -d --name redis --network contador-net redis:8.10.3-alpine
docker run -d --name api --network contador-net -p 8080:8080 \
  -e REDIS_HOST=redis contador:dev
curl -s localhost:8080/
```

## Ejecutar con Docker Compose

```bash
docker compose up -d --build
curl -s localhost:8080/
docker compose down -v
```

## Ejecutar con Podman

```bash
podman build --format docker -t contador:dev .   # --format docker conserva el HEALTHCHECK
podman compose up -d --build
```

## Kubernetes

Los manifiestos para Kubernetes (Deployment, Service, ConfigMap, Secret, HPA…)
están en [`k8s/`](k8s/) y se usan a partir del Módulo 4.

## Ficheros

| Fichero | Descripción |
| --- | --- |
| `app.py` | Código de la API |
| `requirements.txt` | Dependencias con versión fijada |
| `Dockerfile` | Imagen final (multi-stage, no root, healthcheck) |
| `compose.yaml` | API + Redis con volumen persistente |
| `.dockerignore` | Excluye del contexto de build lo que no hace falta |
