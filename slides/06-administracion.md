<!-- .slide: class="module center-v" -->

<span class="kicker">Módulo 6 · Días 6 y 7</span>

# Administración de clústeres Kubernetes

<div class="agenda">

Administración · Recursos y límites · Multinodo · Troubleshooting · Usuarios y RBAC · Cuotas · Almacenamiento persistente

</div>

Note:
Día 6: parte I (administración, recursos, multinodo, troubleshooting). Día 7: parte II (RBAC, cuotas, almacenamiento) y proyecto final.

---

<!-- .slide: class="meme" -->

<div class="meme-iceberg">
<div class="sky" data-label="superficie"><span><code>kubectl apply</code> · Pods · Deployments · Services</span></div>
<div class="l1" data-label="nivel 1"><span>ConfigMaps · Secrets · HPA · Gateway API · Helm</span></div>
<div class="l2" data-label="nivel 2"><span>requests/limits · QoS · PDB · taints · RBAC · Pod Security</span></div>
<div class="l3" data-label="nivel 3"><span>CNI · CSI · CRDs y operadores · admission webhooks · finalizers</span></div>
<div class="l4" data-label="nivel 4"><span>quórum de etcd · certificados que caducan · <code>ndots:5</code> · conntrack lleno · CPU throttling sin superar el límite</span></div>
<div class="l5" data-label="el abismo"><span>namespace en <code>Terminating</code> desde hace 3 semanas · «no puede ser DNS» (era DNS)</span></div>
</div>

<p class="meme-caption">El iceberg de Kubernetes. Hoy bajamos unos cuantos niveles.</p>

Note:
Formato clásico de meme de la comunidad. Lo que hay en cada nivel es real: ndots:5 (cada búsqueda DNS de un nombre corto prueba primero los dominios de búsqueda del clúster), la tabla conntrack del nodo llena con mucho tráfico UDP, el throttling por cuotas CFS aunque la CPU media sea baja, y los namespaces atascados en Terminating por un finalizer cuyo controlador ya no existe. Preguntar: ¿en qué nivel estáis?

---

## ¿Qué hace quien administra un clúster?

<div class="cols">
<div>

- **Ciclo de vida**: instalar, actualizar y retirar
- **Capacidad**: nodos, recursos, cuotas
- **Seguridad**: usuarios, RBAC, certificados

</div>
<div>

- **Continuidad**: backups de etcd, DR
- **Observabilidad y soporte**: «mi Pod no arranca»
- **Plataforma**: CNI, CSI, Gateway, GitOps…

</div>
</div>

<div class="box tip">

En un Kubernetes gestionado (EKS, GKE, AKS) el proveedor se ocupa del *control plane*, pero **todo lo demás sigue siendo tuyo**.

</div>

Note:
Gestionado (EKS/GKE/AKS): el proveedor opera control plane y etcd, upgrades con un botón, se paga una cuota. Autogestionado (kubeadm, Talos, k3s): control total, tú operas etcd, backups y upgrades. El clúster del profesor: Talos 1.14 en Hetzner, Kubernetes 1.37.2, Cilium, Flux.

---

## Talos Linux: un SO inmutable para Kubernetes

<div class="cols wide-left">
<div>

- Sin SSH, sin shell y sin gestor de paquetes
- Se gestiona **solo por API** con `talosctl`
- Configuración declarativa (un YAML por nodo)
- Upgrades atómicos con rollback
- Superficie de ataque mínima

</div>
<div>

```bash
talosctl -n 10.0.0.5 version
talosctl -n 10.0.0.5 dashboard
talosctl -n 10.0.0.5 \
  upgrade-k8s --to 1.37.2
talosctl -n 10.0.0.5 \
  etcd snapshot etcd.db
```

</div>
</div>

---

## Upgrades: la política de *version skew*

- Kubernetes saca **3 minors al año** y cada una tiene soporte durante unos **14 meses**
- Se actualiza **una minor cada vez**: 1.35 → 1.36 → 1.37
- Orden: **control plane primero**, después los nodos (kubelet)
- `kubelet` puede ir hasta **3 minors por detrás** del apiserver, pero nunca por delante
- `kubectl`: ±1 minor respecto al apiserver
- Antes de cada salto: lee las *release notes* y revisa las APIs deprecadas

