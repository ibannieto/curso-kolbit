<!-- .slide: class="module center-v" -->

<span class="kicker">Módulo 4 · Día 4</span>

# Introducción a Kubernetes

<div class="agenda">

Ecosistema · Arquitectura · Objetos y YAML · Instalación · Pods · Services · Escalado y actualizaciones

</div>

---

## De Docker a Kubernetes

<div class="cols wide-left">
<div>

- Con Docker y Compose controlas **un host**
- Kubernetes gestiona un **clúster** de hosts como si fuera uno
- Tú declaras el **estado deseado**; el clúster se encarga de alcanzarlo y mantenerlo
- Mismas imágenes OCI que ya sabes construir

</div>
<div class="center">

<img src="assets/img/logos/kubernetes.svg" alt="Kubernetes" style="height:260px">

</div>
</div>

---

## Qué te da Kubernetes

<div class="cols">
<div>

- **Scheduling**: decide en qué nodo corre cada contenedor
- **Autorreparación**: reinicia y reprograma lo que cae
- **Escalado** horizontal, manual o automático

</div>
<div>

- **Service discovery** y balanceo de carga
- **Rolling updates** y rollbacks
- **Configuración y secretos** desacoplados de la imagen

</div>
</div>

<div class="box warn">

Lo que **no** te da de serie: CI/CD, construir imágenes, logs centralizados ni monitorización completa. Eso lo aporta el ecosistema.

</div>

---

## El ecosistema CNCF

- **Kubernetes** es el núcleo; la CNCF aloja más de 200 proyectos a su alrededor
- Red: **Cilium**, Calico · Gateway: Envoy Gateway, Cilium, kgateway
- Observabilidad: **Prometheus**, OpenTelemetry, Jaeger
- Entrega: **Helm**, Kustomize, **Flux**, Argo CD
- Seguridad: cert-manager, Falco, Kyverno, OPA

<div class="logo-row">
  <img src="assets/img/logos/cncf.svg" alt="CNCF" style="height:60px">
  <img src="assets/img/logos/helm.svg" alt="Helm" style="height:60px">
  <img src="assets/img/logos/cilium.svg" alt="Cilium" style="height:60px">
  <img src="assets/img/logos/prometheus.svg" alt="Prometheus" style="height:60px">
</div>

Note:
Enseñar landscape.cncf.io en directo si hay tiempo: impresiona y asusta a partes iguales.

---

## Distribuciones: ¿dónde corre Kubernetes?

| Tipo | Ejemplos | Para qué |
| --- | --- | --- |
| Local | **kind**, minikube, k3d | Aprender, desarrollar, CI |
| Ligera | k3s, k0s | Edge, homelab, IoT |
| «Vanilla» | **kubeadm** | Control total, examen CKA |
| SO inmutable | **Talos Linux** | Clústeres declarativos sin SSH |
| Gestionada | EKS, GKE, AKS | Producción sin operar el control plane |

<small>En el curso: **kind** en vuestro portátil + mi clúster Talos en Hetzner para las demos</small>

---

<!-- .slide: class="meme" -->

<img src="assets/img/phippy/group.svg" alt="Phippy y sus amigos" style="max-height:470px">

<p class="meme-caption">Phippy y sus amigos: cada personaje es un concepto de Kubernetes</p>

<small>Phippy and Friends · CNCF</small>

Note:
Phippy (la app), Captain Kube (el timonel), Zee (Pod), Goldie (Service)... Material oficial para explicar Kubernetes sin miedo.

---

## Arquitectura de un clúster

<div class="cols">
<div>

**Control plane** (el cerebro)

- `kube-apiserver`: la única puerta de entrada
- `etcd`: la base de datos del estado
- `kube-scheduler`: asigna Pods a nodos
- `kube-controller-manager`: bucles de control
- `cloud-controller-manager`: integra el proveedor cloud

</div>
<div>

**Nodos** (el músculo)

