# Lab 10 · Deployments: escalado, rolling updates y rollback

## Objetivos

- Crear un Deployment y relacionarlo con sus ReplicaSets y Pods
- Escalar de forma manual
- Hacer un rolling update observándolo en directo
- Ajustar `maxSurge` y `maxUnavailable`
- Romper una actualización y volver atrás

## Duración

60 minutos.

## Requisitos

- Clúster `kind-curso` funcionando
- Dos terminales abiertas

```bash
kubectl create namespace lab10
kubectl config set-context --current --namespace=lab10
```

## Pasos

### 1. Crear el Deployment

Crea `web-deploy.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  annotations:
    kubernetes.io/change-cause: "nginx 1.30"
spec:
  replicas: 4
  selector:
    matchLabels: { app: web }
  strategy:
    type: RollingUpdate
    rollingUpdate: { maxSurge: 1, maxUnavailable: 0 }
  template:
    metadata:
      labels: { app: web }
    spec:
      containers:
        - name: nginx
          image: nginx:1.30
          readinessProbe:
            httpGet: { path: /, port: 80 }
```

```bash
kubectl apply -f web-deploy.yaml
kubectl get deploy,rs,pods -l app=web
```

Fíjate en los nombres: `web` → `web-<hash>` (ReplicaSet) → `web-<hash>-<id>` (Pod).

### 2. Autorreparación

```bash
kubectl delete pod -l app=web --wait=false
kubectl get pods -l app=web
```

El ReplicaSet repone los Pods al momento. Así se «borra» de verdad:
`kubectl delete deployment web` (no lo hagas todavía).

### 3. Escalar

```bash
kubectl scale deployment web --replicas=6
kubectl get pods -l app=web -o wide     # ¿cómo se reparten entre los workers?
kubectl scale deployment web --replicas=4
```

### 4. Rolling update en directo

En la **terminal 2**:

```bash
kubectl get pods -l app=web -w
```

En la **terminal 1**:

```bash
kubectl set image deployment/web nginx=nginx:1.31
kubectl annotate deployment/web kubernetes.io/change-cause="nginx 1.31" --overwrite
kubectl rollout status deployment/web
kubectl get rs -l app=web
```

Con `maxSurge: 1` y `maxUnavailable: 0` nunca hay menos de 4 Pods listos: se crea
uno nuevo y, cuando está *Ready*, se elimina uno viejo.

### 5. Cambiar la estrategia

Edita el YAML con `maxSurge: 2` y `maxUnavailable: 2`, vuelve a aplicarlo y
actualiza a `nginx:1.30`:

```bash
kubectl apply -f web-deploy.yaml
kubectl set image deployment/web nginx=nginx:1.30
```

Observa en la terminal 2 que ahora se reemplazan los Pods de **dos en dos**.

### 6. Romper una actualización

```bash
kubectl set image deployment/web nginx=nginx:9.99-noexiste
kubectl rollout status deployment/web --timeout=60s
kubectl get pods -l app=web
```

Salida esperada: Pods nuevos en `ErrImagePull` o `ImagePullBackOff`, y los
antiguos **siguen sirviendo** (gracias a la readinessProbe y a `maxUnavailable`).

### 7. Rollback

```bash
kubectl rollout history deployment/web
kubectl rollout undo deployment/web
kubectl rollout status deployment/web
kubectl rollout history deployment/web
kubectl rollout undo deployment/web --to-revision=1
```

## Retos extra

1. Cambia la estrategia a `Recreate` y repite la actualización. ¿Qué ves en la
   terminal 2?
2. Pon `revisionHistoryLimit: 2` y haz varias actualizaciones. ¿Cuántos ReplicaSets
   quedan?
3. Usa `kubectl rollout pause` y `kubectl rollout resume` para aplicar varios
   cambios en un único rollout.

## Limpieza

```bash
kubectl delete namespace lab10
kubectl config set-context --current --namespace=default
```