```bash
kubectl version            # cliente y servidor
kubectl get nodes          # columna VERSION de cada kubelet
```

Note:
Herramientas para detectar APIs deprecadas: kubent, pluto. kubeadm: kubeadm upgrade plan / apply. Talos: talosctl upgrade-k8s.

---

## etcd: el corazón del clúster

- **Todo** el estado del clúster vive en etcd
- Sin backup de etcd **no hay recuperación** ante un desastre
- Snapshots periódicos, guardados **fuera** del clúster

```bash
# kubeadm (en un nodo de control plane)
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-$(date +%F).db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Talos
talosctl -n 10.0.0.5 etcd snapshot etcd.db
```

<div class="box warn">

Un backup que no has restaurado nunca es solo una esperanza.

</div>

---

## Alta disponibilidad del control plane

<div class="cols">
<div>

- **3 o 5** nodos de control plane: siempre un número impar
- `etcd` necesita **quórum**, es decir, mayoría de miembros vivos
- Un **balanceador** (o VIP) delante del API server, puerto 6443
- Los workers se pierden sin drama: sus Pods se reprograman

</div>
<div>

| Miembros etcd | Quórum | Fallos tolerados |
| --- | --- | --- |
| 1 | 1 | 0 |
| 3 | 2 | **1** |
| 4 | 3 | 1 |
| 5 | 3 | **2** |

<small>4 nodos toleran lo mismo que 3: por eso, impar.</small>

</div>
</div>

Note:
Sin quórum, etcd deja de aceptar escrituras: los Pods que ya corren siguen funcionando, pero no se puede cambiar nada (ni reprogramar). Topologías: etcd «stacked» (en los mismos nodos que el control plane, lo habitual con kubeadm y Talos) o externo. En el clúster de Hetzner del profesor hay 1 control plane: perfecto para demos, no para producción.

---

## Certificados del clúster

- Los componentes hablan entre sí con **TLS mutuo**
- Con kubeadm, los certificados caducan al **año**
- Se renuevan automáticamente en cada `kubeadm upgrade`… si actualizas
- Talos y los clústeres gestionados los rotan por ti

```bash
sudo kubeadm certs check-expiration
sudo kubeadm certs renew all
```

<small>Un clúster que lleva un año sin actualizarse puede «morir» el día que caducan sus certificados.</small>

---

## Requests y limits

<div class="cols">
<div>

**requests**: lo que se *reserva*

- Lo usa el **scheduler** para decidir el nodo
- Garantizado para el contenedor

**limits**: el *máximo*

- Lo aplica el kernel (cgroups v2)

</div>
<div>

```yaml
resources:
  requests:
    cpu: 100m       # 0,1 vCPU
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

</div>
</div>

<div class="box">

`1` CPU = 1 vCPU/core · `100m` = 0,1 CPU · `Mi` = mebibytes (1024²)

</div>

---

## CPU ≠ memoria

<div class="cols">
<div class="box">

**CPU (comprimible)**

- Si superas el limit → **throttling**
- El proceso va más lento, pero sigue vivo
- Muchos equipos **no ponen limit de CPU**, solo request

</div>
<div class="box danger">

**Memoria (no comprimible)**

- Si superas el limit → **OOMKilled** (exit 137)
- El kubelet reinicia el contenedor
- Pon **siempre** request y limit de memoria

</div>
</div>

```bash
kubectl describe pod api-7d9f | grep -A3 "Last State"
#   Last State: Terminated   Reason: OOMKilled   Exit Code: 137
```

---

<!-- .slide: class="meme" -->

<div class="meme-term">
<div class="bar">kubectl get pods -n contador · lunes 09:01</div>
<pre><code data-noescape class="nohighlight">NAME                   READY   STATUS             RESTARTS        AGE
api-7d9f6c5b8-x2k4q    0/1     <span class="red">CrashLoopBackOff</span>   <span class="yellow">4815 (42s ago)</span>   17d
api-7d9f6c5b8-p9z1m    0/1     <span class="red">OOMKilled</span>          <span class="yellow">4790 (12s ago)</span>   17d
redis-0                1/1     <span class="green">Running</span>            0               17d</code></pre>
</div>

<p class="meme-caption">«Nadie dijo nada en todo el fin de semana… porque no había alertas.»</p>

---

## Clases de QoS

| QoS | Condición | Si falta memoria en el nodo… |
| --- | --- | --- |
| **Guaranteed** | requests = limits (CPU y memoria) en todos los contenedores | Es lo último que se desaloja |
| **Burstable** | Hay algún request o limit, pero no son iguales | Se desaloja después |
| **BestEffort** | Ni requests ni limits | **Es lo primero** que se desaloja |

```bash
kubectl get pod api-7d9f -o jsonpath='{.status.qosClass}'
```

---

## LimitRange: valores por defecto por namespace

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: defaults
  namespace: contador
spec:
  limits:
    - type: Container
      defaultRequest: { cpu: 50m, memory: 64Mi }
      default:        { cpu: 500m, memory: 256Mi }
      max:            { cpu: "1", memory: 512Mi }
```