- `kubelet`: agente que arranca los Pods
- Runtime **CRI**: containerd o CRI-O
- `kube-proxy`, o **eBPF con Cilium**: red de los Services
- Plugin **CNI**: red entre Pods

</div>
</div>

---

## Qué pasa al hacer `kubectl apply`

<svg class="diagram" viewBox="0 0 1200 520" role="img" aria-label="Flujo de kubectl apply: API server, etcd, controladores, scheduler y kubelet">
<defs><marker id="ah-api" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path class="arrowhead" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="30" y="70" width="190" height="64" rx="12"/>
<text class="mono" x="125" y="108" text-anchor="middle">kubectl apply</text>
<rect class="box k8s" x="420" y="56" width="340" height="92" rx="14"/>
<text class="title" x="590" y="96" text-anchor="middle">kube-apiserver</text>
<text class="sub" x="590" y="124" text-anchor="middle">única puerta de entrada</text>
<rect class="box" x="950" y="56" width="220" height="92" rx="14"/>
<text class="title" x="1060" y="96" text-anchor="middle">etcd</text>
<text class="sub" x="1060" y="124" text-anchor="middle">estado del clúster</text>
<rect class="box" x="40" y="236" width="330" height="80" rx="14"/>
<text class="title" x="205" y="270" text-anchor="middle">controller-manager</text>
<text class="sub" x="205" y="298" text-anchor="middle">Deployment → ReplicaSet → Pods</text>
<rect class="box" x="830" y="236" width="330" height="80" rx="14"/>
<text class="title" x="995" y="270" text-anchor="middle">scheduler</text>
<text class="sub" x="995" y="298" text-anchor="middle">elige un nodo para cada Pod</text>
<rect class="box node" x="150" y="380" width="420" height="124" rx="14"/>
<text class="sub" x="170" y="408">Nodo 1</text>
<text class="title" x="360" y="412" text-anchor="middle">kubelet</text>
<rect class="box pod" x="200" y="428" width="320" height="56" rx="10"/>
<text class="mono" x="360" y="463" text-anchor="middle">containerd → Pod web-1</text>
<rect class="box node" x="630" y="380" width="420" height="124" rx="14"/>
<text class="sub" x="650" y="408">Nodo 2</text>
<text class="title" x="840" y="412" text-anchor="middle">kubelet</text>
<rect class="box pod" x="680" y="428" width="320" height="56" rx="10"/>
<text class="mono" x="840" y="463" text-anchor="middle">containerd → Pod web-2</text>
<line class="arrow" x1="222" y1="102" x2="414" y2="102" marker-end="url(#ah-api)"/>
<line class="arrow" x1="764" y1="102" x2="944" y2="102" marker-start="url(#ah-api)" marker-end="url(#ah-api)"/>
<line class="arrow" x1="250" y1="232" x2="470" y2="152" marker-start="url(#ah-api)" marker-end="url(#ah-api)"/>
<line class="arrow" x1="950" y1="232" x2="710" y2="152" marker-start="url(#ah-api)" marker-end="url(#ah-api)"/>
<line class="arrow" x1="470" y1="376" x2="565" y2="152" marker-start="url(#ah-api)" marker-end="url(#ah-api)"/>
<line class="arrow" x1="730" y1="376" x2="615" y2="152" marker-start="url(#ah-api)" marker-end="url(#ah-api)"/>
<circle class="step" cx="318" cy="76" r="17"/><text class="step" x="318" y="83" text-anchor="middle">1</text>
<text class="edge" x="318" y="130" text-anchor="middle">manifiesto</text>
<circle class="step" cx="855" cy="76" r="17"/><text class="step" x="855" y="83" text-anchor="middle">2</text>
<text class="edge" x="855" y="130" text-anchor="middle">guarda</text>
<circle class="step" cx="335" cy="170" r="17"/><text class="step" x="335" y="177" text-anchor="middle">3</text>
<circle class="step" cx="865" cy="170" r="17"/><text class="step" x="865" y="177" text-anchor="middle">4</text>
<circle class="step" cx="590" cy="300" r="17"/><text class="step" x="590" y="307" text-anchor="middle">5</text>
<text class="edge" x="590" y="345" text-anchor="middle">watch + estado</text>
</svg>

