<!-- .slide: class="module center-v" -->

<span class="kicker">Módulo 2 · Días 1–2</span>

# Introducción a Docker

<div class="agenda">

Instalación · Arquitectura · Contenedores · Imágenes y registros · Redes · Almacenamiento · Compose

</div>

<div class="logo-row">
  <img src="assets/img/logos/docker.svg" alt="Docker">
  <img src="assets/img/logos/podman.svg" alt="Podman">
</div>

---

<!-- .slide: class="docker" -->

## Instalación: opciones

<div class="cols">
<div>

**Linux** (servidores y equipos de desarrollo)

- **Docker Engine 29** desde los repos oficiales de Docker
- Paquetes: `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`
- No uses el `docker.io` antiguo de tu distro

</div>
<div>

**Mac y Windows**

- **Docker Desktop**: VM Linux + Engine + UI
- Requiere licencia de pago en empresas medianas y grandes
- Alternativas: **Podman Desktop**, Rancher Desktop, Colima

</div>
</div>

Note:
Docker Desktop es gratis para uso personal, educación y empresas pequeñas (menos de 250 empleados y menos de 10 M$ de facturación). Revisar la licencia vigente antes de desplegarlo en la empresa.

---

<!-- .slide: class="docker" -->

## Instalación en Linux (Debian/Ubuntu)

```bash
# Script oficial (cómodo para laboratorios; en producción, usa el repo apt)
curl -fsSL https://get.docker.com | sudo sh

# Verificar
sudo docker version
sudo docker run --rm hello-world

# Arrancar con el sistema
sudo systemctl enable --now docker
```

<small>Guía completa: `labs/lab-00-entorno.md` · docs.docker.com/engine/install</small>

---

<!-- .slide: class="docker" -->

## Post-instalación: ¿`sudo` o grupo `docker`?

```bash
sudo usermod -aG docker "$USER"
newgrp docker          # o cerrar sesión y volver a entrar
docker ps              # ya sin sudo
```

<div class="box danger">

Pertenecer al grupo `docker` **equivale a ser root** en el host:
`docker run -v /:/host -it alpine chroot /host` y listo.

</div>

- Alternativa más segura: **Docker rootless** (`dockerd-rootless-setuptool.sh install`)
- O **Podman**, que es rootless por defecto

---

<!-- .slide: class="docker" -->

## Podman: la alternativa compatible

<div class="cols wide-left">
<div>

- **Sin daemon**: cada contenedor es un proceso hijo
- **Rootless** por defecto, con user namespaces
- Misma CLI: `alias docker=podman`
- Conceptos extra: **pods** (como en Kubernetes) y `podman kube play`
- `podman compose` delega en docker-compose o podman-compose

</div>
<div class="center">

<img src="assets/img/logos/podman.svg" alt="Podman" style="height:240px">

</div>
</div>

<small>En este curso usamos `docker` en las diapositivas; con Podman casi todo funciona igual.</small>

---

<!-- .slide: class="docker" -->

## Arquitectura de Docker

```text
 docker (CLI) ──REST API──▶ dockerd (Docker Engine)
                                  │  gRPC
                                  ▼
                             containerd ──▶ containerd-shim ──▶ runc ──▶ tu proceso
                                  │
                         imágenes · snapshots (overlayfs) · redes · volúmenes
```

- **CLI**: cliente; puede hablar con un Engine remoto (`DOCKER_HOST`, `docker context`)
- **dockerd**: API, build (BuildKit), redes y volúmenes
- **containerd**: ciclo de vida de contenedores e imágenes (también lo usa Kubernetes)
- **runc**: crea el proceso con namespaces y cgroups, y desaparece

---

<!-- .slide: class="docker" -->

## Comprobar la instalación

```console
$ docker version --format '{{.Server.Version}}'
29.10.0

$ docker info --format '{{.Driver}} · cgroup {{.CgroupVersion}} · {{.OperatingSystem}}'
overlayfs · cgroup 2 · Ubuntu 24.04.3 LTS

$ docker context ls
NAME        DESCRIPTION                               DOCKER ENDPOINT
default *   Current DOCKER_HOST based configuration   unix:///var/run/docker.sock
```

Note:
Docker 29 usa por defecto el containerd image store (driver overlayfs, el snapshotter de containerd) en instalaciones nuevas. Las instalaciones antiguas actualizadas pueden seguir con overlay2.

---

<!-- .slide: class="docker" -->

## Imagen vs. contenedor

<div class="cols">
<div>

**Imagen**

- Plantilla **inmutable** de solo lectura
- Capas apiladas + metadatos
- Se identifica por `nombre:tag` o `@sha256:digest`

