# Lab 18 · Proyecto final: despliega esta presentación

## Objetivos

- Construir la imagen de la presentación del curso (reveal.js + nginx) a partir del `Dockerfile` del repositorio
- Ejecutarla en local como contenedor
- Cargarla en kind y desplegarla con Kustomize (`k8s/overlays/kind`)
- Revisar todo lo aprendido en unos manifiestos «de producción» y hacer un rolling update

## Duración

90 minutos.

## Requisitos

- Repositorio del curso clonado (el directorio raíz es el que contiene el `Dockerfile`)
- Docker o Podman, y el clúster kind `curso`

## Pasos

### 1. Leer antes de construir

Abre el `Dockerfile` y localiza:

- Las **dos etapas** (`build` con Node y `runtime` con nginx-unprivileged)
- Las **versiones fijadas** de las imágenes base
- El **usuario no root** (`USER 101`) y el puerto **8080**
- Qué se copia a la imagen final (solo `dist/`, sin `node_modules`)

### 2. Construir la imagen

```bash
docker build -t curso-kolbit:dev .
# o con Podman:
podman build --format docker -t curso-kolbit:dev .
docker images curso-kolbit
```

Pregunta: ¿cuánto pesa la imagen final comparada con `node:26.13.1-alpine`?

### 3. Ejecutarla en local

```bash
docker run -d --name curso -p 8080:8080 --read-only --tmpfs /tmp --cap-drop ALL curso-kolbit:dev
curl -s localhost:8080/healthz          # ok
curl -s localhost:8080/version.json
```

Abre <http://localhost:8080>: ¡es esta presentación! Pulsa `S` para ver las notas del ponente.
Fíjate en que funciona con el sistema de ficheros en **solo lectura** y **sin capabilities**.

```bash
docker rm -f curso
```

### 4. Cargar la imagen en kind

Con Docker:

```bash
kind load docker-image curso-kolbit:dev --name curso
```

Con Podman, la imagen se llama `localhost/curso-kolbit:dev`. Hay que reetiquetarla y pasarla
como archivo:

```bash
podman tag localhost/curso-kolbit:dev docker.io/library/curso-kolbit:dev
podman save -o /tmp/curso-kolbit.tar docker.io/library/curso-kolbit:dev
kind load image-archive /tmp/curso-kolbit.tar --name curso
```

Comprueba que el nodo la tiene:

```bash
docker exec curso-worker crictl images | grep curso-kolbit   # o "podman exec"
```

### 5. Revisar los manifiestos

```bash
kubectl kustomize k8s/overlays/kind | less
```

Busca y explica a tu compañero:

| Qué | Dónde |
| --- | --- |
| Namespace `curso-kolbit` y etiquetas comunes | `k8s/base/kustomization.yaml` |
| `securityContext` compatible con `restricted` | `k8s/base/deployment.yaml` |
| Probes de liveness y readiness sobre `/healthz` | `k8s/base/deployment.yaml` |
| requests/limits | `k8s/base/deployment.yaml` |
| PodDisruptionBudget y NetworkPolicy | `k8s/base/pdb.yaml`, `k8s/base/networkpolicy.yaml` |
| Imagen `curso-kolbit:dev` y 1 réplica | `k8s/overlays/kind/kustomization.yaml` |

### 6. Desplegar

```bash
kubectl apply -k k8s/overlays/kind
kubectl -n curso-kolbit rollout status deploy/curso-kolbit
kubectl -n curso-kolbit get deploy,pods,svc,pdb -o wide
kubectl -n curso-kolbit port-forward svc/curso-kolbit 8081:80
```

Abre <http://localhost:8081>. Si el Pod no arranca, aplica la metodología del lab 15
(`describe` → `logs` → `events`). El fallo más típico aquí es `ErrImagePull` porque la
imagen no se cargó en kind con el nombre correcto.

### 7. Rolling update y rollback

Cambia algo visible (por ejemplo, el título en `slides/00-bienvenida.md`), reconstruye con
otro tag y actualiza:

```bash
docker build -t curso-kolbit:dev2 .
kind load docker-image curso-kolbit:dev2 --name curso
kubectl -n curso-kolbit scale deploy/curso-kolbit --replicas=2
kubectl -n curso-kolbit set image deploy/curso-kolbit slides=curso-kolbit:dev2
kubectl -n curso-kolbit rollout status deploy/curso-kolbit
kubectl -n curso-kolbit rollout history deploy/curso-kolbit
kubectl -n curso-kolbit rollout undo deploy/curso-kolbit
```

### 8. Así se despliega en el clúster del profesor (Hetzner)

El profesor publica la imagen en GHCR desde su equipo y despliega con el overlay `hetzner`:

```bash
make image push        # ghcr.io/ibannieto/curso-kolbit:<git-sha>
make deploy            # kubectl apply -k k8s/overlays/hetzner + rollout status
make k8s-status
```

## Retos extra

1. **HPA**: crea un `HorizontalPodAutoscaler` para `curso-kolbit` (CPU 70 %, entre 2 y 5
   réplicas). Necesita metrics-server (lab 12). ¿Tiene sentido un HPA para una web estática?
2. **PDB + drain**: con 2 réplicas, haz `kubectl drain` del nodo donde está una de ellas y
   comprueba que la presentación sigue respondiendo durante el drain.
3. **Gateway API**: revisa el componente `k8s/components/httproute`. ¿Qué haría falta en
   kind para que funcione? (Un controlador de Gateway, como Envoy Gateway o Cilium, y un `Gateway`.)
4. **Registro privado**: si la imagen de GHCR es privada, crea un Secret
   `docker-registry` y referéncialo con `imagePullSecrets` desde un overlay nuevo.
5. **Seguridad**: etiqueta el namespace con `pod-security.kubernetes.io/enforce=restricted`
   y comprueba que el Deployment sigue funcionando.

## Limpieza

```bash
kubectl delete -k k8s/overlays/kind
```
