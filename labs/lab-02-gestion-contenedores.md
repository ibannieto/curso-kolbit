# Lab 02 · Gestión de contenedores

## Objetivos

- Inspeccionar contenedores con `inspect`, `stats`, `top`, `diff` y `cp`.
- Configurar políticas de reinicio.
- Limitar memoria y CPU, y provocar un **OOMKilled**.
- Liberar espacio de forma segura.

**Duración:** 45 min · **Requisitos:** Lab 01.

## Pasos

### 1. `inspect`: toda la verdad en JSON

```bash
docker run -d --name web -p 8080:80 nginx:1.30-alpine
docker inspect web | less
docker inspect -f '{{.State.Status}} desde {{.State.StartedAt}}' web
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' web
docker inspect -f '{{json .Config.Env}}' web | jq .
```

Busca en el JSON el comando de arranque (`Config.Cmd`), la imagen
(`Config.Image`) y los puertos (`NetworkSettings.Ports`).

### 2. Procesos, consumo y cambios

```bash
docker top web
docker stats --no-stream
docker exec web sh -c 'echo prueba > /tmp/fichero'
docker diff web          # A = añadido, C = cambiado, D = borrado
```

### 3. Copiar ficheros

```bash
docker cp web:/etc/nginx/conf.d/default.conf ./default.conf
sed -i 's/listen       80;/listen       8081;/' default.conf
docker cp ./default.conf web:/etc/nginx/conf.d/default.conf
docker exec web nginx -t && docker exec web nginx -s reload
```

> Esto es **depurar**, no **desplegar**. Los cambios en caliente se pierden y
> nadie sabe que existen. La configuración se monta o se mete en la imagen.

```bash
docker rm -f web
```

### 4. Políticas de reinicio

Un contenedor que falla cada 3 segundos:

```bash
docker run -d --name inestable --restart on-failure:3 \
  alpine:3.24 sh -c 'echo arrancando; sleep 3; exit 1'
sleep 20
docker ps -a --filter name=inestable
docker inspect -f 'Reinicios: {{.RestartCount}}' inestable
docker logs inestable
```

Debería mostrar `Reinicios: 3` y quedar en `Exited (1)`.

Ahora con `unless-stopped`:

```bash
docker run -d --name siempre --restart unless-stopped \
  alpine:3.24 sh -c 'sleep 2; exit 1'
sleep 10; docker inspect -f '{{.RestartCount}}' siempre
docker stop siempre      # si lo paras tú, no vuelve a arrancar
docker rm -f inestable siempre
```

### 5. Límite de memoria: provocar un OOMKilled

```bash
docker run -d --name gloton --memory 64m --memory-swap 64m \
  python:3.15.2-slim python -c "x = bytearray(200 * 1024 * 1024); input()"
sleep 3
docker ps -a --filter name=gloton --format '{{.Status}}'
docker inspect -f 'OOMKilled={{.State.OOMKilled}} ExitCode={{.State.ExitCode}}' gloton
```

Salida esperada:

```text
Exited (137) 2 seconds ago
OOMKilled=true ExitCode=137
```

> **137 = 128 + 9 (SIGKILL).** Volverás a ver este código en Kubernetes.

### 6. Límite de CPU: throttling, no muerte

```bash
docker run -d --name cpu --cpus 0.5 alpine:3.24 sh -c 'while :; do :; done'
docker stats --no-stream cpu        # CPU% ronda el 50 %
docker update --cpus 0.2 cpu        # cambiar en caliente
docker stats --no-stream cpu
docker rm -f cpu gloton
```

### 7. ¿Qué ocupa espacio?

```bash
docker system df
docker system df -v | head -30
```

### 8. Limpieza segura, de menos a más agresiva

```bash
docker container prune -f            # contenedores parados
docker image prune -f                # imágenes <none> (dangling)
docker builder prune -f              # caché de build
docker system prune -f               # todo lo anterior + redes sin uso
```

> `docker system prune -a --volumes` borra **todas** las imágenes sin
> contenedor y **todos los volúmenes** sin contenedor. No lo ejecutes en un
> servidor con datos.

## Retos extra

1. Arranca un nginx con `--read-only --tmpfs /var/cache/nginx --tmpfs /var/run --tmpfs /tmp`.
   ¿Qué pasa si quitas alguno de los `--tmpfs`? Mira `docker logs`.
2. Lanza un contenedor con `--pids-limit 20` y ejecuta dentro una bomba de
   procesos controlada: `for i in $(seq 50); do sleep 100 & done`. ¿Qué error ves?
3. Usa `docker events` en otra terminal mientras arrancas y paras contenedores.

## Limpieza

```bash
docker rm -f $(docker ps -aq) 2>/dev/null
rm -f default.conf
```
