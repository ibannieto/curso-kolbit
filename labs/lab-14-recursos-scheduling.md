# Lab 14 · Recursos y scheduling

## Objetivos

- Ver la diferencia entre requests y limits, y las clases de QoS
- Aplicar una `LimitRange` con valores por defecto y máximos
- Controlar dónde se ejecutan los Pods con taints, tolerations y afinidad
- Hacer mantenimiento de un nodo con `cordon` y `drain`, respetando un PodDisruptionBudget

## Duración

75 minutos.

## Requisitos

- Clúster kind `curso` con 1 control-plane y 2 workers (lab 08)
- App `contador` desplegada en el namespace `contador` (lab 11)

```bash
kubectl config use-context kind-curso
kubectl get nodes
kubectl get pods -n contador -o wide
```

## Pasos

### 1. Clases de QoS de los Pods actuales

```bash
kubectl get pods -n contador \
  -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass,NODE:.spec.nodeName
```

Salida esperada: `api-*` y `redis-*` son **Burstable**, porque tienen requests y limits, pero no iguales.

### 2. Un Pod BestEffort y otro Guaranteed

```bash
kubectl run besteffort -n contador --image=busybox:1.38 -- sleep 3600

cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata: { name: guaranteed, namespace: contador }
spec:
  containers:
    - name: app
      image: busybox:1.38
      command: ["sleep", "3600"]
      resources:
        requests: { cpu: 100m, memory: 64Mi }
        limits:   { cpu: 100m, memory: 64Mi }
EOF

kubectl get pod besteffort guaranteed -n contador \
  -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass
```

Pregunta: si el nodo se queda sin memoria, ¿cuál se desaloja primero?

### 3. LimitRange: valores por defecto y máximos

```bash
kubectl apply -f examples/contador/k8s/admin/limitrange.yaml
kubectl describe limitrange defaults -n contador

kubectl run sinrecursos -n contador --image=busybox:1.38 -- sleep 3600
kubectl get pod sinrecursos -n contador -o jsonpath='{.spec.containers[0].resources}{"\n"}'
```

Salida esperada: `{"limits":{"cpu":"500m","memory":"256Mi"},"requests":{"cpu":"50m","memory":"64Mi"}}`.

Ahora intenta saltarte el máximo:

```bash
kubectl run gloton -n contador --image=busybox:1.38 \
  --overrides='{"spec":{"containers":[{"name":"g","image":"busybox:1.38","command":["sleep","3600"],"resources":{"limits":{"memory":"1Gi"}}}]}}'
```

Salida esperada: `Error from server (Forbidden): ... maximum memory usage per Container is 512Mi, but limit is 1Gi`.

### 4. Taints y tolerations

```bash
kubectl taint nodes curso-worker2 dedicado=lab:NoSchedule
kubectl describe node curso-worker2 | grep -i taints

kubectl rollout restart deploy/api -n contador
kubectl get pods -n contador -l app.kubernetes.io/name=api -o wide
```

Todas las réplicas nuevas de `api` deberían caer en `curso-worker`.
El control-plane tiene su propio taint: `node-role.kubernetes.io/control-plane:NoSchedule`.

Crea un Deployment que **tolere** el taint y que además **exija** ese nodo:

```bash
kubectl create deployment gpu-job -n contador --image=busybox:1.38 -- sleep 3600
kubectl patch deployment gpu-job -n contador --type=merge -p '{
  "spec":{"template":{"spec":{
    "tolerations":[{"key":"dedicado","operator":"Equal","value":"lab","effect":"NoSchedule"}],
    "affinity":{"nodeAffinity":{"requiredDuringSchedulingIgnoredDuringExecution":{
      "nodeSelectorTerms":[{"matchExpressions":[{"key":"kubernetes.io/hostname","operator":"In","values":["curso-worker2"]}]}]}}}
  }}}}'
kubectl get pods -n contador -l app=gpu-job -o wide
```

Salida esperada: el Pod `gpu-job-*` está en `curso-worker2`. Quita el taint:

```bash
kubectl taint nodes curso-worker2 dedicado=lab:NoSchedule-
```

### 5. PodDisruptionBudget y drain

```bash
kubectl apply -f examples/contador/k8s/admin/pdb.yaml
kubectl get pdb -n contador
```

Salida esperada: `api   1   N/A   1` (MIN AVAILABLE 1, ALLOWED DISRUPTIONS 1).

Vacía el nodo donde estén las réplicas de `api`:

```bash
kubectl cordon curso-worker
kubectl drain curso-worker --ignore-daemonsets --delete-emptydir-data
kubectl get pods -n contador -o wide
```

Si alguno de los Pods del paso 2 y 3 está en ese nodo, el drain **falla**:
`cannot delete Pods that declare no controller`. Los Pods sueltos (`besteffort`, `guaranteed`, `sinrecursos`) no los gestiona ningún controlador y,
si se borran, **no vuelven**. Bórralos y repite el drain:

```bash
kubectl delete pod besteffort guaranteed sinrecursos -n contador --ignore-not-found
kubectl drain curso-worker --ignore-daemonsets --delete-emptydir-data
kubectl get pods -n contador -o wide
```

Las réplicas de `api` se desalojan **de una en una** (la PDB exige 1 disponible) y se
recrean en otro nodo. Si `redis` estaba en ese nodo, se recrea en otro… y **pierde el
contador** (usa `emptyDir`). Lo arreglaremos con un StatefulSet y un PVC en el lab 17.

Ahora provoca un bloqueo. Con 2 réplicas y `minAvailable: 2`, no se puede desalojar ninguna:

```bash
kubectl uncordon curso-worker
kubectl rollout restart deploy/api -n contador && kubectl rollout status deploy/api -n contador
kubectl get pods -n contador -l app.kubernetes.io/name=api -o wide   # una réplica en cada worker
kubectl patch pdb api -n contador --type=merge -p '{"spec":{"minAvailable":2}}'
kubectl drain curso-worker2 --ignore-daemonsets --delete-emptydir-data --timeout=30s
```

Salida esperada: `Cannot evict pod as it would violate the pod's disruption budget.`

```bash
kubectl uncordon curso-worker2
kubectl patch pdb api -n contador --type=merge -p '{"spec":{"minAvailable":1}}'
```

## Retos extra

1. Añade a `api` una `topologySpreadConstraints` con `maxSkew: 1` por `kubernetes.io/hostname`,
   escala a 4 réplicas (sube antes `minReplicas` del HPA) y comprueba el reparto.
2. Cambia en caliente el request de CPU de un Pod de `api` con
   `kubectl patch pod ... --subresource resize` y comprueba que `RESTARTS` no cambia.
3. ¿Qué QoS tiene un Pod con request y limit solo de memoria, iguales, pero sin CPU?

## Limpieza

```bash
kubectl delete pod besteffort guaranteed sinrecursos -n contador --ignore-not-found
kubectl delete deployment gpu-job -n contador
kubectl uncordon curso-worker curso-worker2
```

Deja la `LimitRange` y la PDB: las usaremos en el lab 17.