- Rellena requests y limits a los contenedores que **no los declaran**
- Rechaza los Pods que superan `max`
- Solo se aplica **al crear** el Pod (no cambia los que ya existen)

---

## In-place pod resize (GA)

- Hasta hace poco, cambiar `resources` suponía **recrear el Pod**
- Ahora se pueden cambiar CPU y memoria **sin reiniciar**, mediante el subrecurso `resize`
- `resizePolicy` decide si un cambio requiere reiniciar el contenedor

```bash
kubectl patch pod api-7d9f -n contador --subresource resize \
  --patch '{"spec":{"containers":[{"name":"api",
    "resources":{"requests":{"cpu":"200m"},"limits":{"cpu":"800m"}}}]}}'

kubectl get pod api-7d9f -n contador \
  -o jsonpath='{.status.containerStatuses[0].resources}'
```

<small>En un Deployment, lo normal sigue siendo cambiar la plantilla (se hace un rolling update).</small>

---

## El scheduler

1. **Filtrado**: ¿qué nodos *pueden* ejecutar el Pod? (recursos, taints, afinidad, volúmenes…)
2. **Puntuación**: de esos, ¿cuál es el *mejor*? (reparto de carga, afinidad preferida…)
3. **Binding**: asigna el Pod al nodo y el kubelet lo arranca

```bash
kubectl get pod api-7d9f -o wide          # columna NODE
kubectl describe pod pendiente | tail -5
# Warning  FailedScheduling  0/3 nodes are available:
#   1 node(s) had untolerated taint ..., 2 Insufficient memory.
```

---

## ¿Dónde se ejecuta mi Pod?

<div class="cols">
<div>

**nodeSelector** (simple)

```yaml
nodeSelector:
  disktype: ssd
```

**nodeAffinity** (expresiva)

- `required…`: obligatoria
- `preferred…`: con peso

</div>
<div>

**podAntiAffinity**: separa réplicas

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          topologyKey: kubernetes.io/hostname
          labelSelector:
            matchLabels: { app.kubernetes.io/name: api }
```

</div>
</div>

Note:
topologySpreadConstraints (maxSkew, topologyKey kubernetes.io/hostname o topology.kubernetes.io/zone, whenUnsatisfiable) reparte muchas réplicas de forma uniforme entre nodos o zonas; es más fino que la antiafinidad. Se practica en los retos del lab 14.

---

## Taints y tolerations

- **Taint** (en el nodo): «aquí no entra nadie… salvo quien lo tolere»
- **Toleration** (en el Pod): «yo sí aguanto ese taint»
- Efectos: `NoSchedule`, `PreferNoSchedule`, `NoExecute` (además expulsa los Pods)

```bash
kubectl taint nodes worker-2 dedicado=gpu:NoSchedule
kubectl taint nodes worker-2 dedicado=gpu:NoSchedule-   # quitarlo
```

```yaml
tolerations:
  - key: dedicado
    operator: Equal
    value: gpu
    effect: NoSchedule