<small>**1** envías el manifiesto · **2** se guarda en etcd · **3** los controladores crean ReplicaSet y Pods · **4** el scheduler asigna nodo · **5** el kubelet arranca el contenedor y reporta. Nadie habla con nadie: todos **observan** el API server.</small>

Note:
Recorrer qué ocurre al hacer kubectl apply de un Deployment: API → etcd → controller crea ReplicaSet → Pods → scheduler asigna nodo → kubelet arranca contenedores.

---

## Modelo declarativo

<div class="cols">
<div>

**Imperativo** (Docker)

```bash
docker run -d nginx
docker run -d nginx
docker run -d nginx
```

«Haz esto, ahora»

</div>
<div>

**Declarativo** (Kubernetes)

```yaml
kind: Deployment
spec:
  replicas: 3
```

«Quiero que exista esto, siempre»

</div>
</div>

---

## El bucle de reconciliación

1. **Observar**: ¿cuál es el estado real?
2. **Comparar** con el estado deseado (`spec`)
3. **Actuar** para acercar uno al otro
4. Repetir… para siempre

<div class="box tip">

Si un nodo muere, el controlador ve 2 Pods de 3 y crea otro. No hace falta que nadie se despierte a las 3:00.

</div>

---

<!-- .slide: class="meme" -->

<div class="meme-bubble">
  <img src="assets/img/phippy/captain_kube.svg" alt="Captain Kube">
  <div class="bubble">
    —¿Has borrado el Pod?<br>
    —Sí.<br>
    —¿Y por qué sigue ahí?<br>
    —Reconciliando… 😌
    <small>Captain Kube · el estado deseado siempre gana</small>
  </div>
</div>

Note:
Para borrar de verdad hay que borrar el Deployment, no el Pod. Lo veremos en el lab.

---

## Anatomía de un objeto

```yaml
apiVersion: v1          # grupo/versión de la API
kind: Pod               # tipo de objeto
metadata:
  name: web
  namespace: default
  labels:
    app: web
spec:                   # lo que TÚ quieres
  containers:
    - name: nginx
      image: nginx:1.30
status: {}              # lo que HAY (lo rellena el clúster)
```

---

## Labels, selectors y namespaces

<div class="cols">
<div>

**Labels**: etiquetas clave/valor

- `app: web`, `tier: frontend`, `env: prod`
- Los **selectors** las usan para agrupar
- Así encuentran sus Pods los Services y los Deployments

</div>
<div>

**Namespaces**: espacios lógicos

- Aíslan nombres, permisos (RBAC) y cuotas
- `default`, `kube-system`, `kube-public`…
- No aíslan la red por sí solos (para eso, NetworkPolicy)

</div>
</div>

```bash
kubectl get pods -l app=web -n tienda
```

---

## Instalar un clúster local con kind

```yaml
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

```bash
kind create cluster --name curso --config kind-config.yaml
kubectl get nodes
```

<small>kind = «Kubernetes IN Docker»: cada nodo es un contenedor (funciona también con Podman)</small>

---

## ¿Y un clúster «de verdad»? kubeadm

```bash
# 1. Primer nodo de control plane (requiere containerd y kubelet instalados)
sudo kubeadm init --control-plane-endpoint api.midominio.lan:6443 \
  --pod-network-cidr 10.244.0.0/16

# 2. Plugin de red (CNI): sin él, los nodos se quedan en NotReady
cilium install

# 3. En cada worker: el comando exacto lo imprime kubeadm init
sudo kubeadm join api.midominio.lan:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>

