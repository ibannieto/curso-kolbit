# Lab 07 · Buenas prácticas de construcción

## Objetivos

- Aplicar **multi-stage** y **usuario no root**.
- Comparar tamaños: ingenua, slim y multi-stage.
- Pasar `hadolint` (lint) y `trivy` (CVE) desde contenedores.
- Evitar secretos en la imagen con `.dockerignore` y secretos de BuildKit.

**Duración:** 75 min · **Requisitos:** Lab 06.

## Pasos

### 1. La versión final del curso

```bash
cd examples/contador
cat Dockerfile
docker build -t contador:final .
```

Identifica:

- Las dos etapas (`AS build` y la final).
- `pip install --prefix=/install` en build y `COPY --from=build` en la final.
- `USER 10001:10001`, la forma exec y el `HEALTHCHECK`.

### 2. Comparar tamaños

```bash
docker image ls contador --format 'table {{.Tag}}\t{{.Size}}'
```

Referencia, medida en el portátil del profesor:

| Imagen | Tamaño |
| --- | --- |
| `contador:v1` (python:3.15, ingenua) | ≈ 1,17 GB |
| `contador:v2` (slim) | ≈ 143 MB |
| `contador:final` (slim, multi-stage, no root) | ≈ 133 MB |
| `contador:distroless` (paso 6) | ≈ 69 MB |

> Con Python el multi-stage ahorra poco, porque no hay compilador que quitar.
> Con Go, Rust o Java la diferencia es enorme: de GB a decenas de MB.

### 3. Usuario no root

```bash
docker run --rm contador:final id
docker run --rm contador:final sh -c 'touch /etc/prueba'     # Permission denied
docker run --rm --read-only -e REDIS_HOST=x -p 8080:8080 -d --name ro contador:final
curl -s localhost:8080/healthz && docker rm -f ro
```

Salida esperada:

```text
uid=10001 gid=10001 groups=10001
touch: cannot touch '/etc/prueba': Permission denied
{"status": "ok"}
```

### 4. Lint con hadolint

```bash
docker run --rm -i ghcr.io/hadolint/hadolint:v2.15.1 < Dockerfile
echo "código de salida: $?"
```

Ahora pásalo por el Dockerfile ingenuo del Lab 06:

```bash
docker run --rm -i ghcr.io/hadolint/hadolint:v2.15.1 < ~/lab06/Dockerfile
```

Salida (fragmento):

```text
-:5 DL3025 warning: Use arguments JSON notation for CMD and ENTRYPOINT arguments
-:4 DL3042 warning: Avoid use of cache directory with pip. Use `pip install --no-cache-dir <package>`
```

### 5. Escaneo de vulnerabilidades con Trivy

Con Docker, compartiendo el socket:

```bash
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  -v trivy-cache:/root/.cache aquasec/trivy:0.76.2 \
  image --severity HIGH,CRITICAL contador:final
```

Con Podman, o sin acceso al socket, exporta la imagen a un tar:

```bash
docker save -o /tmp/contador.tar contador:final
docker run --rm -v /tmp:/work -v trivy-cache:/root/.cache aquasec/trivy:0.76.2 \
  image --severity HIGH,CRITICAL --input /work/contador.tar
```

Salida (fragmento; las cifras cambian cada día):

```text
/work/contador.tar (debian 13.7)
Total: 51 (HIGH: 51, CRITICAL: 0)
```

Preguntas para comentar:

- ¿Las CVE están en **tu código** o en **paquetes de la imagen base**?
- ¿Cuántas tienen versión corregida (columna *Fixed Version*)?
- ¿Qué pasaría con una base distroless o una imagen endurecida?

### 6. Comparar con otra base

Construye una variante sobre distroless. Guárdala como `examples/contador/Dockerfile.distroless`:

```dockerfile
FROM python:3.15.2-slim AS build
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --target=/deps -r requirements.txt

FROM gcr.io/distroless/python3-debian13:nonroot
WORKDIR /app
ENV PYTHONPATH=/deps
COPY --from=build /deps /deps
COPY app.py .
CMD ["app.py"]
```

> Ojo: la imagen distroless de Debian 13 trae **Python 3.13**, no la 3.15 de
> la etapa de build. Con dependencias en Python puro (como `redis`) funciona,
> pero con extensiones en C no. Compruébalo con `docker run --rm <imagen> --version`.
> Además, distroless no tiene shell: `docker exec … sh` no funciona. Un
> `HEALTHCHECK` en forma exec con `python -c` sí funcionaría.

```bash
docker build -f Dockerfile.distroless -t contador:distroless .
docker image ls contador
```

Vuelve a pasar Trivy y compara el número de CVE.

> En la prueba del profesor (22/11/2026), la imagen distroless pesaba la mitad
> pero tenía **más** CVE HIGH (90 frente a 51), porque arrastra paquetes de
> Debian con correcciones pendientes. **Más pequeña no implica automáticamente
> más segura:** mide siempre.

### 7. Secretos: lo que no hay que hacer

```bash
mkdir -p ~/lab07 && cd ~/lab07
echo "API_KEY=super-secreta" > .env
printf 'FROM alpine:3.24\nCOPY . /app\n' > Dockerfile
docker build -t fuga:v1 .
docker run --rm fuga:v1 cat /app/.env        # 😱 el secreto está en la imagen
```

Arréglalo con `.dockerignore`:

```bash
echo ".env" > .dockerignore
docker build -t fuga:v2 . && docker run --rm fuga:v2 ls -la /app
```

### 8. Secretos en build, bien hechos

```bash
cat > Dockerfile <<'EOF'
# syntax=docker/dockerfile:1
FROM alpine:3.24
RUN --mount=type=secret,id=api_key \
    echo "usando la clave de longitud $(wc -c < /run/secrets/api_key)"
EOF
echo -n "super-secreta" > api_key.txt
docker build --no-cache --progress=plain --secret id=api_key,src=api_key.txt -t secreto:ok .
docker image history secreto:ok             # no aparece el valor
```

### 9. SBOM

```bash
docker buildx build --sbom=true -t contador:sbom --load examples/contador 2>/dev/null \
  || echo "requiere builder con soporte de attestations (docker-container)"
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy:0.76.2 \
  image --format spdx-json contador:final | head -20
```

## Retos extra

1. Añade una etapa `test` al Dockerfile de contador que ejecute
   `python -m py_compile app.py`, y haz que la etapa final dependa de ella.
2. Pasa `hadolint` a todos los Dockerfiles del repositorio con un bucle `find`.
3. Fija la imagen base por digest y comprueba que el build sigue siendo reproducible.
4. **Reto del día: conteneriza tu propia app.** Elige una aplicación tuya (o de
   tu equipo) y escríbele un Dockerfile aplicando el checklist del módulo:
   multi-stage, usuario no root, `.dockerignore`, versiones fijadas,
   `HEALTHCHECK` y parada limpia con SIGTERM. Pásale hadolint y Trivy, y
   compara el tamaño con el de la imagen que usáis hoy, si existe. Al final,
   se comentan dos o tres en común.

## Limpieza

```bash
docker rmi contador:final contador:distroless contador:sbom fuga:v1 fuga:v2 secreto:ok 2>/dev/null
docker volume rm trivy-cache
rm -rf ~/lab07 /tmp/contador.tar examples/contador/Dockerfile.distroless
```
