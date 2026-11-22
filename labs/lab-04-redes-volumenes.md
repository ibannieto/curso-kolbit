# Lab 04 · Redes y volúmenes

## Objetivos

- Levantar **contador + Redis a mano**, sin Compose, en una red de usuario.
- Comprobar el DNS interno entre contenedores y su ausencia en la red por defecto.
- Demostrar que los datos **persisten** en un volumen aunque se borre el contenedor.
- Servir contenido propio con un bind mount.

**Duración:** 60 min · **Requisitos:** Lab 03 · Directorio `examples/contador`.

## Pasos

### 1. Construir la imagen de contador

```bash
cd examples/contador
docker build -t contador:dev .
docker image ls contador
```

> El Dockerfile lo analizaremos a fondo en el Módulo 3. Hoy lo usamos tal cual.

### 2. La red por defecto no tiene DNS

```bash
docker run -d --name redis-solo redis:8.10.3-alpine
docker run --rm alpine:3.24 ping -c1 redis-solo
```

Salida esperada:

```text
ping: bad address 'redis-solo'
```

```bash
docker rm -f redis-solo
```

### 3. Crear una red de usuario

```bash
docker network create contador-net
docker network ls
docker network inspect contador-net -f '{{(index .IPAM.Config 0).Subnet}}'
```

### 4. Redis con un volumen con nombre

```bash
docker volume create redis-data
docker run -d --name redis --network contador-net \
  -v redis-data:/data \
  redis:8.10.3-alpine redis-server --appendonly yes
```

### 5. La API en la misma red

```bash
docker run -d --name api --network contador-net -p 8080:8080 \
  -e REDIS_HOST=redis -e APP_MESSAGE="Hola desde una red de usuario" \
  contador:dev

curl -s localhost:8080/
curl -s localhost:8080/
curl -s localhost:8080/readyz
```

Salida esperada:

```json
{"visits": 2, "message": "Hola desde una red de usuario", "color": "blue", "host": "5f2d0c…"}
```

### 6. Comprobar el DNS

```bash
docker run --rm --network contador-net alpine:3.24 nslookup redis
docker run --rm --network contador-net redis:8.10.3-alpine redis-cli -h redis get visits
```

### 7. Persistencia: borrar Redis y recrearlo

```bash
docker rm -f redis
curl -s localhost:8080/          # 503: Redis no disponible
docker run -d --name redis --network contador-net \
  -v redis-data:/data redis:8.10.3-alpine redis-server --appendonly yes
sleep 2
curl -s localhost:8080/          # el contador CONTINÚA donde estaba
```

> Repite el experimento **sin** `-v redis-data:/data`. ¿Qué ocurre con el contador?

### 8. ¿Dónde está el volumen?

```bash
docker volume inspect redis-data
# Linux: sudo ls /var/lib/docker/volumes/redis-data/_data
docker run --rm -v redis-data:/data alpine:3.24 ls -la /data
```

### 9. Bind mount: servir tu propio HTML

```bash
mkdir -p ~/web-curso && echo '<h1>Mi web en un bind mount</h1>' > ~/web-curso/index.html
docker run -d --name web -p 8081:80 \
  --mount type=bind,src="$HOME/web-curso",dst=/usr/share/nginx/html,readonly \
  nginx:1.30-alpine
curl -s localhost:8081
echo '<h2>Editado en caliente</h2>' >> ~/web-curso/index.html
curl -s localhost:8081          # se ve el cambio sin reiniciar
```

### 10. tmpfs

```bash
docker run --rm --tmpfs /scratch:size=16m alpine:3.24 sh -c 'df -h /scratch; mount | grep scratch'
```

### 11. Publicación de puertos y exposición

```bash
docker run -d --name solo-local -p 127.0.0.1:8082:80 nginx:1.30-alpine
docker port solo-local
ss -tlnp | grep 8082        # escucha solo en 127.0.0.1
```

## Retos extra

1. Conecta un segundo contenedor `api2` a `contador-net` en el puerto 8083 del host.
   ¿Comparten contador? ¿Por qué?
2. Crea una segunda red `otra-net` y un contenedor en ella. ¿Puede llegar a `redis`?
   Usa `docker network connect` para conectarlo.
3. Haz un backup del volumen `redis-data` en un `.tgz` con un contenedor auxiliar
   (pista: Módulo 3, «Backup y restauración de un volumen»).

## Limpieza

```bash
docker rm -f api api2 redis web solo-local 2>/dev/null
docker network rm contador-net otra-net 2>/dev/null
docker volume rm redis-data
rm -rf ~/web-curso
```