kubectl get nodes -o wide
```

<small>kubeadm, kubelet y kubectl de la **misma minor** (paquetes de `pkgs.k8s.io`). Talos o un gestionado hacen todo esto por ti; kubeadm es lo que pide la CKA.</small>

Note:
No lo hacemos en el lab (kind ya usa kubeadm por dentro: cada contenedor de kind ejecuta kubeadm init/join). Si sobra tiempo, enseñar en directo el clúster Talos de Hetzner: kubectl get nodes -o wide, los Pods de kube-system (Cilium, hcloud-csi, coredns) y talosctl dashboard.

---

## kubeconfig y contextos

- `~/.kube/config` guarda **clusters**, **usuarios** y **contextos**
- Un contexto = clúster + usuario + namespace por defecto

```bash
kubectl config get-contexts
kubectl config use-context kind-curso
kubectl config set-context --current --namespace=lab
```

<div class="box warn">

Antes de borrar nada, mira en qué contexto estás. Producción y local se parecen demasiado en la terminal.

</div>

---

## kubectl: lo imprescindible

```bash
kubectl get pods -o wide            # listar (también -o yaml / -o json)
kubectl describe pod web            # detalle + eventos
kubectl apply -f web.yaml           # crear/actualizar declarativamente
kubectl delete -f web.yaml          # borrar
kubectl logs web -f                 # logs en streaming
kubectl exec -it web -- sh          # shell dentro del contenedor
kubectl port-forward pod/web 8080:80
kubectl explain deployment.spec.strategy
```

---

<!-- .slide: class="meme" -->

<div class="meme-poll">
<p class="q">Encuesta seria: ¿cómo se pronuncia <code>kubectl</code>?</p>
<ol>
<li>kube-control</li>
<li>kube-ce-te-ele</li>
<li>kube-cuttle</li>
<li>kube-cuddle</li>
</ol>
</div>

<p class="meme-caption">No hay respuesta oficial. Sí hay equipos que no se hablan por esto.</p>

Note:
Lanzar la encuesta en el chat de Teams. Es un debate real y eterno en la comunidad. Lo importante: todo el mundo os entenderá digáis lo que digáis.

---

## Truco: que kubectl escriba el YAML por ti

```bash
kubectl create deployment web --image=nginx:1.30 \
  --replicas=3 --dry-run=client -o yaml > web.yaml

kubectl run tmp --image=busybox:1.37 \
  --dry-run=client -o yaml -- sleep 3600
```

- Genera el esqueleto, edítalo y guárdalo en git
- `kubectl explain` para descubrir los campos sin salir de la terminal

---

<!-- .slide: class="lab" -->

## Lab 08 · Clúster kind multinodo

- Crear un clúster de 3 nodos con kind
- Explorar contextos y kubeconfig
- Ver los componentes del control plane en `kube-system`
- Primeros pasos con `kubectl`

<small>⏱ 45 min · `labs/lab-08-cluster-kind.md`</small>

---

## Pods: la unidad mínima

- Un Pod = **uno o varios contenedores** que comparten red (misma IP) y volúmenes
- Normalmente **un contenedor principal** por Pod
- Son **efímeros**: no se reparan, se reemplazan
- Casi nunca se crean a mano: los crea un Deployment, un Job…

<img src="assets/img/phippy/zee.svg" alt="Zee" style="height:220px">

---

## Un Pod en YAML

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web
  labels:
    app: web
spec:
  containers:
    - name: nginx
      image: nginx:1.30
      ports:
        - containerPort: 80
```

```bash
kubectl apply -f pod.yaml && kubectl get pod web -w
```

---

## Pods multicontenedor

<div class="cols">
<div>

**Init containers**

- Se ejecutan **antes**, en orden
- Deben terminar con éxito
- Ej.: esperar a la BD, migraciones

</div>
<div>

**Sidecars nativos** (GA)

- `initContainers` con `restartPolicy: Always`
- Arrancan antes y viven con el Pod
- Ej.: proxy, agente de logs

</div>
</div>

```yaml
initContainers:
  - name: log-shipper
    image: fluent/fluent-bit:5.2
    restartPolicy: Always      # ← esto lo convierte en sidecar
```

---

## Ciclo de vida de un Pod