</div>
<div>

**Contenedor**

- **Instancia** en ejecución de una imagen
- Añade una capa **escribible** encima
- Efímero: si lo borras, se pierde lo que escribió

</div>
</div>

<div class="box tip">

Analogía: imagen = clase, contenedor = objeto. Una imagen, N contenedores.

</div>

---

<!-- .slide: class="docker" -->

## Tu primer contenedor

```bash
docker run hello-world

docker run -it --rm alpine:3.24 sh       # interactivo, se borra al salir
docker run -d --name web -p 8080:80 nginx:1.30-alpine
curl -s localhost:8080 | head -4

docker ps                                # en ejecución
docker ps -a                             # también los parados
```

- `-d`: en segundo plano · `-it`: terminal interactiva · `--rm`: borrar al salir
- `--name`: nombre fijo · `-p HOST:CONTENEDOR`: publicar un puerto

---

<!-- .slide: class="docker" -->

## Ciclo de vida

```text
          docker create          docker start
 imagen ────────────────▶ created ───────────▶ running ◀──┐
                                                  │        │ docker restart
                          docker stop (SIGTERM) │ │        │
                     ┌──────── exited ◀─────────┘ └────────┘
                     │  docker rm                     docker pause ⇄ unpause
                     ▼
                  (borrado)                 docker run = create + start
```

- `docker stop` envía **SIGTERM** y, pasados 10 s, **SIGKILL** (`-t` para cambiarlo)
- `docker kill` envía SIGKILL directamente

Note:
Si la app corre como PID 1 y no maneja SIGTERM, se queda colgada hasta el SIGKILL. Nos pasó con la app contador: Python sin manejador de señales ignora SIGTERM siendo PID 1. Lo arreglamos con signal.signal en app.py.

---

<!-- .slide: class="docker" -->

## Inspeccionar y depurar

```bash
docker logs -f --tail 50 web            # stdout/stderr del contenedor
docker exec -it web sh                  # shell dentro del contenedor
docker inspect web                      # JSON con TODA la configuración
docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' web
docker top web                          # procesos
docker stats --no-stream                # CPU, memoria, red e I/O
docker cp web:/etc/nginx/nginx.conf .   # copiar ficheros
docker diff web                         # cambios en la capa escribible
```

---

<!-- .slide: class="docker" -->

## Variables de entorno y configuración

```bash
docker run -d --name api \
  -e APP_MESSAGE="Hola curso" \
  -e LOG_LEVEL=debug \
  --env-file ./app.env \
  -p 8080:8080 \
  contador:dev
```

- La configuración **se inyecta al arrancar**, no se hornea en la imagen
- Es el principio *12-factor*: la misma imagen para dev, test y prod
- Los secretos por `-e` aparecen en `docker inspect`: ojo

---

<!-- .slide: class="docker" -->

## Políticas de reinicio

| Política | Comportamiento |
| --- | --- |
| `no` (por defecto) | Nunca se reinicia |
| `on-failure[:N]` | Si sale con código ≠ 0 (hasta N veces) |
| `always` | Siempre, también al reiniciar el daemon |
| `unless-stopped` | Como `always`, salvo si lo paraste tú |

```bash
docker run -d --restart unless-stopped --name redis redis:8.10.3-alpine
docker update --restart on-failure:3 redis
```

<small>En Kubernetes esto lo hace el kubelet (`restartPolicy`)… y mucho más.</small>

---

<!-- .slide: class="docker" -->

## Limitar recursos (cgroups)

```bash
docker run -d --name limitado \
  --memory 256m --memory-swap 256m \
  --cpus 0.5 \
  --pids-limit 100 \
  nginx:1.30-alpine

docker stats --no-stream limitado
```

- Si supera la **memoria**, el kernel lo mata: **OOMKilled** (exit code 137)
- Si supera la **CPU**, no muere: se le *estrangula* (throttling)
- `docker inspect -f '{{.State.OOMKilled}}' limitado`

---

<!-- .slide: class="docker" -->

## Limpieza

```bash
docker rm -f web api                 # borrar contenedores (aunque estén corriendo)
docker container prune               # todos los parados
docker image prune                   # imágenes «dangling» (<none>)
docker system df                     # ¿qué ocupa espacio?
docker system prune                  # parados + redes + dangling + caché
docker system prune -a --volumes     # ☢ TODO lo que no esté en uso
```

---

<!-- .slide: class="meme" -->

<div class="meme-term">
<div class="bar">viernes 14:15 · producción</div>

