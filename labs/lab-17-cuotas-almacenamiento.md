# Lab 17 · Cuotas y almacenamiento persistente

## Objetivos

- Limitar un namespace con `ResourceQuota` y `LimitRange`
- Superar la cuota a propósito y entender el error
- Entender StorageClass, PVC y PV con provisión dinámica
- Migrar Redis a un **StatefulSet** con volumen persistente y demostrar que los datos sobreviven

## Duración

60 minutos.

## Requisitos

- Clúster kind `curso` y app `contador` desplegada en `contador` (lab 11)
- LimitRange del lab 14 (se vuelve a aplicar en el paso 1)

## Pasos

### 1. Cuota y valores por defecto

```bash
kubectl apply -f examples/contador/k8s/admin/limitrange.yaml
kubectl apply -f examples/contador/k8s/admin/resourcequota.yaml
kubectl describe quota cuota -n contador
```

Salida esperada: una tabla `Resource / Used / Hard` con el consumo actual de `api` y `redis`.

### 2. Superar la cuota

La cuota permite 10 Pods. Crea un Deployment que pida 12 réplicas:

```bash
kubectl create deployment relleno -n contador \
  --image=nginxinc/nginx-unprivileged:1.30.6-alpine-slim --replicas=12
kubectl get deployment relleno -n contador
kubectl describe quota cuota -n contador | grep pods
```

`READY` se queda por debajo de 12. ¿Dónde está el error? No en el Deployment, sino en su
**ReplicaSet**:

```bash
kubectl describe rs -n contador -l app=relleno | grep -i -A2 quota
```

Salida esperada (algo similar a):
`Error creating: pods "relleno-..." is forbidden: exceeded quota: cuota, requested: pods=1, used: pods=10, limited: pods=10`.

Pregunta: los Pods de `relleno` no declaran recursos. ¿Por qué la cuota de CPU y memoria no
los rechaza? (Pista: `kubectl get pod <relleno> -o yaml | grep -A6 resources`).

```bash
kubectl delete deployment relleno -n contador
```

### 3. StorageClass del clúster

```bash
kubectl get storageclass
```

Salida esperada en kind: `standard (default)   rancher.io/local-path   Delete   WaitForFirstConsumer`.
El driver local-path crea directorios en el disco del nodo: perfecto para laboratorios,
**no** para producción.

### 4. El problema: Redis sin persistencia

```bash
kubectl port-forward -n contador svc/api 8080:80 >/dev/null &
for i in 1 2 3; do curl -s localhost:8080/; done
kubectl delete pod -n contador -l app.kubernetes.io/name=redis
sleep 10; curl -s localhost:8080/
```

Salida esperada: después de borrar el Pod de Redis, `visits` vuelve a **1**. El `emptyDir`
muere con el Pod.

### 5. Migrar Redis a un StatefulSet con PVC

```bash
kubectl delete -n contador deployment/redis service/redis
kubectl apply -f examples/contador/k8s/admin/redis-statefulset.yaml
kubectl get pvc -n contador -w
```

Observa cómo el PVC `data-redis-0` pasa de `Pending` a `Bound`: con `WaitForFirstConsumer`,
el volumen no se crea hasta que el Pod `redis-0` se programa en un nodo.

```bash
kubectl get statefulset,pods,pvc -n contador
kubectl get pv
kubectl describe quota cuota -n contador | grep -E 'persistentvolumeclaims|requests.storage'
```

### 6. Demostrar la persistencia

```bash
for i in 1 2 3 4 5; do curl -s localhost:8080/; done     # visits: 1..5
kubectl delete pod redis-0 -n contador
kubectl wait pod redis-0 -n contador --for=condition=Ready --timeout=60s
curl -s localhost:8080/                                  # visits: 6 🎉
```

El Pod nuevo se llama **igual** (`redis-0`) y monta **el mismo** PVC. Compruébalo dentro:

```bash
kubectl exec redis-0 -n contador -- ls -la /data/appendonlydir
```

### 7. ¿Qué pasa al borrar el StatefulSet?

```bash
kubectl delete statefulset redis -n contador
kubectl get pvc -n contador       # data-redis-0 sigue ahí
kubectl apply -f examples/contador/k8s/admin/redis-statefulset.yaml
kubectl wait pod redis-0 -n contador --for=condition=Ready --timeout=60s
curl -s localhost:8080/           # el contador continúa
```

## Retos extra

1. Escala el StatefulSet a 2 réplicas: ¿cuántos PVC hay ahora? ¿Comparten datos `redis-0` y
   `redis-1`? (No: cada réplica tiene su propio volumen. La replicación es cosa de la app.)
2. Intenta ampliar el PVC a 2Gi editando `spec.resources.requests.storage`. ¿Por qué falla
   en kind? (Mira `ALLOWVOLUMEEXPANSION` en `kubectl get storageclass`.) En Hetzner
   (`hcloud-volumes`) sí funciona.
3. Crea un PVC de 3Gi. ¿Quién lo rechaza, la LimitRange o la ResourceQuota?
4. Cambia la `reclaimPolicy` del PV a `Retain` con `kubectl patch pv` y razona cuándo
   tiene sentido.

## Limpieza

```bash
kill %1 2>/dev/null                                   # port-forward
kubectl delete -f examples/contador/k8s/admin/resourcequota.yaml
# Para volver al Redis sin persistencia del lab 11:
#   kubectl delete -f examples/contador/k8s/admin/redis-statefulset.yaml
#   kubectl delete pvc data-redis-0 -n contador
#   kubectl apply -k examples/contador/k8s
```
