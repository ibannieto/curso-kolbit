# Lab 03 · Imágenes y registros

## Objetivos

- Entender las capas de una imagen y cómo se comparten.
- Distinguir **tags** (mutables) de **digests** (inmutables).
- Montar un registro local con `registry:3` y hacer push y pull.
- Mover imágenes sin registro con `save` y `load`.

**Duración:** 45 min · **Requisitos:** Lab 02.

## Pasos

### 1. Descargar y explorar

```bash
docker pull nginx:1.30-alpine
docker pull redis:8.10.3-alpine
docker image ls
docker image history nginx:1.30-alpine
```

Identifica en el historial la capa base de Alpine (`ADD alpine-minirootfs…`) y
la capa que instala nginx. ¿Cuál es la más grande?

### 2. Capas compartidas

```bash
docker image inspect nginx:1.30-alpine -f '{{json .RootFS.Layers}}' | jq .
docker image inspect redis:8.10.3-alpine -f '{{json .RootFS.Layers}}' | jq .
```

Si las dos imágenes se basan en la misma versión de Alpine, la **primera capa
coincide** y solo se guarda una vez en disco.

### 3. Tags vs. digests

```bash
docker image inspect redis:8.10.3-alpine -f '{{join .RepoDigests "\n"}}'
```

Salida (el hash variará):

```text
redis@sha256:3b0c…e91a
```

Descarga la misma imagen por digest:

```bash
DIGEST=$(docker image inspect redis:8.10.3-alpine -f '{{index .RepoDigests 0}}')
echo "$DIGEST"
docker pull "$DIGEST"
```

> Un tag puede moverse: hoy `redis:8.10-alpine` es la 8.10.3 y mañana la 8.10.4.
> Un digest **siempre** apunta al mismo contenido.

### 4. Arquitectura y metadatos

```bash
docker image inspect nginx:1.30-alpine \
  -f '{{.Os}}/{{.Architecture}} · creada {{.Created}} · {{.Size}} bytes'
docker buildx imagetools inspect nginx:1.30-alpine | head -20   # índice multiarquitectura
```

### 5. Montar un registro local

```bash
docker run -d --name registry --restart unless-stopped \
  -p 5000:5000 -v registry-data:/var/lib/registry registry:3.1.2
curl -s localhost:5000/v2/_catalog
```

Salida esperada:

```json
{"repositories":[]}
```

### 6. Tag y push al registro local

```bash
docker tag nginx:1.30-alpine localhost:5000/curso/nginx:1.30
docker tag redis:8.10.3-alpine localhost:5000/curso/redis:8.10.3
docker push localhost:5000/curso/nginx:1.30
docker push localhost:5000/curso/redis:8.10.3

curl -s localhost:5000/v2/_catalog
curl -s localhost:5000/v2/curso/nginx/tags/list
```

> `localhost` se considera un registro «inseguro permitido» por defecto. Para
> usar HTTP con otro hostname tendrías que configurar `insecure-registries` en
> `/etc/docker/daemon.json`. Mejor ponerle TLS.

### 7. Pull desde el registro local

```bash
docker rmi localhost:5000/curso/nginx:1.30 nginx:1.30-alpine
docker pull localhost:5000/curso/nginx:1.30
docker run --rm -d -p 8080:80 --name web localhost:5000/curso/nginx:1.30
curl -s localhost:8080 | grep -i title
docker rm -f web
```

### 8. `save` y `load`: imágenes sin registro

Útil en entornos aislados (air-gapped) o para pasar una imagen a un compañero:

```bash
docker save -o redis.tar redis:8.10.3-alpine
ls -lh redis.tar
docker rmi redis:8.10.3-alpine localhost:5000/curso/redis:8.10.3
docker load -i redis.tar
docker image ls redis
```

### 9. Registros públicos: login

```bash
docker login                     # Docker Hub (evita el límite de pulls anónimos)
# GHCR, con un token de GitHub con permiso read:packages / write:packages:
echo "$GITHUB_TOKEN" | docker login ghcr.io -u <usuario> --password-stdin
cat ~/.docker/config.json        # ¿se guardan las credenciales en base64 o en un credential helper?
```

## Retos extra

1. Sube a tu registro local la misma imagen con dos tags (`1.30` y `latest`).
   Compara sus digests con `curl -sI -H 'Accept: application/vnd.oci.image.index.v1+json' localhost:5000/v2/curso/nginx/manifests/latest`.
2. Busca la etiqueta `org.opencontainers.image.source` en `docker image inspect`
   de alguna imagen oficial. ¿Dónde está su código?
3. ¿Qué tamaño tiene el volumen `registry-data`? (`docker system df -v`)

## Limpieza

```bash
docker rm -f registry
docker volume rm registry-data
rm -f redis.tar
```