```

<small>Tolerar un taint **no obliga** a ir a ese nodo: para eso se combina con afinidad.</small>

---

## Añadir y retirar nodos

```bash
# Añadir (kubeadm): el token caduca en 24 h, genera uno nuevo
kubeadm token create --print-join-command
# Añadir (Talos): el nodo arranca en modo mantenimiento y recibe su config
talosctl apply-config --insecure -n 10.0.0.9 --file worker.yaml

# Retirar: vaciar, sacar del clúster y apagar la máquina
kubectl drain worker-3 --ignore-daemonsets --delete-emptydir-data
kubectl delete node worker-3
```

- En la nube, **Cluster Autoscaler** o **Karpenter** añaden y retiran nodos solos
- Etiqueta los nodos (`topology.kubernetes.io/zone`, `node.kubernetes.io/instance-type`) para poder programar sobre ellos

---

## Mantenimiento de nodos

```bash
kubectl cordon worker-1          # no se programan Pods nuevos
kubectl drain worker-1 \
  --ignore-daemonsets --delete-emptydir-data   # desaloja los Pods
# ... parchear, reiniciar, actualizar ...
kubectl uncordon worker-1        # vuelve al servicio
```

- `drain` respeta los **PodDisruptionBudgets**
- Los Pods sueltos (sin controlador) **no vuelven**: usa siempre Deployments
- Los DaemonSets se quedan (por eso `--ignore-daemonsets`)

---

## PodDisruptionBudget

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: api
  namespace: contador
spec:
  minAvailable: 1          # o maxUnavailable: 1
  selector:
    matchLabels: { app.kubernetes.io/name: api }
```

- Protege frente a **interrupciones voluntarias**: drain, upgrades, autoscaler
- No protege si se cae el nodo (eso es una interrupción involuntaria)
- Un PDB con `minAvailable` igual al número de réplicas **bloquea el drain**

---

<!-- .slide: class="lab" -->

## Lab 14 · Recursos y scheduling

- Requests, limits y clases de QoS
- LimitRange con valores por defecto
- Taints, tolerations y afinidad en el clúster kind multinodo
- `cordon` y `drain` con un PodDisruptionBudget

```bash
kubectl get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass,NODE:.spec.nodeName
```

<small>⏱ 60 min · `labs/lab-14-recursos-scheduling.md`</small>

---

## Troubleshooting: la metodología

```bash
kubectl get pods -n contador -o wide        # 1. ¿Qué estado tiene?
kubectl describe pod <pod> -n contador      # 2. Eventos y condiciones
kubectl logs <pod> -n contador [--previous] # 3. ¿Qué dice la app?
kubectl get events -n contador \
  --sort-by=.lastTimestamp                  # 4. ¿Qué ha pasado alrededor?
kubectl exec -it <pod> -n contador -- sh    # 5. Mirar por dentro
kubectl debug -it <pod> --image=busybox     # 6. ...o con un contenedor de debug
```

<div class="box tip">

`--previous`: los logs del contenedor **anterior**, el que se murió. Imprescindible en CrashLoopBackOff.

</div>

Note:
Herramientas recomendadas: k9s (TUI), stern (logs de varios Pods: stern -n contador -l app.kubernetes.io/name=api --since 10m), kubectx/kubens, Headlamp (UI web de la CNCF).

---

## Estados típicos y su causa habitual

| Estado | Causa habitual | Mira en… |
| --- | --- | --- |
| `Pending` | Faltan recursos, taints o un PVC sin enlazar | `describe` → Events |
| `ImagePullBackOff` / `ErrImagePull` | Tag inexistente, registro privado sin secret | `describe` → Events |
| `CrashLoopBackOff` | La app termina al arrancar | `logs --previous` |
| `OOMKilled` | Se supera el limit de memoria | `describe` → Last State |
| `CreateContainerConfigError` | Falta un ConfigMap, Secret o clave | `describe` → Events |
| `Running` pero 0/1 Ready | Falla la readiness probe | `describe` → Events |

---

## «El Service no responde»

```bash
kubectl get svc api -n contador
kubectl get endpointslices -n contador -l kubernetes.io/service-name=api
# Si no hay endpoints → el selector no coincide con las etiquetas de los Pods
kubectl get pods -n contador --show-labels
kubectl describe svc api -n contador | grep -i selector

# Probar desde dentro del clúster
kubectl run tmp --rm -it --image=busybox:1.38 --restart=Never -- \
  wget -qO- http://api.contador.svc.cluster.local
```

