# Lab 11 · Desplegar contador en Kubernetes

## Objetivos

- Construir la imagen de `contador` y cargarla en kind
- Desplegar la aplicación completa con Kustomize (`kubectl apply -k`)
- Entender cómo se conectan ConfigMap, Secret, Deployments y Services
- Cambiar la configuración y aplicarla con un `rollout restart`

## Duración

60 minutos.

## Requisitos

- Clúster `kind-curso` funcionando
- Imagen de `contador` del Módulo 3 (la reconstruimos en el paso 1)

## Pasos

### 1. Construir y cargar la imagen

kind no puede descargar imágenes de tu Docker local: hay que **cargarlas** en
sus nodos.

```bash
docker build -t contador:1.0 examples/contador
kind load docker-image contador:1.0 --name curso
```

> **Con Podman**, la imagen se etiqueta como `localhost/contador:1.0`. Etiquétala
> con el nombre que espera el manifiesto y cárgala como archivo:
>
> ```bash
> podman build -t docker.io/library/contador:1.0 examples/contador
> podman save docker.io/library/contador:1.0 -o /tmp/contador.tar
> kind load image-archive /tmp/contador.tar --name curso
> ```

Comprueba que está en los nodos:

```bash
docker exec curso-worker crictl images | grep contador
```

### 2. Revisar los manifiestos

```bash
cat examples/contador/k8s/kustomization.yaml
kubectl kustomize examples/contador/k8s | less
```

Busca en la salida:

- El namespace `contador`, con Pod Security `baseline` (obligatorio) y `restricted` (solo avisos)
- Cómo `api.yaml` usa `envFrom` (ConfigMap) y `secretKeyRef` (Secret)
- Cómo Redis recibe la contraseña con `--requirepass $(REDIS_PASSWORD)`
- Las tres probes de la API y su `securityContext`

### 3. Desplegar

```bash
kubectl apply -k examples/contador/k8s
kubectl -n contador get all
kubectl -n contador rollout status deployment/api
```

Salida esperada:

```text
NAME                        READY   STATUS    RESTARTS   AGE
pod/api-6c9d8f7b5d-4xk2p    1/1     Running   0          40s
pod/api-6c9d8f7b5d-q8w7z    1/1     Running   0          40s
pod/redis-7f5c9b6d8-lm2nb   1/1     Running   0          40s
```

> El HPA aparecerá con `<unknown>` en los targets hasta que instalemos
> metrics-server en el Lab 12.

### 4. Probar la API

```bash
kubectl -n contador port-forward svc/api 8080:80 &
curl -s localhost:8080/
curl -s localhost:8080/
curl -s localhost:8080/info
```

Repite `curl localhost:8080/` varias veces: `visits` aumenta. El campo `host` no
cambia porque `port-forward` conecta con **un único Pod**. Para ver el balanceo:

```bash
kubectl -n contador run tmp --rm -it --image=busybox:1.37 --restart=Never \
  -- sh -c 'for i in 1 2 3 4 5 6; do wget -qO- api; done'
```

### 5. Cambiar la configuración

```bash
kubectl -n contador patch configmap contador-config \
  --type merge -p '{"data":{"APP_MESSAGE":"Configuración cambiada en caliente","APP_COLOR":"green"}}'
curl -s localhost:8080/info        # ¡todavía el mensaje antiguo!
```

Las variables de entorno se leen **al arrancar**. Reinicia los Pods:

```bash
kubectl -n contador rollout restart deployment/api
kubectl -n contador rollout status deployment/api
kill %1; kubectl -n contador port-forward svc/api 8080:80 &
curl -s localhost:8080/info
```

### 6. ¿Qué pasa si Redis cae?

```bash
kubectl -n contador scale deployment redis --replicas=0
kubectl -n contador get pods -w      # Ctrl+C tras unos segundos
```

Los Pods de `api` pasan a `0/1 READY` (falla la readinessProbe), pero **no se
reinician** (la livenessProbe solo comprueba el proceso). Restaura Redis:

```bash
kubectl -n contador scale deployment redis --replicas=1
```

¿Se ha perdido el contador? ¿Por qué? (Pista: `emptyDir`. Lo arreglamos en el Módulo 6.)

## Retos extra

1. Decodifica la contraseña de Redis: `kubectl -n contador get secret contador-secret -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d`.
   ¿Qué conclusión sacas sobre los Secrets?
2. Crea un overlay en `/tmp/overlay-dev` que use la base, cambie `APP_COLOR` con
   un `configMapGenerator` (`behavior: merge`) y ponga 1 réplica.
3. Intenta desplegar un Pod con `securityContext.runAsUser: 0` en el namespace
   `contador`. ¿Qué responde Pod Security Admission?

## Limpieza

```bash
kill %1 2>/dev/null
```

> Deja la aplicación desplegada: la usamos en los labs 12 y 13.
