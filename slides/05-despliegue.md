<!-- .slide: class="module center-v" -->

<span class="kicker">Módulo 5 · Día 5</span>

# Despliegue de aplicaciones en Kubernetes

<div class="agenda">

Manifiestos y Kustomize · Helm · Controladores · Autoescalado · Probes · ConfigMaps y Secrets · Monitorización y logs

</div>

---

## Del YAML suelto a una aplicación

Una aplicación real en Kubernetes son **varios objetos** que viajan juntos:

- **Deployment** (o StatefulSet): la app
- **Service**: cómo se llega a ella
- **ConfigMap** y **Secret**: su configuración
- **HPA**: cómo escala
- Y quizá un **HTTPRoute**, una **NetworkPolicy**, un **PodDisruptionBudget**…

<small>Hilo conductor de hoy: desplegar `contador` + Redis en kind</small>

---

## Manifiestos en git

```text
examples/contador/k8s/
├── kustomization.yaml
├── namespace.yaml
├── configmap.yaml
├── secret.yaml        # ⚠ solo demo
├── redis.yaml
├── api.yaml
├── service.yaml
└── hpa.yaml
```

```bash
kubectl apply -f examples/contador/k8s/   # todos los ficheros
kubectl diff  -f examples/contador/k8s/   # qué cambiaría
```

---

## `apply`: client-side vs. server-side

- `kubectl apply` **fusiona** tu YAML con lo que hay en el clúster
- **Server-side apply** (`--server-side`): el API server calcula la fusión y registra **quién gestiona cada campo** (`managedFields`)
- Detecta conflictos entre herramientas (tú, el HPA, Flux…)

```bash
kubectl apply --server-side -f api.yaml
kubectl get deploy api -o yaml --show-managed-fields | less
```

---

## Kustomize: personalizar sin plantillas

<div class="cols">
<div>

```text
k8s/
├── base/
│   ├── kustomization.yaml
│   └── *.yaml
└── overlays/
    ├── dev/
    │   └── kustomization.yaml
    └── prod/
        └── kustomization.yaml
```

</div>
<div>

- La **base** es YAML válido, sin variables
- Los **overlays** parchean: réplicas, imagen, namespace, labels…
- Integrado en kubectl: `kubectl apply -k`

</div>
</div>

---

## Un overlay de Kustomize

```yaml
# overlays/prod/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: contador-prod
resources:
  - ../../base
images:
  - name: contador
    newName: ghcr.io/miempresa/contador
    newTag: "1.4.2"
patches:
  - target: { kind: Deployment, name: api }
    patch: |-
      - { op: replace, path: /spec/replicas, value: 4 }
```

---

## Helm 4: el gestor de paquetes

- **Chart**: paquete de plantillas YAML + `values.yaml`
- **Release**: una instalación concreta de un chart en el clúster
- **Values**: los parámetros que personalizas
- Repositorios clásicos o **OCI** (`oci://ghcr.io/...`)

<div class="logo-row">
  <img src="assets/img/logos/helm.svg" alt="Helm" style="height:110px">
</div>

---

## Helm en la práctica

```bash
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts

helm install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace -f values.yaml

helm list -A
helm upgrade monitoring prometheus-community/kube-prometheus-stack -f values.yaml
helm rollback monitoring 1
helm uninstall monitoring -n monitoring
```

<small>¿Kustomize o Helm? Kustomize para tus apps; Helm para instalar software de terceros. Se pueden combinar.</small>

---

## Controladores de carga de trabajo

| Controlador | Para qué |
| --- | --- |
| **Deployment** | Apps sin estado (gestiona ReplicaSets) |
| **StatefulSet** | Apps con identidad y disco estables (BD, colas) |
| **DaemonSet** | Un Pod por nodo (agentes de logs, CNI, monitorización) |
| **Job** | Tarea que termina (migración, batch) |
| **CronJob** | Job programado (backups, informes) |

---

## StatefulSet en 30 segundos

- Pods con **nombre estable**: `redis-0`, `redis-1`…
- **Volumen propio** para cada Pod (`volumeClaimTemplates`)
- Arranque y parada **ordenados**
- Necesita un **Service headless** para el DNS de cada Pod

<div class="box">

Lo usamos en el Módulo 6 para dar persistencia a Redis.

</div>

---

## DaemonSet, Job y CronJob

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: backup
spec:
  schedule: "0 3 * * *"          # todos los días a las 3:00
  jobTemplate:
    spec:
      backoffLimit: 2
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - { name: backup, image: "busybox:1.37", command: ["sh", "-c", "echo backup"] }
```

---

## Probes: ¿está viva? ¿está lista?

| Probe | Pregunta | Si falla |
| --- | --- | --- |
| `startupProbe` | ¿Ha terminado de arrancar? | Sigue esperando; luego reinicia |
| `livenessProbe` | ¿Sigue viva? | **Reinicia** el contenedor |
| `readinessProbe` | ¿Puede recibir tráfico? | La **saca del Service** |

<div class="box warn">

No compruebes dependencias externas en la liveness: si cae Redis, Kubernetes reiniciaría todas las APIs en bucle.

</div>

---

## Probes en contador

```yaml
startupProbe:
  httpGet: { path: /healthz, port: http }
  periodSeconds: 2
  failureThreshold: 15        # hasta 30 s para arrancar