<small>Las causas más comunes: selector mal escrito, `targetPort` equivocado o Pods que no están Ready.</small>

---

## Probes mal configuradas

- **liveness** demasiado agresiva → reinicios en bucle cuando la app va lenta
- **readiness** apuntando a un puerto o una ruta equivocados → nunca recibe tráfico
- Arranque lento → usa una **startupProbe** en vez de inflar `initialDelaySeconds`
- La liveness **no debe** comprobar dependencias (BD, Redis…): eso es trabajo de la readiness

```bash
kubectl describe pod api-7d9f | grep -E "Liveness|Readiness|Unhealthy"
#  Warning  Unhealthy  Liveness probe failed: HTTP probe failed with statuscode: 404
```

---

## kubectl debug

<div class="cols">
<div>

**Contenedor efímero** en un Pod vivo

```bash
kubectl debug -it api-7d9f \
  --image=busybox:1.38 \
  --target=api
```

Comparte el namespace de procesos con `api`: ideal para imágenes *distroless* sin shell.

</div>
<div>

**Depurar un nodo**

```bash
kubectl debug node/worker-1 \
  -it --image=busybox:1.38
# el FS del nodo está en /host
chroot /host
```

**Copia del Pod** con otro comando

```bash
kubectl debug api-7d9f -it \
  --copy-to=api-debug \
  --container=api -- sh
```

</div>
</div>

---

<!-- .slide: class="meme" -->

<div class="meme-two">
<div>
<span class="tag">En kind, en mi portátil</span>

1/1 Running ✔<br>«Listo para producción»

</div>
<div>
<span class="tag">En producción</span>

ImagePullBackOff, Pending,<br>OOMKilled y una PDB que bloquea el drain

</div>
</div>

<p class="meme-caption">«Works in kind» es el nuevo «works on my machine».</p>

---

<!-- .slide: class="lab" -->

## Lab 15 · Troubleshooting

- Cinco despliegues **rotos a propósito** en `examples/contador/k8s/admin/broken/`
- Diagnostica cada uno siguiendo la metodología
- Arréglalo y comprueba que pasa a `Running` y `Ready`
- Las soluciones están ocultas en el lab (no hagas trampa 😉)

```bash
kubectl apply -f examples/contador/k8s/admin/broken/01-imagen.yaml
```

<small>⏱ 75 min · `labs/lab-15-troubleshooting.md`</small>

---

## Resumen del día 6

- Administrar = ciclo de vida + capacidad + seguridad + continuidad
- Upgrades de minor en minor, y **backups de etcd** probados
- **requests** para el scheduler y **limits** para el kernel; la memoria siempre con limit
- Afinidad, taints y spread para **colocar** los Pods; PDB + drain para el **mantenimiento**
- Troubleshooting: `get` → `describe` → `logs` → `events` → `exec`/`debug`

<div class="box tip">

Mañana: usuarios y RBAC, cuotas, almacenamiento persistente… y el proyecto final.

</div>

---

<!-- .slide: class="quiz" -->

## Día 6

1. Un contenedor supera su limit de CPU. ¿Y si supera el de memoria? <span class="fragment answer">CPU: throttling (va más lento) · memoria: OOMKilled</span>
2. ¿Qué QoS tiene un Pod con requests = limits en todos sus contenedores? <span class="fragment answer">Guaranteed: el último en ser desalojado</span>
3. ¿Para qué sirve un taint? <span class="fragment answer">Para repeler Pods de un nodo, salvo los que lo toleren</span>
4. Pod en CrashLoopBackOff: ¿qué miras primero? <span class="fragment answer">`kubectl logs --previous` y `kubectl describe pod`</span>

---

<!-- .slide: class="module center-v" -->

<span class="kicker">Módulo 6 · Parte II · Día 7</span>

# Usuarios, cuotas y almacenamiento

<div class="agenda">

Autenticación · RBAC · ServiceAccounts · Pod Security · ResourceQuota · PV/PVC · StatefulSet

</div>

---

## Autenticación vs. autorización