| Fase | Significado |
| --- | --- |
| `Pending` | Aceptado, sin nodo asignado o descargando la imagen |
| `Running` | Asignado a un nodo y con al menos un contenedor en marcha |
| `Succeeded` | Todos los contenedores terminaron bien |
| `Failed` | Algún contenedor terminó con error |
| `Unknown` | No se sabe nada del nodo |

<small>`CrashLoopBackOff` e `ImagePullBackOff` no son fases: son **razones** de estado del contenedor</small>

---

## Services: una dirección estable

- Los Pods cambian de IP cada vez que se recrean
- Un **Service** da una IP virtual y un nombre DNS **estables**
- Selecciona sus Pods por **labels** y reparte el tráfico entre ellos
- Mantiene la lista de destinos en **EndpointSlices**

<img src="assets/img/phippy/goldie.svg" alt="Goldie" style="height:200px">

---

## Cómo llega el tráfico a un Pod

<svg class="diagram" viewBox="0 0 1200 450" role="img" aria-label="Un Pod cliente resuelve el Service por DNS y kube-proxy reparte el tráfico entre los Pods con la etiqueta app=web">
<defs><marker id="ah-svc" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path class="arrowhead" d="M0,0 L10,5 L0,10 z"/></marker></defs>
<rect class="box" x="20" y="30" width="230" height="84" rx="12"/>
<text class="title" x="135" y="66" text-anchor="middle">CoreDNS</text>
<text class="mono" x="135" y="94" text-anchor="middle">web → 10.96.0.20</text>
<rect class="box pod" x="20" y="190" width="230" height="84" rx="12"/>
<text class="title" x="135" y="226" text-anchor="middle">Pod cliente</text>
<text class="mono" x="135" y="254" text-anchor="middle">curl http://web</text>
<rect class="box k8s" x="350" y="150" width="300" height="140" rx="14"/>
<text class="title" x="500" y="190" text-anchor="middle">Service web</text>
<text class="mono" x="500" y="222" text-anchor="middle">10.96.0.20:80</text>
<text class="mono" x="500" y="252" text-anchor="middle">selector: app=web</text>
<rect class="box" x="350" y="340" width="300" height="90" rx="12"/>
<text class="title" x="500" y="374" text-anchor="middle">EndpointSlice</text>
<text class="sub" x="500" y="402" text-anchor="middle">IPs de los Pods listos</text>
<rect class="box pod" x="790" y="20" width="390" height="80" rx="12"/>
<text class="title" x="810" y="54">web-1</text><text class="mono" x="810" y="82">app=web · 10.244.1.5</text>
<rect class="box pod" x="790" y="120" width="390" height="80" rx="12"/>
<text class="title" x="810" y="154">web-2</text><text class="mono" x="810" y="182">app=web · 10.244.2.7</text>
<rect class="box pod" x="790" y="220" width="390" height="80" rx="12"/>
<text class="title" x="810" y="254">web-3</text><text class="mono" x="810" y="282">app=web · 10.244.2.9</text>
<g class="off"><rect class="box off" x="790" y="340" width="390" height="80" rx="12"/>
<text class="title off" x="810" y="374">db-0</text><text class="sub off" x="810" y="402">app=db · no coincide: no recibe tráfico</text></g>
<line class="arrow dashed" x1="135" y1="186" x2="135" y2="118" marker-end="url(#ah-svc)"/>
<line class="arrow" x1="254" y1="232" x2="344" y2="222" marker-end="url(#ah-svc)"/>
<line class="arrow dashed" x1="500" y1="294" x2="500" y2="336" marker-start="url(#ah-svc)" marker-end="url(#ah-svc)"/>
<line class="arrow" x1="654" y1="200" x2="784" y2="62" marker-end="url(#ah-svc)"/>
<line class="arrow" x1="654" y1="215" x2="784" y2="160" marker-end="url(#ah-svc)"/>
<line class="arrow" x1="654" y1="232" x2="784" y2="258" marker-end="url(#ah-svc)"/>
<circle class="step" cx="105" cy="152" r="17"/><text class="step" x="105" y="159" text-anchor="middle">1</text>
<circle class="step" cx="300" cy="200" r="17"/><text class="step" x="300" y="207" text-anchor="middle">2</text>
<circle class="step" cx="720" cy="120" r="17"/><text class="step" x="720" y="127" text-anchor="middle">3</text>
</svg>