livenessProbe:
  httpGet: { path: /healthz, port: http }   # solo el proceso
  periodSeconds: 10
readinessProbe:
  httpGet: { path: /readyz, port: http }    # incluye Redis
  periodSeconds: 5
```

---

## Escalabilidad automática

<div class="cols">
<div>

**Pods**

- **HPA**: más o menos réplicas según CPU, memoria o métricas propias
- **VPA**: ajusta requests y limits
- **KEDA**: escala por eventos (colas, Kafka…), incluso a cero

</div>
<div>

**Nodos**

- **Cluster Autoscaler**: añade o quita nodos del grupo
- **Karpenter**: aprovisiona el nodo más adecuado al momento

</div>
</div>

<small>El HPA necesita **metrics-server** (v0.9.1) y que los Pods declaren `requests`</small>

---

## HorizontalPodAutoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api
spec:
  scaleTargetRef: { apiVersion: apps/v1, kind: Deployment, name: api }
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target: { type: Utilization, averageUtilization: 50 }
```

```bash
kubectl get hpa api -w
```

---

<!-- .slide: class="meme" -->

<div class="meme-term">
<div class="bar">kubectl get hpa -n contador -w</div>

```text
NAME   TARGETS         MINPODS   MAXPODS   REPLICAS
api    cpu: 12%/50%    2         50        2
api    cpu: 380%/50%   2         50        8
api    cpu: 410%/50%   2         50        32
api    cpu: 395%/50%   2         50        50
```

</div>

<p class="meme-caption">Cuando alguien deja un bucle infinito en <code>/load</code> y el HPA se lo toma como tráfico real</p>

<small>Pon siempre un <code>maxReplicas</code> razonable… y mira la factura antes que tu jefe.</small>

---

<!-- .slide: class="lab" -->

## Lab 11 · Desplegar contador

- Construir la imagen y cargarla en kind
- `kubectl apply -k examples/contador/k8s`
- Probar la API con `port-forward`
- Cambiar el ConfigMap y hacer `rollout restart`

<small>⏱ 60 min · `labs/lab-11-despliegue-contador.md`</small>

---

## ConfigMaps: configuración fuera de la imagen

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: contador-config
data:
  APP_MESSAGE: "¡Hola desde Kubernetes!"
  APP_COLOR: "blue"
  nginx.conf: |
    server { listen 8080; }
```

- La misma imagen en dev, test y prod; cambia la configuración
- Límite: 1 MiB por objeto

---

## Usar un ConfigMap

<div class="cols">
<div>

**Como variables de entorno**

```yaml
envFrom:
  - configMapRef:
      name: contador-config
```

Se leen **solo al arrancar**

</div>
<div>

**Como ficheros**

```yaml
volumes:
  - name: conf
    configMap:
      name: contador-config
```

Se actualizan solos (con cierto retraso)

</div>
</div>

<small>Con `immutable: true`, más rendimiento y nadie lo cambia por accidente</small>

---

## Secrets

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: contador-secret
type: Opaque
stringData:                      # en claro; el API server lo guarda en base64
  REDIS_PASSWORD: "cambia-esto"
```

```yaml
env:
  - name: REDIS_PASSWORD
    valueFrom:
      secretKeyRef: { name: contador-secret, key: REDIS_PASSWORD }
```

---

<!-- .slide: class="meme" -->

<div class="meme-two">
<div>
<span class="tag">Lo que crees</span>

`kind: Secret` 🔐

«Está cifrado, ¿no?»

</div>
<div>
<span class="tag">Lo que es</span>

`echo Y2FtYmlhLWVzdG8= | base64 -d`

`cambia-esto`

</div>
</div>

<p class="meme-caption">base64 es una codificación, no un cifrado</p>

---

## Secrets de verdad

- Activa el **cifrado en reposo** de etcd (`EncryptionConfiguration`, o KMS)
- Restringe con **RBAC** quién puede hacer `get secrets`
- **Nunca en git en claro**. Alternativas:
  - **External Secrets Operator**: Vault/OpenBao, AWS SM, GCP SM…
  - **Sealed Secrets** o **SOPS**: cifrados dentro del repositorio
- Rotación: **Reloader** reinicia los Pods cuando cambia un Secret o ConfigMap

---

## Cambiar la configuración en caliente

```bash
kubectl -n contador edit configmap contador-config
# las variables de entorno NO se recargan solas:
kubectl -n contador rollout restart deployment api
kubectl -n contador rollout status deployment api
```

<div class="box tip">

Patrón GitOps: un hash del ConfigMap en una anotación del Pod (Kustomize `configMapGenerator` lo hace solo), así cada cambio provoca un rollout.