<div class="cols">
<div>

**Authn**: ¿quién eres?

- Certificados X.509 de cliente
- Tokens OIDC (Keycloak, Entra ID, Google…)
- Tokens de **ServiceAccount**

</div>
<div>

**Authz**: ¿qué puedes hacer?

- **RBAC** (lo normal)
- Node authorizer, webhooks

Y después, **admission**: Pod Security, cuotas, políticas…

</div>
</div>

<div class="box warn">

Kubernetes **no tiene un objeto User**: un usuario es simplemente el *CN* de un certificado o el *claim* de un token.

</div>

---

## Usuarios con certificado: la API CSR

```bash
openssl genrsa -out alumno.key 2048
openssl req -new -key alumno.key -out alumno.csr -subj "/CN=alumno/O=alumnos"
```

```yaml
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata: { name: alumno }
spec:
  request: <base64 de alumno.csr>
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages: [client auth]
```

```bash
kubectl certificate approve alumno
```

<small>CN = usuario · O = grupos. En producción, mejor **OIDC**: un certificado no se puede revocar.</small>

---

## ServiceAccounts: identidades para los Pods

- Cada namespace tiene una `default` (que no debería tener permisos)
- Crea **una SA por aplicación**, con solo lo que necesita
- Tokens **proyectados**: de vida corta, rotan solos y están ligados al Pod
- `automountServiceAccountToken: false` si la app no habla con la API

```bash
kubectl create serviceaccount ci-deployer -n contador
kubectl create token ci-deployer -n contador --duration=1h
```

<small>Identidad SA: `system:serviceaccount:<namespace>:<nombre>`</small>

---

## RBAC: cuatro objetos

| Objeto | Ámbito | Para qué |
| --- | --- | --- |
| **Role** | Namespace | Permisos (verbos sobre recursos) |
| **ClusterRole** | Clúster | Permisos globales o reutilizables |
| **RoleBinding** | Namespace | Asigna un Role o ClusterRole a sujetos *en un namespace* |
| **ClusterRoleBinding** | Clúster | Asigna un ClusterRole *en todo el clúster* |

<small>RBAC solo **suma** permisos: no hay reglas de «denegar». Todo lo que no está permitido, está prohibido.</small>

---

## RBAC en YAML: el Role

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata: { name: deployer, namespace: contador }
rules:
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["services", "configmaps"]
    verbs: ["get", "list", "create", "update", "patch"]
```

<small>`apiGroups: [""]` es el grupo *core* (Pods, Services, ConfigMaps, Secrets…). Consulta los grupos con `kubectl api-resources`.</small>

---

## RBAC en YAML: el RoleBinding

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: { name: ci-deployer, namespace: contador }
roleRef: { apiGroup: rbac.authorization.k8s.io, kind: Role, name: deployer }
subjects:
  - kind: ServiceAccount
    name: ci-deployer
    namespace: contador
  - kind: Group                     # también usuarios (User) o grupos
    name: alumnos
    apiGroup: rbac.authorization.k8s.io
```

<small>El `roleRef` no se puede cambiar: para cambiar el Role, borra y vuelve a crear el binding.</small>

---

## ¿Puedo…? `kubectl auth can-i`

```bash
kubectl auth can-i create deployments -n contador
kubectl auth can-i delete pods -n contador \
  --as=system:serviceaccount:contador:ci-deployer        # no
kubectl auth can-i list pods -n contador --as=alumno     # yes
kubectl auth can-i --list -n contador --as=alumno
kubectl auth whoami
```

<div class="box tip">

ClusterRoles predefinidos que puedes reutilizar: `view`, `edit`, `admin` y `cluster-admin`. Asígnalos con un **RoleBinding** para limitarlos a un namespace.

</div>

---

<!-- .slide: class="meme" -->

<div class="meme-bubble">
  <img src="assets/img/phippy/captain_kube.svg" alt="Captain Kube">
  <div class="bubble">
    «¿Que el becario necesita ver los logs?<br>Dale <code>cluster-admin</code>, que así no molesta.»
    <small>Captain Kube, minutos antes del incidente · Principio de mínimo privilegio: ignorado</small>
  </div>
</div>