```console
$ docker system prune -a --volumes
WARNING! This will remove:
  - all stopped containers
  - all volumes not used by at least one container
  - all images without at least one container associated to them
Are you sure you want to continue? [y/N] y
Total reclaimed space: 48.7GB
```

</div>

<p class="meme-caption">48,7 GB liberados. La base de datos de ayer, también.</p>

Note:
Un volumen sin contenedor «en uso» no es un volumen sin importancia. Si la BD estaba parada, su volumen se borra.

---

<!-- .slide: class="lab" -->

## Lab 01 · Primeros contenedores

- `run`, `ps`, `logs`, `exec`, `stop`, `start` y `rm`
- Contenedores interactivos vs. en segundo plano
- Publicar puertos y pasar variables de entorno

<small>⏱ 45 min · `labs/lab-01-primeros-contenedores.md`</small>

---

<!-- .slide: class="lab" -->

## Lab 02 · Gestión de contenedores

- `inspect`, `stats`, `top`, `diff` y `cp`
- Políticas de reinicio
- Límites de memoria y CPU: provocar un OOMKilled
- Limpieza del sistema

<small>⏱ 45 min · `labs/lab-02-gestion-contenedores.md`</small>

---

<!-- .slide: class="docker center-v" -->

## Resumen del día 1

- Contenedor = proceso aislado con namespaces y cgroups
- Docker: CLI → dockerd → containerd → runc
- Ciclo de vida: `run`, `ps`, `logs`, `exec`, `stop`, `rm`
- Configuración por variables de entorno, reinicios y límites

<div class="box tip">

**Mañana:** imágenes, registros, redes, volúmenes y Docker Compose.

</div>

---

<!-- .slide: class="docker" -->

## Día 2 · Imágenes: capas

```console
$ docker image history nginx:1.30-alpine --format '{{.Size}}\t{{.CreatedBy}}'
50.2MB  RUN /bin/sh -c set -x && apkArch="$(cat /etc/apk/arch)" …
0B      CMD ["nginx" "-g" "daemon off;"]
7.17kB  COPY 30-tune-worker-processes.sh /docker-entrypoint.d # buildkit
4.76MB  RUN /bin/sh -c set -x && addgroup -g 101 -S nginx …
0B      ENV NGINX_VERSION=1.30.7
8.71MB  ADD alpine-minirootfs-3.24.4-x86_64.tar.gz / # buildkit
```

- Cada instrucción del Dockerfile que toca ficheros crea una **capa**
- Las capas se **comparten** entre imágenes y se descargan una sola vez
- **OverlayFS** las apila y añade la capa escribible del contenedor

---

<!-- .slide: class="docker" -->

## Nombres de imagen

```text
ghcr.io / ibannieto / curso-kolbit : 1.0.0 @sha256:4f1c…
└──┬──┘   └───┬───┘   └────┬─────┘   └─┬─┘  └───┬────┘
registro  namespace   repositorio     tag     digest
```

- Sin registro, se usa `docker.io` · sin namespace, `library/` · sin tag, `:latest`
- `nginx` = `docker.io/library/nginx:latest`
- **Tag**: etiqueta *mutable* (alguien puede moverla)
- **Digest**: hash del contenido, *inmutable*

---

<!-- .slide: class="meme" -->

<div class="meme-two">
<div>
<span class="tag">Lunes</span>

`image: myapp:latest`

✔ Funciona

</div>
<div>
<span class="tag">Martes (mismo YAML)</span>

`image: myapp:latest`

✖ `ModuleNotFoundError`

</div>
</div>

<p class="meme-caption"><code>:latest</code> no es una versión. Es una ruleta.</p>

---

<!-- .slide: class="docker" -->

## Trabajar con imágenes

```bash
docker pull redis:8.10.3-alpine
docker image ls
docker image inspect redis:8.10.3-alpine --format '{{.Os}}/{{.Architecture}}'
docker pull redis@sha256:<digest>           # fijar por digest

docker tag redis:8.10.3-alpine mi-registro.local/cache/redis:8.10
docker rmi mi-registro.local/cache/redis:8.10   # borra la etiqueta

docker save -o redis.tar redis:8.10.3-alpine     # exportar a fichero
docker load -i redis.tar                         # importar (sin registro)
```

---

<!-- .slide: class="docker" -->

## Registros de imágenes

<div class="cols">
<div>

**Públicos / SaaS**

- **Docker Hub**: imágenes oficiales (`library/`)
- **GHCR** (`ghcr.io`): GitHub Packages
- Quay.io, ECR, Artifact Registry, ACR…

</div>
<div>

**Propios**

- **Harbor** (CNCF): escaneo, réplica, RBAC
- `registry:3` (Distribution): mínimo, para labs
- Zot, Nexus, Artifactory…