</div>

---

<!-- .slide: class="lab" -->

## Lab 12 · Autoescalado

- Instalar metrics-server en kind
- `kubectl top nodes` y `kubectl top pods`
- Crear el HPA de contador
- Generar carga contra `/load` y ver cómo escala y desescala

<small>⏱ 45 min · `labs/lab-12-autoescalado.md`</small>

---

## Monitorización y registro: las tres señales

| Señal | Pregunta | Herramientas |
| --- | --- | --- |
| **Métricas** | ¿Cómo va? | metrics-server, **Prometheus**, Grafana |
| **Logs** | ¿Qué ha pasado? | `kubectl logs`, **Loki**, Fluent Bit |
| **Trazas** | ¿Dónde se pierde el tiempo? | **OpenTelemetry**, Jaeger, Tempo |

<small>Y los **eventos** de Kubernetes: la primera pista casi siempre</small>

---

## Logs con kubectl

```bash
kubectl logs deploy/api -n contador            # un Pod del Deployment
kubectl logs -l app.kubernetes.io/name=api -f  # todos los Pods con esa label
kubectl logs api-7d9f-x2k -c api --previous    # el contenedor ANTERIOR (tras un crash)
kubectl logs api-7d9f-x2k --since=10m --timestamps
```

- La app escribe en **stdout/stderr**; el runtime guarda los logs en el nodo
- Se pierden si el Pod desaparece → hace falta **centralizarlos**

---

## Eventos y métricas

```bash
kubectl get events -n contador --sort-by=.lastTimestamp
kubectl describe pod api-7d9f-x2k        # eventos al final

kubectl top nodes
kubectl top pods -n contador --containers
```

- Los eventos se guardan **solo una hora** (por defecto)
- `kubectl top` depende de **metrics-server**: datos en vivo, sin histórico

---

## Prometheus + Grafana

<div class="cols wide-left">
<div>

- **Prometheus** recoge métricas (*pull*) y las guarda como series temporales
- **Grafana** las muestra en dashboards
- **Alertmanager** envía alertas
- Todo junto: chart `kube-prometheus-stack`

</div>
<div class="center">

<img src="assets/img/logos/prometheus.svg" alt="Prometheus" style="height:220px">

</div>
</div>

```promql
sum(rate(container_cpu_usage_seconds_total{namespace="contador"}[5m])) by (pod)
```

---

## Logs centralizados y OpenTelemetry

- **Fluent Bit** o el colector de **OpenTelemetry** como DaemonSet → leen los logs de cada nodo
- Los envían a **Loki**, Elasticsearch/OpenSearch o un SaaS
- **OpenTelemetry**: estándar abierto para métricas, logs y trazas
- Logs **estructurados** (JSON), con un id de traza para correlacionar

---

<!-- .slide: class="lab" -->

## Lab 13 · Monitorización y logs

- Logs, eventos y `kubectl top` de contador
- Depurar con `kubectl debug` y un contenedor efímero
- (Opcional) kube-prometheus-stack con Helm y dashboards de Grafana

<small>⏱ 60 min · `labs/lab-13-monitorizacion-logs.md`</small>

---

## Resumen del módulo

- Manifiestos en **git**; **Kustomize** para tus apps y **Helm** para terceros
- El controlador adecuado para cada carga: Deployment, StatefulSet, DaemonSet, Job o CronJob
- **Probes** bien diseñadas y **HPA** con requests declarados
- **ConfigMaps** para la configuración; **Secrets** con cifrado en reposo y sin git en claro
- Métricas, logs y trazas: Prometheus, Loki y OpenTelemetry

<div class="box tip">

Siguiente: administrar el clúster (recursos, nodos, RBAC, cuotas y almacenamiento).

</div>

---

<!-- .slide: class="quiz" -->

## Día 5

1. Readiness frente a liveness: ¿qué hace cada una al fallar? <span class="fragment answer">Readiness saca el Pod del Service; liveness reinicia el contenedor</span>
2. ¿Qué necesita el HPA para escalar por CPU? <span class="fragment answer">metrics-server y que los Pods declaren `requests` de CPU</span>
3. ¿Un Secret va cifrado? <span class="fragment answer">No por defecto: es base64. Hace falta cifrado en reposo de etcd y RBAC</span>
4. Cambias un ConfigMap que la app lee como variable de entorno. ¿Se entera? <span class="fragment answer">No, hasta que se recrean los Pods (`kubectl rollout restart`)</span>

---

## Referencias

- Kustomize: [kubectl.docs.kubernetes.io](https://kubectl.docs.kubernetes.io/)
- Helm: [helm.sh/docs](https://helm.sh/docs/)
- HPA: [kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- Secrets: [kubernetes.io/docs/concepts/security/secrets-good-practices](https://kubernetes.io/docs/concepts/security/secrets-good-practices/)
- kube-prometheus-stack: [github.com/prometheus-community/helm-charts](https://github.com/prometheus-community/helm-charts)