Note:
Hablar del principio de mínimo privilegio. Revisar periódicamente quién tiene cluster-admin: kubectl get clusterrolebindings -o wide | grep cluster-admin.

---

## Pod Security Admission

- Sustituto integrado de las antiguas PodSecurityPolicies
- Tres niveles: **privileged**, **baseline** y **restricted**
- Tres modos por namespace: `enforce`, `audit` y `warn`

```bash
kubectl label namespace contador \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/warn=restricted
```

```yaml
securityContext:          # lo que pide "restricted"
  runAsNonRoot: true
  allowPrivilegeEscalation: false
  capabilities: { drop: ["ALL"] }
  seccompProfile: { type: RuntimeDefault }
```

---

## NetworkPolicy: el cortafuegos de los Pods

- Por defecto, **todos los Pods hablan con todos**, de cualquier namespace
- Una NetworkPolicy **selecciona Pods** y dice qué tráfico entrante o saliente se permite
- En cuanto una política selecciona un Pod, **todo lo no permitido se deniega**
- Solo hay reglas de permitir, y se suman entre sí
- Las aplica el **CNI**: Cilium, Calico o kindnet en kind. Sin soporte se ignoran **sin avisar**

Note:
Multi-tenancy por namespace = RBAC + ResourceQuota/LimitRange + Pod Security + NetworkPolicy de denegar por defecto. La presentación del curso lleva una NetworkPolicy (k8s/base/networkpolicy.yaml): solo entrada al 8080 y ninguna salida.

---

## NetworkPolicy en YAML

```yaml [1-6|7-9|10-15]
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: redis-solo-desde-api
  namespace: contador
spec:
  podSelector:                     # a quién protege
    matchLabels: { app.kubernetes.io/name: redis }
  policyTypes: ["Ingress"]
  ingress:
    - from:                        # quién puede entrar
        - podSelector:
            matchLabels: { app.kubernetes.io/name: api }
      ports:
        - port: 6379
```

---

<!-- .slide: class="lab" -->

## Lab 16 · Usuarios y RBAC

- ServiceAccount `ci-deployer` con un Role a medida
- Comprobar permisos con `kubectl auth can-i --as`
- Crear el usuario `alumno` con openssl y la API CSR
- Contexto de kubeconfig con permisos de solo lectura
- NetworkPolicy: Redis solo accesible desde la API

```bash
kubectl apply -f examples/contador/k8s/admin/rbac.yaml
```

<small>⏱ 75 min · `labs/lab-16-rbac.md`</small>

---

## ResourceQuota: el reparto del clúster

```yaml
apiVersion: v1
kind: ResourceQuota
metadata: { name: cuota, namespace: contador }
spec:
  hard:
    requests.cpu: "2"
    requests.memory: 2Gi
    limits.cpu: "8"
    limits.memory: 4Gi
    pods: "10"
    persistentvolumeclaims: "3"
    requests.storage: 5Gi
```

<small>Limita la **suma** del namespace. Con cuota de CPU/memoria, todo Pod **debe** declarar requests y limits → combínala con una **LimitRange**.</small>

Note:
Multi-tenancy por namespace: namespace propio por equipo + RoleBinding a su grupo + ResourceQuota + LimitRange + etiquetas de Pod Security + NetworkPolicy de denegar por defecto. Para aislamiento más fuerte: vCluster, Capsule o clústeres separados. kubectl describe quota -n contador muestra Used/Hard.

---

## Almacenamiento: de volúmenes a PV/PVC

<div class="cols">
<div>

**Volúmenes efímeros** (viven con el Pod)

- `emptyDir`, `configMap`, `secret`
- `projected`, `image`

</div>
<div>

**Persistentes** (sobreviven al Pod)

- **PersistentVolume (PV)**: el disco real
- **PersistentVolumeClaim (PVC)**: «necesito 1Gi RWO»
- **StorageClass**: *cómo* se crean los PV

</div>
</div>

<div class="box tip">

El desarrollador pide un **PVC**; la **StorageClass** crea el **PV** automáticamente (provisión dinámica) mediante un driver **CSI**.

</div>

---

## StorageClass y PVC