<small>**1** el nombre se resuelve a la IP virtual · **2** el cliente conecta a esa IP · **3** kube-proxy (o eBPF con Cilium) reparte entre los Pods **listos** con la etiqueta del selector.</small>

Note:
Si el selector no coincide con las etiquetas, la EndpointSlice queda vacía y el Service «no responde»: es uno de los fallos del lab de troubleshooting. Un Pod que no pasa la readiness también sale de la lista.

---

## Tipos de Service

| Tipo | Accesible desde | Uso típico |
| --- | --- | --- |
| `ClusterIP` | Dentro del clúster | Comunicación entre servicios (por defecto) |
| `NodePort` | `IP-del-nodo:30000-32767` | Labs, entornos sin balanceador |
| `LoadBalancer` | IP pública del proveedor | Exponer en la nube |
| Headless (`clusterIP: None`) | DNS → IPs de los Pods | StatefulSets, bases de datos |

---

## Un Service en YAML

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  type: ClusterIP
  selector:
    app: web          # ← los Pods con esta label
  ports:
    - port: 80        # puerto del Service
      targetPort: 80  # puerto del contenedor
```

```bash
kubectl get endpointslices -l kubernetes.io/service-name=web
```

---

## DNS interno

- CoreDNS crea un nombre para cada Service:

```text
web.tienda.svc.cluster.local
│    │      │    └─ dominio del clúster
│    │      └────── tipo de objeto
│    └───────────── namespace
└────────────────── nombre del Service
```

- Desde el mismo namespace basta con `web`
- Desde otro namespace: `web.tienda`

---

<!-- .slide: class="meme" -->

<div class="meme-term">
<div class="bar">deployment.yaml — 14:47 del viernes</div>

```text
spec:
  template:
    spec:
      containers:
      - name: api
         image: contador:1.0
```

</div>

<p class="meme-caption">error converting YAML to JSON: line 6: mapping values are not allowed here</p>

<small>Un espacio de más. Tres horas de tu vida.</small>

Note:
Recomendar extensión YAML de VS Code con el esquema de Kubernetes, y kubeconform/yamllint en el pipeline.

---

## Tráfico de entrada: Ingress y Gateway API

<div class="cols">
<div>

**Ingress** (clásico)

- Reglas HTTP host/path → Service
- Muchas funciones vía **anotaciones** no portables
- **Ingress NGINX retirado** (marzo 2026): sin parches de seguridad

</div>
<div>

**Gateway API** (v1.7, recomendado)

- Roles separados: `GatewayClass` → `Gateway` → `HTTPRoute`
- HTTP, gRPC, TLS, TCP; pesos y cabeceras de serie
- Cilium, Envoy Gateway, Istio, kgateway…

</div>
</div>

---

## Un HTTPRoute

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: web
spec:
  parentRefs:
    - name: public-gw          # Gateway gestionado por plataforma
  hostnames: ["web.ejemplo.com"]
  rules:
    - matches:
        - path: { type: PathPrefix, value: / }
      backendRefs:
        - name: web            # Service
          port: 80
```

---

<!-- .slide: class="lab" -->

## Lab 09 · Pods y Services

- Crear Pods de forma imperativa y declarativa
- Un Pod con dos contenedores que comparten volumen
- Exponerlo con ClusterIP y NodePort
- Probar el DNS interno desde un Pod de depuración
- `kubectl port-forward`

<small>⏱ 60 min · `labs/lab-09-pods-services.md`</small>

---

## ReplicaSet y Deployment

```text
Deployment ──► ReplicaSet (v2) ──► Pod Pod Pod
          └──► ReplicaSet (v1)     (0 réplicas, para rollback)
```

