# Lab 09 · Pods y Services

## Objetivos

- Crear Pods de forma imperativa y declarativa
- Construir un Pod con dos contenedores que comparten un volumen
- Exponer Pods con Services `ClusterIP` y `NodePort`
- Comprobar el DNS interno del clúster
- Acceder a un Pod desde tu máquina con `port-forward`

## Duración

60 minutos.

## Requisitos

- Clúster `kind-curso` del [Lab 08](lab-08-cluster-kind.md) funcionando

```bash
kubectl create namespace lab09
kubectl config set-context --current --namespace=lab09
```

## Pasos

### 1. Pod imperativo

```bash
kubectl run web --image=nginx:1.30 --labels=app=web --port=80
kubectl get pods -o wide
kubectl describe pod web | tail -15     # mira la sección Events
kubectl logs web
kubectl exec -it web -- sh -c 'hostname; cat /etc/os-release | head -2'
```

### 2. Pod declarativo

Crea `pod-web2.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: web2
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
kubectl apply -f pod-web2.yaml
kubectl get pods -l app=web --show-labels
```

### 3. Pod multicontenedor

Un contenedor escribe en un volumen compartido y nginx lo sirve. Crea `pod-multi.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi
  labels:
    app: multi
spec:
  volumes:
    - name: html
      emptyDir: {}
  containers:
    - name: nginx
      image: nginx:1.30
      volumeMounts:
        - { name: html, mountPath: /usr/share/nginx/html }
    - name: writer
      image: busybox:1.37
      command: ["sh", "-c", "while true; do date > /html/index.html; sleep 5; done"]
      volumeMounts:
        - { name: html, mountPath: /html }
```

```bash
kubectl apply -f pod-multi.yaml
kubectl get pod multi            # READY 2/2
kubectl exec multi -c writer -- wget -qO- localhost
```

> Los dos contenedores comparten **la misma red**: `localhost` es el mismo para ambos.

### 4. Service ClusterIP

```bash
kubectl expose pod web --name=web --port=80 --selector=app=web
kubectl get svc web
kubectl get endpointslices -l kubernetes.io/service-name=web
```

El Service selecciona **los dos Pods** (`web` y `web2`) porque ambos tienen `app=web`.

### 5. Probar el DNS interno

Arranca un Pod de depuración temporal:

```bash
kubectl run tmp --rm -it --image=nicolaka/netshoot:v0.16 -- bash
```

Dentro del Pod:

```bash
nslookup web
nslookup web.lab09.svc.cluster.local
for i in $(seq 1 6); do curl -s web | grep -o '<title>.*</title>'; done
cat /etc/resolv.conf
exit
```

Salida esperada de `nslookup web`:

```text
Name:   web.lab09.svc.cluster.local
Address: 10.96.x.y
```

### 6. Service NodePort

Crea `svc-nodeport.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-np
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080
```

```bash
kubectl apply -f svc-nodeport.yaml
curl -s localhost:30080 | head -5
```

> Funciona gracias al `extraPortMappings` de `kind-config.yaml`.

### 7. port-forward

```bash
kubectl port-forward pod/multi 8081:80 &
curl -s localhost:8081
kill %1
```

## Retos extra

1. Quita la label `app=web` a `web2` (`kubectl label pod web2 app-`) y observa
   cómo cambian los EndpointSlices del Service.
2. Crea un Service **headless** (`clusterIP: None`) para `app=web` y compara la
   respuesta de `nslookup` con la del Service normal.
3. Borra el Pod `web`. ¿Vuelve? ¿Por qué? (Compáralo con el Lab 10.)

## Limpieza

```bash
kubectl delete namespace lab09
kubectl config set-context --current --namespace=default
```