<div class="cols">
<div>

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hcloud-volumes
provisioner: csi.hetzner.cloud
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
```

</div>
<div>

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: datos }
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: hcloud-volumes
  resources:
    requests: { storage: 10Gi }
```

</div>
</div>

<small>`WaitForFirstConsumer`: el disco se crea en la zona del nodo donde se programa el Pod. En kind, la clase por defecto es `standard` (local-path).</small>

---

## Modos de acceso y políticas

| accessMode | Significado | Ejemplo típico |
| --- | --- | --- |
| **RWO** ReadWriteOnce | Lectura y escritura desde **un nodo** | Discos de bloque (Hetzner, EBS) |
| **ROX** ReadOnlyMany | Solo lectura desde varios nodos | Datos estáticos |
| **RWX** ReadWriteMany | Lectura y escritura desde varios nodos | NFS, CephFS, EFS |
| **RWOP** ReadWriteOncePod | Desde **un único Pod** | Bases de datos exigentes |

- `reclaimPolicy`: **Delete** (borra el disco con el PVC) o **Retain** (lo conserva)
- **Expansión**: edita `spec.resources.requests.storage` del PVC (solo hacia arriba)

---

## StatefulSet: aplicaciones con estado

- Nombres estables: `redis-0`, `redis-1`…
- DNS estable gracias a un **Service headless**: `redis-0.redis.contador.svc`
- Un **PVC por réplica** mediante `volumeClaimTemplates`
- Arranque y parada **ordenados**

```yaml
volumeClaimTemplates:
  - metadata: { name: data }
    spec:
      accessModes: [ReadWriteOnce]
      resources:
        requests: { storage: 1Gi }
```

<small>Al borrar el StatefulSet, los PVC **no** se borran (por defecto). Tus datos están a salvo… y siguen costando dinero.</small>

---

## Snapshots, CSI y operadores

- **CSI**: interfaz estándar de drivers (Hetzner, EBS, Ceph, Longhorn…)
- **VolumeSnapshot** (GA): copias del volumen a nivel CSI
- **Velero**: backup de los recursos y los volúmenes del clúster
- Bases de datos en serio → **operadores**: CloudNativePG (PostgreSQL), Strimzi (Kafka)…

```bash
kubectl get storageclass
kubectl get pv,pvc -A
kubectl get volumesnapshotclass
```

<small>Pregunta clave antes de meter una BD en Kubernetes: ¿quién la va a operar a las 3 de la mañana?</small>

---

<!-- .slide: class="meme" -->

<div class="meme-term">
<div class="bar">kubectl delete namespace contador</div>
<pre><code data-noescape class="nohighlight">namespace "contador" deleted
<span class="yellow">persistentvolumeclaim "data-redis-0" deleted</span>
<span class="red">persistentvolume "pvc-3f2a…" deleted   # reclaimPolicy: Delete</span></code></pre>
</div>

<p class="meme-caption">«¿Backups? Pensaba que Kubernetes ya se encargaba de eso.»</p>

---

<!-- .slide: class="lab" -->

## Lab 17 · Cuotas y almacenamiento persistente

- ResourceQuota + LimitRange en el namespace `contador`
- Superar la cuota a propósito y leer el error
- Redis como **StatefulSet** con un PVC
- Borrar el Pod y comprobar que **las visitas no se pierden**

```bash
kubectl apply -f examples/contador/k8s/admin/redis-statefulset.yaml
```

<small>⏱ 60 min · `labs/lab-17-cuotas-almacenamiento.md`</small>

---

## Resumen del módulo 6

- **Admin**: upgrades con *skew policy*, backups de etcd y certificados
- **Recursos**: requests/limits, QoS, LimitRange e in-place resize
- **Multinodo**: HA del control plane, nodos, afinidad, taints, drain y PDB
- **Troubleshooting**: metodología y `kubectl debug`
- **Seguridad**: authn/authz, RBAC con mínimo privilegio, Pod Security y NetworkPolicy
- **Datos**: cuotas, StorageClass, PVC, StatefulSet y snapshots

Note:
Referencias: kubernetes.io/docs/tasks/administer-cluster, kubernetes.io/docs/reference/access-authn-authz/rbac, kubernetes.io/docs/concepts/storage.