- **ReplicaSet**: mantiene N copias de un Pod
- **Deployment**: gestiona ReplicaSets y añade **actualizaciones** e **historial**
- En la práctica, siempre trabajas con **Deployments**

---

## Un Deployment en YAML

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  selector:
    matchLabels: { app: web }
  template:                    # plantilla del Pod
    metadata:
      labels: { app: web }
    spec:
      containers:
        - { name: nginx, image: "nginx:1.30" }
```

---

## Escalado manual

```bash
kubectl scale deployment web --replicas=5
kubectl get pods -l app=web -w
```

- O cambia `replicas:` en el YAML y vuelve a hacer `apply` (mejor: queda en git)
- El escalado **automático** (HPA) lo vemos en el Módulo 5

<div class="box tip">

Prueba: `kubectl delete pod` sobre uno de los Pods y observa cómo el ReplicaSet lo repone.

</div>

---

## Estrategias de actualización

<div class="cols">
<div>

**RollingUpdate** (por defecto)

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1        # Pods extra
    maxUnavailable: 0  # Pods caídos
```

Sin corte de servicio

</div>
<div>

**Recreate**

```yaml
strategy:
  type: Recreate
```

Mata todo y arranca la versión nueva. Hay corte, pero nunca conviven dos versiones.

</div>
</div>

---

## Actualizar y volver atrás

```bash
kubectl set image deployment/web nginx=nginx:1.31
kubectl rollout status deployment/web

kubectl rollout history deployment/web
kubectl rollout undo deployment/web                 # a la anterior
kubectl rollout undo deployment/web --to-revision=1

kubectl annotate deployment/web \
  kubernetes.io/change-cause="nginx 1.31"           # aparece en history
```

<small>En GitOps no se usa `set image`: se cambia el YAML en git y se aplica</small>

---

<!-- .slide: class="lab" -->

## Lab 10 · Deployments

- Crear un Deployment y escalarlo
- Rolling update observando `kubectl get pods -w`
- Jugar con `maxSurge` y `maxUnavailable`
- Romper una actualización (imagen inexistente) y hacer rollback

<small>⏱ 60 min · `labs/lab-10-deployments.md`</small>

---

## Resumen del módulo

- Kubernetes = **API declarativa** + **bucles de reconciliación**
- Control plane (apiserver, etcd, scheduler, controllers) + nodos (kubelet, CRI, CNI)
- **Pod**: unidad mínima, efímera · **Service**: dirección estable
- **Deployment** → ReplicaSet → Pods: escalado, rolling updates, rollback
- Tráfico de entrada: **Gateway API** (Ingress NGINX está retirado)

<div class="box tip">

Siguiente: desplegar una aplicación de verdad, con configuración, secretos y autoescalado.

</div>

---

<!-- .slide: class="quiz" -->

## Día 4

1. ¿Qué componente es el único que habla con etcd? <span class="fragment answer">`kube-apiserver`</span>
2. Borras un Pod de un Deployment de 3 réplicas. ¿Qué pasa? <span class="fragment answer">El ReplicaSet crea otro: el estado deseado sigue siendo 3</span>
3. ¿Cómo sabe un Service a qué Pods mandar tráfico? <span class="fragment answer">Por su selector de labels (las EndpointSlices)</span>
4. ¿Cómo vuelves a la versión anterior de un Deployment? <span class="fragment answer">`kubectl rollout undo deployment/web`</span>

---

## Referencias

- Documentación oficial: [kubernetes.io/docs](https://kubernetes.io/docs/)
- Chuleta de kubectl: [kubernetes.io/docs/reference/kubectl/quick-reference](https://kubernetes.io/docs/reference/kubectl/quick-reference/)
- kind: [kind.sigs.k8s.io](https://kind.sigs.k8s.io/)
- Gateway API: [gateway-api.sigs.k8s.io](https://gateway-api.sigs.k8s.io/)
- Phippy and Friends: [phippy.io](https://phippy.io/)
