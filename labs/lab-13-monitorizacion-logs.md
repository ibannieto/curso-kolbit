# Lab 13 · Monitorización y logs

## Objetivos

- Consultar logs de uno o varios Pods, incluidos los de contenedores anteriores
- Usar los eventos del clúster como primera herramienta de diagnóstico
- Medir consumo con `kubectl top`
- Depurar un Pod con `kubectl debug` y un contenedor efímero
- (Opcional) Instalar Prometheus y Grafana con Helm

## Duración

60 minutos (más 30 de la parte opcional).

## Requisitos

- `contador` desplegado ([Lab 11](lab-11-despliegue-contador.md))
- metrics-server instalado ([Lab 12](lab-12-autoescalado.md))
- Para la parte opcional: Helm 4 (`helm version`)

## Pasos

### 1. Logs

```bash
kubectl -n contador logs deploy/api
kubectl -n contador logs -l app.kubernetes.io/name=api --prefix -f
```

En otra terminal, genera tráfico:

```bash
kubectl -n contador port-forward svc/api 8080:80 &
for i in $(seq 1 10); do curl -s localhost:8080/ >/dev/null; done
```

Prueba otras opciones:

```bash
kubectl -n contador logs deploy/api --since=5m --timestamps
kubectl -n contador logs deploy/redis --tail=20
```

### 2. Logs de un contenedor que ha fallado

Provoca un fallo: el contador muere al arrancar si existe `FAIL_ON_START`.

```bash
kubectl -n contador set env deployment/api FAIL_ON_START=lab13
kubectl -n contador get pods -w        # CrashLoopBackOff; Ctrl+C
```

Elige un Pod en `CrashLoopBackOff` y mira sus logs **actuales** y **anteriores**:

```bash
kubectl -n contador logs <pod-en-crash>
kubectl -n contador logs <pod-en-crash> --previous
```

Salida esperada:

```text
FATAL: FAIL_ON_START=lab13
```

> Gracias a `maxUnavailable: 0`, los Pods antiguos siguen sirviendo tráfico.

Arréglalo:

```bash
kubectl -n contador set env deployment/api FAIL_ON_START-
kubectl -n contador rollout status deployment/api
```

### 3. Eventos

```bash
kubectl -n contador get events --sort-by=.lastTimestamp | tail -20
kubectl -n contador events --for deployment/api
kubectl get events -A --field-selector type=Warning
```

### 4. Consumo

```bash
kubectl top nodes
kubectl -n contador top pods --containers
kubectl -n contador top pods --sort-by=memory
```

Compara el consumo real con los `requests` y `limits` de `api.yaml`.

### 5. Depurar con un contenedor efímero

La imagen de `contador` es mínima y el sistema de ficheros es de solo lectura.
Para investigar, añade un contenedor efímero con herramientas de red:

```bash
POD=$(kubectl -n contador get pod -l app.kubernetes.io/name=api -o jsonpath='{.items[0].metadata.name}')
kubectl -n contador debug -it "$POD" --image=nicolaka/netshoot:v0.16 \
  --target=api --profile=restricted -- bash
```

Dentro del contenedor efímero:

```bash
ps aux                      # ves los procesos de "api" (namespace de PID compartido)
curl -s localhost:8080/readyz
nslookup redis
exit
```

> `--profile=restricted` crea el contenedor efímero cumpliendo Pod Security
> `restricted`: el namespace `contador` avisa de todo lo que no lo cumpla.

### 6. (Opcional) Prometheus y Grafana con Helm

Crea `/tmp/kps-values.yaml` con una configuración mínima para kind:

```yaml
grafana:
  adminPassword: curso
alertmanager:
  enabled: false
prometheus:
  prometheusSpec:
    retention: 6h
    resources:
      requests: { cpu: 200m, memory: 400Mi }
kubeEtcd:
  enabled: false
kubeControllerManager:
  enabled: false
kubeScheduler:
  enabled: false
```

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace -f /tmp/kps-values.yaml
kubectl -n monitoring get pods -w      # espera a que todo esté Running
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
```

Abre <http://localhost:3000> (usuario `admin`, contraseña `curso`) y explora:

- **Kubernetes / Compute Resources / Namespace (Pods)** → namespace `contador`
- Repite la carga del Lab 12 y mira cómo suben la CPU y las réplicas

## Retos extra

1. En Grafana → *Explore*, escribe una consulta PromQL que muestre las réplicas
   disponibles del Deployment `api`
   (`kube_deployment_status_replicas_available{namespace="contador"}`).
2. Usa `kubectl debug node/curso-worker -it --image=busybox:1.37` y busca los
   logs de los contenedores en `/host/var/log/containers/`.
3. Instala `stern` y sigue los logs de todos los Pods del namespace con colores.

## Limpieza

```bash
kill %1 2>/dev/null
helm uninstall monitoring -n monitoring 2>/dev/null
kubectl delete namespace monitoring --ignore-not-found
```
