# Lab 15 · Troubleshooting

## Objetivos

- Aplicar una metodología sistemática para depurar en Kubernetes
- Reconocer los estados de error más habituales y su causa
- Arreglar cinco despliegues rotos a propósito
- Usar `kubectl debug` con contenedores efímeros

## Duración

75 minutos.

## Requisitos

- Clúster kind `curso` y app `contador` desplegada (lab 11), con la imagen `contador:1.0` cargada en kind
- Los manifiestos de `examples/contador/k8s/admin/broken/`

## La metodología

```bash
kubectl get pods -n contador -o wide              # 1. Estado
kubectl describe pod <pod> -n contador            # 2. Eventos y condiciones (¡léelos de abajo a arriba!)
kubectl logs <pod> -n contador --previous         # 3. Logs del contenedor que murió
kubectl get events -n contador --sort-by=.lastTimestamp   # 4. Contexto
kubectl exec -it <pod> -n contador -- sh          # 5. Mirar por dentro
```

Para cada caso: **aplica**, **diagnostica** (apunta qué comando te dio la pista), **arregla**
y **verifica** que el Pod queda `Running` y `READY 1/1`. No abras la solución hasta haberlo
intentado.

## Pasos

### 1. Roto nº 1: no arranca

```bash
kubectl apply -f examples/contador/k8s/admin/broken/01-imagen.yaml
kubectl get pods -n contador -l app.kubernetes.io/name=roto-imagen -w
```

<details>
<summary>Solución</summary>

Estado `ErrImagePull` y después `ImagePullBackOff`. `kubectl describe pod` muestra
`Failed to pull image "contador:1.0.1-final-definitivo"`: ese tag no existe (ni en kind
ni en Docker Hub).

```bash
kubectl set image deployment/roto-imagen api=contador:1.0 -n contador
```

</details>

### 2. Roto nº 2: Running, pero el Service no responde

```bash
kubectl apply -f examples/contador/k8s/admin/broken/02-selector.yaml
kubectl get pods -n contador -l app.kubernetes.io/name=roto-web
kubectl run tmp --rm -it --image=busybox:1.38 --restart=Never -n contador -- \
  wget -qO- -T 3 http://roto-web
```

<details>
<summary>Solución</summary>

Los Pods están bien, pero el Service **no tiene endpoints**:

```bash
kubectl get endpointslices -n contador -l kubernetes.io/service-name=roto-web
kubectl describe svc roto-web -n contador | grep -i selector   # rotoweb ≠ roto-web
kubectl patch svc roto-web -n contador \
  -p '{"spec":{"selector":{"app.kubernetes.io/name":"roto-web"}}}'
```

</details>

### 3. Roto nº 3: el contenedor ni siquiera se crea

```bash
kubectl apply -f examples/contador/k8s/admin/broken/03-configmap.yaml
kubectl get pods -n contador -l app.kubernetes.io/name=roto-config
```

<details>
<summary>Solución</summary>

Estado `CreateContainerConfigError`. En `describe`:
`couldn't find key APP_MESSAGE in ConfigMap contador/roto-config`. El ConfigMap tiene la
clave `MENSAJE`, no `APP_MESSAGE`. Puedes arreglar el ConfigMap o el Deployment:

```bash
kubectl patch configmap roto-config -n contador -p '{"data":{"APP_MESSAGE":"Hola desde un ConfigMap"}}'
```

El kubelet reintenta y el Pod arranca solo, sin recrearlo.

</details>

### 4. Roto nº 4: arranca, dura un segundo y se reinicia

```bash
kubectl apply -f examples/contador/k8s/admin/broken/04-memoria.yaml
kubectl get pods -n contador -l app.kubernetes.io/name=roto-memoria -w
```

<details>
<summary>Solución</summary>

Alterna entre `OOMKilled` y `CrashLoopBackOff`. En `describe`:
`Last State: Terminated · Reason: OOMKilled · Exit Code: 137`. El proceso reserva 150 MB,
pero el limit es de 100Mi.

```bash
kubectl set resources deployment/roto-memoria -n contador --limits=memory=200Mi
```

Reflexión: ¿subir el limit es siempre la solución? A veces el bug está en la app (fuga de memoria).

</details>

### 5. Roto nº 5: RESTARTS no para de subir

```bash
kubectl apply -f examples/contador/k8s/admin/broken/05-arranque.yaml
kubectl get pods -n contador -l app.kubernetes.io/name=roto-arranque -w
```

<details>
<summary>Solución</summary>

`CrashLoopBackOff`: la app termina nada más arrancar. Los logs lo explican:

```bash
kubectl logs deploy/roto-arranque -n contador --previous
# FATAL: FAIL_ON_START=falta la variable DATABASE_URL
kubectl set env deployment/roto-arranque -n contador FAIL_ON_START-
```

El tiempo entre reinicios crece de forma exponencial (10 s, 20 s, 40 s… hasta 5 min).

</details>

### 6. Depurar con un contenedor efímero

La imagen de `contador` no trae herramientas de red. Añade un contenedor de debug al Pod:

```bash
POD=$(kubectl get pod -n contador -l app.kubernetes.io/name=api -o name | head -1)
kubectl debug -it -n contador "$POD" --image=busybox:1.38 --target=api -- sh
# Dentro:
ps aux                       # ves el proceso python de "api" (namespace de PID compartido)
wget -qO- localhost:8080/info
nslookup redis
exit
```

## Retos extra

1. Rompe tú la readiness probe de `api` (ruta `/nope`) con `kubectl edit` y diagnostica el
   síntoma: `Running`, pero `0/1` y sin endpoints en el Service.
2. Usa `kubectl debug node/curso-worker -it --image=busybox:1.38` y busca los logs del
   kubelet o los contenedores en `/host/var/log/pods`.
3. Instala `stern` o `k9s` y repite un caso usándolos.
4. Por parejas: uno rompe un Deployment y el otro lo arregla.

## Limpieza

```bash
kubectl delete -f examples/contador/k8s/admin/broken/ --ignore-not-found
```