</div>
</div>

<div class="box warn">

Docker Hub limita los **pulls anónimos** por IP. En CI y en clústeres: `docker login`, un mirror o un registro propio.

</div>

---

<!-- .slide: class="docker" -->

## Subir imágenes: `login`, `tag` y `push`

```bash
# GHCR: usuario de GitHub + token con permiso write:packages
echo "$GITHUB_TOKEN" | docker login ghcr.io -u USUARIO --password-stdin

docker tag contador:dev ghcr.io/USUARIO/contador:1.0.0
docker push ghcr.io/USUARIO/contador:1.0.0

# Registro local para laboratorios
docker run -d --name registry -p 5000:5000 registry:3.1.2
docker tag contador:dev localhost:5000/contador:1.0.0
docker push localhost:5000/contador:1.0.0
```

Note:
Las credenciales se guardan en ~/.docker/config.json; mejor con un credential helper (pass, osxkeychain, wincred) que en base64. La imagen de este curso se sube a ghcr.io/ibannieto/curso-kolbit desde el portátil del profesor.

---

<!-- .slide: class="lab" -->

## Lab 03 · Imágenes y registros

- Explorar capas con `history` e `inspect`
- Tags vs. digests
- Montar un registro local `registry:3` y hacer push y pull
- `save` y `load` para entornos sin conexión

<small>⏱ 45 min · `labs/lab-03-imagenes-registros.md`</small>

---

<!-- .slide: class="docker" -->

## Redes en Docker

| Driver | Uso |
| --- | --- |
| `bridge` (por defecto) | Red privada en el host, con NAT hacia fuera |
| **bridge de usuario** | Igual, pero **con DNS interno** por nombre de contenedor |
| `host` | Comparte la red del host: sin aislamiento ni `-p` |
| `none` | Sin red, solo loopback |
| `macvlan` / `ipvlan` | IP propia en la LAN física |
| `overlay` | Multihost (Swarm) |

---

<!-- .slide: class="docker" -->

## Red por defecto vs. red de usuario

```bash
docker network create app-net

docker run -d --name redis --network app-net redis:8.10.3-alpine
docker run -d --name api --network app-net -p 8080:8080 \
  -e REDIS_HOST=redis contador:dev        # ¡resuelve «redis» por DNS!

docker network inspect app-net --format '{{range .Containers}}{{.Name}} {{end}}'
docker network connect app-net otro-contenedor
```

- En la red `bridge` por defecto **no hay DNS** entre contenedores
- Regla: **una red de usuario por aplicación**

---

<!-- .slide: class="docker" -->

## Publicar puertos

```bash
docker run -d -p 8080:80 nginx:1.30-alpine            # 0.0.0.0:8080 → 80
docker run -d -p 127.0.0.1:8081:80 nginx:1.30-alpine  # solo localhost
docker run -d -P nginx:1.30-alpine                    # puertos aleatorios
docker port <contenedor>
```

<div class="box warn">

Docker escribe sus propias reglas de iptables/nftables: un `-p 5432:5432` puede **saltarse el firewall** del host (ufw). Publica en `127.0.0.1` lo que no deba ser público.

</div>

---

<!-- .slide: class="meme" -->

<div class="meme-term">
<div class="bar">haiku del administrador de sistemas</div>

```text
No es el DNS.
Es imposible que sea el DNS.
Era el DNS.
```

</div>

<p class="meme-caption">¿El contenedor no encuentra «redis»? ¿Estáis en la misma red de usuario?</p>

---

<!-- .slide: class="docker" -->

## Almacenamiento: tres opciones

<div class="cols three">
<div>

**Volumen**

- Lo gestiona Docker
- `/var/lib/docker/volumes`
- Portable y con backups
- **Datos de aplicaciones**

</div>
<div>

**Bind mount**

- Ruta del host
- Tú gestionas permisos
- **Desarrollo**: código en caliente, configs

</div>
<div>

**tmpfs**

- En memoria
- Desaparece al parar
- **Datos temporales y sensibles**

</div>
</div>

<div class="box tip">

La capa escribible del contenedor **no es almacenamiento**: es lenta y se pierde con `docker rm`.

</div>

---

<!-- .slide: class="docker" -->

## Volúmenes y montajes en la práctica

```bash
docker volume create redis-data
docker run -d --name redis -v redis-data:/data \
  redis:8.10.3-alpine redis-server --appendonly yes

# Bind mount (sintaxis --mount, más explícita)
docker run -d -p 8080:80 \
  --mount type=bind,src="$PWD/html",dst=/usr/share/nginx/html,readonly \
  nginx:1.30-alpine

docker run --rm --tmpfs /tmp:size=64m alpine:3.24 df -h /tmp
docker volume ls && docker volume inspect redis-data
```

