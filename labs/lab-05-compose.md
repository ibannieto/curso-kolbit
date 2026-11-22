# Lab 05 · Docker Compose

## Objetivos

- Levantar contador + Redis con un único `compose.yaml`.
- Manejar el ciclo de vida con `up`, `ps`, `logs`, `exec`, `down` y `config`.
- Comprobar `depends_on` con healthcheck y la persistencia del volumen.
- Añadir servicios opcionales con **profiles** y variables con `.env`.

**Duración:** 60 min · **Requisitos:** Lab 04 · `docker compose version` muestra v5.x.

## Pasos

### 1. Revisar el fichero

```bash
cd examples/contador
cat compose.yaml
docker compose config        # YAML final, con valores por defecto resueltos
```

Fíjate en:

- `name: contador`: el nombre del proyecto y el prefijo de los recursos.
- `depends_on.redis.condition: service_healthy`: la API espera a que Redis responda a `PING`.
- `volumes.redis-data`: un volumen con nombre gestionado por Compose.

### 2. Arrancar

```bash
docker compose up -d --build
docker compose ps
```

Salida esperada (fragmento):

```text
NAME               SERVICE   STATUS                    PORTS
contador-api-1     api       Up 5 seconds              0.0.0.0:8080->8080/tcp
contador-redis-1   redis     Up 11 seconds (healthy)   6379/tcp
```

```bash
curl -s localhost:8080/
curl -s localhost:8080/info
```

### 3. Logs y exec

```bash
docker compose logs -f api            # Ctrl+C para salir
docker compose exec redis redis-cli get visits
docker compose exec api python -c "import os; print(os.environ['REDIS_HOST'])"
```

### 4. Recursos creados

```bash
docker network ls | grep contador     # contador_default
docker volume ls | grep contador      # contador_redis-data
```

### 5. Persistencia tras `down` / `up`

```bash
curl -s localhost:8080/               # anota el número de visitas
docker compose down                   # borra contenedores y red, NO el volumen
docker compose up -d
sleep 5 && curl -s localhost:8080/    # continúa la cuenta
```

Ahora con `-v`:

```bash
docker compose down -v
docker compose up -d && sleep 5 && curl -s localhost:8080/    # vuelve a 1
```

### 6. Cambiar la configuración con `.env`

Edita `compose.yaml` para que el mensaje venga de una variable:

```yaml
    environment:
      REDIS_HOST: redis
      APP_MESSAGE: "${APP_MESSAGE:-Hola desde Docker Compose}"
```

```bash
echo 'APP_MESSAGE=Configurado desde .env' > .env
docker compose up -d                  # Compose recrea solo lo que ha cambiado
curl -s localhost:8080/info
```

### 7. Escalar la API

El puerto fijo `8080:8080` impide tener varias réplicas. Cámbialo a un rango:

```yaml
    ports:
      - "8080-8085:8080"
```

```bash
docker compose up -d --scale api=3
docker compose ps
for p in 8080 8081 8082; do curl -s localhost:$p/ ; done   # distinto "host", mismo contador
```

### 8. Un servicio opcional con profiles

Añade al final de `services:`:

```yaml
  redis-ui:
    image: redis/redisinsight:latest
    ports: ["5540:5540"]
    profiles: ["debug"]
```

```bash
docker compose up -d                   # redis-ui NO arranca
docker compose --profile debug up -d   # ahora sí: http://localhost:5540
```

> Aquí usamos `latest` por comodidad en una herramienta de depuración. En
> servicios de verdad, fija la versión.

### 9. Desarrollo con `watch`

```yaml
  api:
    develop:
      watch:
        - action: sync+restart
          path: ./app.py
          target: /app/app.py
```

```bash
docker compose watch                   # edita app.py y observa cómo se recarga
```

## Retos extra

1. Añade un límite de memoria a la API (`deploy.resources.limits.memory: 128m`)
   y compruébalo con `docker stats`.
2. Crea `compose.override.yaml` que cambie `APP_COLOR` a `green` y verifica con
   `docker compose config` que se fusiona automáticamente.
3. Haz que Redis exija contraseña (`--requirepass`) y pásala a la API con
   `REDIS_PASSWORD`. ¿Dónde guardarías esa contraseña?

## Limpieza

```bash
docker compose --profile debug down -v
rm -f .env compose.override.yaml
git checkout compose.yaml              # deshacer los cambios del lab
```
