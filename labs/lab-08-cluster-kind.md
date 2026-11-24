# Lab 08 · Clúster kind multinodo

## Objetivos

- Crear un clúster Kubernetes local de 3 nodos con **kind**
- Entender el kubeconfig y los contextos
- Explorar los componentes del control plane
- Practicar los comandos básicos de `kubectl`

## Duración

45 minutos.

## Requisitos

- Docker (o Podman), `kubectl` y `kind` 0.33 instalados ([Lab 00](lab-00-entorno.md))
- Repositorio del curso clonado (los comandos se ejecutan desde su raíz)

> **Con Podman:** exporta `KIND_EXPERIMENTAL_PROVIDER=podman` antes de usar kind.

## Pasos

### 1. Crear el clúster

Revisa la configuración: un control plane, dos workers y el puerto 30080 del
host mapeado al NodePort 30080.

```bash
cat examples/contador/k8s/kind-config.yaml
kind create cluster --name curso --config examples/contador/k8s/kind-config.yaml
```

Salida esperada (resumida):

```text
Creating cluster "curso" ...
 ✓ Ensuring node image (kindest/node:v1.37.0) 🖼
 ✓ Preparing nodes 📦 📦 📦
 ✓ Starting control-plane 🕹️
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-curso"
```

### 2. Los nodos son contenedores

```bash
docker ps --format 'table {{.Names}}\t{{.Image}}'
kubectl get nodes -o wide
```

```text
NAME                  STATUS   ROLES           AGE   VERSION
curso-control-plane   Ready    control-plane   1m    v1.37.0
curso-worker          Ready    <none>          1m    v1.37.0
curso-worker2         Ready    <none>          1m    v1.37.0
```

### 3. kubeconfig y contextos

```bash
kubectl config get-contexts
kubectl config current-context
kubectl config view --minify
```

- ¿Qué servidor (`server:`) usa el contexto `kind-curso`?
- Crea un namespace y conviértelo en el namespace por defecto del contexto:

```bash
kubectl create namespace lab
kubectl config set-context --current --namespace=lab
kubectl config view --minify | grep namespace
```

### 4. El control plane por dentro

```bash
kubectl get pods -n kube-system -o wide
```

Identifica cada componente: `etcd-…`, `kube-apiserver-…`, `kube-scheduler-…`,
`kube-controller-manager-…`, `kube-proxy-…` (uno por nodo, es un DaemonSet),
`coredns-…` y `kindnet-…` (el CNI de kind).

```bash
kubectl describe pod -n kube-system -l component=kube-apiserver | head -40
docker exec curso-control-plane ls /etc/kubernetes/manifests
```

> Los componentes del control plane son **static Pods**: el kubelet los arranca
> a partir de los ficheros de `/etc/kubernetes/manifests`.

### 5. Descubrir la API

```bash
kubectl api-resources | head -20
kubectl api-resources --namespaced=false
kubectl explain pod.spec.containers.resources
kubectl version
```

### 6. Primeros objetos

```bash
kubectl create deployment hola --image=nginx:1.30
kubectl get deploy,rs,pods -o wide
kubectl get deploy hola -o yaml | less
kubectl delete deployment hola
```

Genera un manifiesto sin crearlo:

```bash
kubectl create deployment hola --image=nginx:1.30 --replicas=2 \
  --dry-run=client -o yaml > /tmp/hola.yaml
kubectl apply -f /tmp/hola.yaml
kubectl get pods -l app=hola
```

## Retos extra

1. ¿En qué nodos se han programado los Pods de `hola`? ¿Por qué ninguno está en
   el control plane? (Pista: `kubectl describe node curso-control-plane | grep Taints`.)
2. Usa `kubectl get pods -A --field-selector spec.nodeName=curso-worker` para
   ver qué corre en un nodo concreto.
3. Instala `k9s` y explora el clúster desde la interfaz de texto.

## Limpieza

```bash
kubectl delete -f /tmp/hola.yaml
kubectl config set-context --current --namespace=default
kubectl delete namespace lab
```

> **No borres el clúster**: lo usaremos en los labs 09 a 18. Si necesitas
> recrearlo: `kind delete cluster --name curso`.