---

<!-- .slide: class="lab" -->

## Lab 04 · Redes y volúmenes

- Levantar **contador + Redis a mano** en una red de usuario
- Comprobar el DNS entre contenedores
- Borrar Redis y **demostrar que los datos persisten** en el volumen
- Bind mount para servir HTML propio con nginx

<small>⏱ 60 min · `labs/lab-04-redes-volumenes.md`</small>

---

<!-- .slide: class="docker" -->

## Docker Compose

- Define una **aplicación multicontenedor** en un único `compose.yaml`
- Servicios, redes y volúmenes de forma **declarativa**
- Crea una red de usuario por proyecto (DNS por nombre de servicio)
- Plugin `docker compose` (**v5**); el antiguo `docker-compose` v1 está muerto
- Sigue la **Compose Specification**: ya no hace falta la clave `version:`

<small>Ideal para desarrollo, CI y despliegues sencillos en un solo host.</small>

---

<!-- .slide: class="docker" -->

## `compose.yaml` de la app contador

```yaml
services:
  api:
    build: .
    ports: ["8080:8080"]
    environment: { REDIS_HOST: redis }
    depends_on:
      redis: { condition: service_healthy }
    restart: unless-stopped
  redis:
    image: redis:8.10.3-alpine
    volumes: ["redis-data:/data"]
    healthcheck: { test: ["CMD", "redis-cli", "ping"], interval: 5s }
volumes:
  redis-data:
```

<small>Fichero completo: `examples/contador/compose.yaml`</small>

---

<!-- .slide: class="docker" -->

## Comandos de Compose

```bash
docker compose up -d --build      # construir y arrancar
docker compose ps                 # estado de los servicios
docker compose logs -f api        # logs de un servicio
docker compose exec redis redis-cli get visits
docker compose up -d --scale api=3   # (sin puerto fijo en el host)
docker compose down               # parar y borrar contenedores y red
docker compose down -v            # … y también los volúmenes
docker compose config             # ver el YAML final ya resuelto
```

---

<!-- .slide: class="docker" -->

## Compose: algunos extras útiles

```yaml
services:
  api:
    env_file: .env
    develop:
      watch:                         # docker compose watch
        - action: sync+restart
          path: ./app.py
          target: /app/app.py
  adminer:
    image: adminer:5
    profiles: ["debug"]              # solo con --profile debug
```

- **Variables** `${VAR:-defecto}` desde `.env` · **override**: `compose.override.yaml`
- **profiles**: servicios opcionales · **watch**: recarga en desarrollo

---

<!-- .slide: class="docker" -->

## ¿Compose en producción?

<div class="cols">
<div>

**Sí, si…**

- Un único servidor
- Pocas apps y tolerancia a cortes breves
- Equipo pequeño

</div>
<div>

**Mejor un orquestador si…**

- Varios nodos y alta disponibilidad
- Autoescalado y rolling updates sin corte
- Muchos equipos y servicios

</div>
</div>

<div class="box tip">

Compose → Kubernetes es el salto que daremos el **día 4**.

</div>

---

<!-- .slide: class="meme" -->

<div class="meme-term">
<div class="bar">docker ps -a | wc -l</div>

```console
$ docker ps -a --format '{{.Names}}\t{{.Status}}'
api               Up 2 minutes
quirky_hopper     Exited (0) 3 weeks ago
sad_tesla         Exited (137) 3 weeks ago
eager_lovelace    Exited (1) 2 weeks ago
… 43 más …
```

</div>

<p class="meme-caption"><code>--rm</code> existe. Úsalo.</p>

---

<!-- .slide: class="lab" -->

## Lab 05 · Docker Compose

- Levantar contador + Redis con `examples/contador/compose.yaml`
- Logs, `exec`, escalado y persistencia tras `down` / `up`
- Añadir un servicio opcional con **profiles**

<small>⏱ 60 min · `labs/lab-05-compose.md`</small>

---

<!-- .slide: class="docker" -->

## Resumen del módulo

- **Imágenes**: capas inmutables; fija tags concretos o digests
- **Registros**: Docker Hub, GHCR, Harbor, `registry:3`
- **Redes**: una red de usuario por app, que trae DNS por nombre
- **Datos**: volúmenes para datos, bind mounts para desarrollo, tmpfs para temporales
- **Compose**: la app entera en un YAML declarativo

<div class="box tip">

Siguiente: construir **nuestras propias imágenes**.

</div>
