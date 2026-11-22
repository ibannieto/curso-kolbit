# Lab 01 · Primeros contenedores

## Objetivos

- Ejecutar contenedores interactivos y en segundo plano.
- Recorrer el ciclo de vida: `run`, `ps`, `logs`, `exec`, `stop`, `start` y `rm`.
- Publicar puertos y pasar variables de entorno.

**Duración:** 45 min · **Requisitos:** Lab 00 completado.

## Pasos

### 1. Hola mundo… y qué ha pasado

```bash
docker run hello-world
docker ps -a
```

El contenedor aparece como `Exited (0)`: ejecutó su proceso y terminó.
**Un contenedor vive lo que vive su proceso principal.**

### 2. Contenedor interactivo

```bash
docker run -it --rm --name explorador alpine:3.24 sh
```

Dentro del contenedor:

```sh
cat /etc/os-release | head -2
ps aux            # ¿cuántos procesos ves? ¿quién es el PID 1?
hostname          # el ID corto del contenedor
touch /tmp/hola && ls /tmp
exit
```

Al salir, `--rm` borra el contenedor. Compruébalo con `docker ps -a`.

### 3. Contenedor en segundo plano con un puerto publicado

```bash
docker run -d --name web -p 8080:80 nginx:1.30-alpine
docker ps
curl -s localhost:8080 | grep -i title
```

Salida esperada:

```text
<title>Welcome to nginx!</title>
```

### 4. Logs

```bash
docker logs web
docker logs -f --tail 5 web     # sigue los logs (Ctrl+C para salir)
```

En otra terminal, lanza varias peticiones con `curl localhost:8080` y observa
cómo aparecen en los logs.

### 5. Ejecutar comandos dentro (`exec`)

```bash
docker exec web nginx -v
docker exec -it web sh
# dentro:
echo '<h1>Hola curso</h1>' > /usr/share/nginx/html/index.html
exit
curl -s localhost:8080
```

> ¿Qué pasará con este cambio si borras el contenedor? Apúntalo y lo
> comprobamos en el paso 7.

### 6. Parar, arrancar y reiniciar

```bash
docker stop web          # SIGTERM y, a los 10 s, SIGKILL
docker ps -a --filter name=web
docker start web
curl -s localhost:8080   # ¿sigue tu «Hola curso»?
docker restart web
```

### 7. Borrar y recrear

```bash
docker rm -f web
docker run -d --name web -p 8080:80 nginx:1.30-alpine
curl -s localhost:8080 | grep -i title
```

El cambio se ha perdido: estaba en la **capa escribible** del contenedor
anterior. Mañana lo resolveremos con volúmenes.

### 8. Variables de entorno

```bash
docker run --rm -e SALUDO="Hola" -e NOMBRE="Kolbit" alpine:3.24 \
  sh -c 'echo "$SALUDO, $NOMBRE"; env | sort | head'
```

Con un fichero:

```bash
printf 'APP_MESSAGE=Desde env-file\nAPP_COLOR=green\n' > app.env
docker run --rm --env-file app.env alpine:3.24 env | grep APP_
```

### 9. Nombres, IDs y filtros

```bash
docker run -d nginx:1.30-alpine            # sin --name: nombre aleatorio
docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}'
docker ps -q                               # solo IDs
docker stop $(docker ps -q --filter ancestor=nginx:1.30-alpine)
```

## Retos extra

1. Arranca dos nginx a la vez en los puertos 8081 y 8082. ¿Qué pasa si intentas
   usar el mismo puerto del host dos veces?
2. Ejecuta `docker run -d alpine:3.24 sleep 5` y observa su estado con
   `docker ps -a` cada pocos segundos. ¿Qué código de salida tiene?
3. Ejecuta `docker run --rm alpine:3.24 sh -c 'exit 3'` y luego `echo $?`. ¿Qué
   código ves?

## Limpieza

```bash
docker rm -f web $(docker ps -aq --filter ancestor=nginx:1.30-alpine) 2>/dev/null
docker container prune -f
rm -f app.env
```
