# Lab 12 · Autoescalado con HPA

## Objetivos

- Instalar metrics-server en kind
- Consultar el consumo con `kubectl top`
- Ver cómo el HorizontalPodAutoscaler escala `contador` bajo carga
- Entender el papel de los `requests` y de la ventana de estabilización

## Duración

45 minutos.

## Requisitos

- `contador` desplegado en el namespace `contador` ([Lab 11](lab-11-despliegue-contador.md))

## Pasos

### 1. Instalar metrics-server

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.9.1/components.yaml
```

En kind, los kubelets usan certificados autofirmados, así que metrics-server
necesita `--kubelet-insecure-tls` (**solo en laboratorio**):

```bash
kubectl -n kube-system patch deployment metrics-server --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl -n kube-system rollout status deployment/metrics-server
```

Espera un minuto y comprueba:

```bash
kubectl top nodes
kubectl top pods -n contador
```

### 2. Revisar el HPA

```bash
cat examples/contador/k8s/hpa.yaml
kubectl -n contador get hpa api
kubectl -n contador describe hpa api
```

Salida esperada:

```text
NAME   REFERENCE        TARGETS       MINPODS   MAXPODS   REPLICAS
api    Deployment/api   cpu: 2%/50%   2         10        2
```

> El porcentaje se calcula sobre el **request** de CPU (`100m`). Sin requests,
> el HPA no puede funcionar.

### 3. Observar

Abre una segunda terminal:

```bash
kubectl -n contador get hpa api -w
```

Y una tercera (opcional):

```bash
watch -n 2 kubectl -n contador top pods
```

### 4. Generar carga

El endpoint `/load` quema CPU durante 2 segundos en cada petición. Lanza un Pod
generador de carga:

```bash
kubectl -n contador run carga --image=busybox:1.37 --restart=Never -- \
  sh -c 'while true; do wget -qO- http://api/load >/dev/null; done'
```

Para más carga, lanza varios:

```bash
for i in 2 3 4; do
  kubectl -n contador run carga$i --image=busybox:1.37 --restart=Never -- \
    sh -c 'while true; do wget -qO- http://api/load >/dev/null; done'
done
```

En uno o dos minutos verás subir `TARGETS` por encima del 50 % y `REPLICAS` hacia 10:

```text
api    Deployment/api   cpu: 248%/50%   2   10   2
api    Deployment/api   cpu: 248%/50%   2   10   4
api    Deployment/api   cpu: 131%/50%   2   10   8
api    Deployment/api   cpu: 72%/50%    2   10   10
```

### 5. Parar la carga y ver el desescalado

```bash
kubectl -n contador delete pod carga carga2 carga3 carga4
```

El HPA espera la **ventana de estabilización** (`stabilizationWindowSeconds: 60`
en nuestro manifiesto; 300 s por defecto) antes de reducir réplicas, para no
oscilar.

```bash
kubectl -n contador describe hpa api | sed -n '/Events/,$p'
```

## Retos extra

1. Añade una métrica de memoria al HPA (`type: Resource`, `name: memory`,
   `averageUtilization: 70`). ¿Cómo combina el HPA varias métricas?
2. Configura `behavior.scaleUp.policies` para que solo pueda añadir 1 Pod cada
   30 segundos y repite la prueba.
3. ¿Qué pasa si `maxReplicas` es mayor de lo que caben en los nodos? Ponlo a 50,
   genera carga y busca Pods en `Pending` (`kubectl describe pod`).

## Limpieza

```bash
kubectl -n contador delete pod carga carga2 carga3 carga4 --ignore-not-found
```

> Deja metrics-server instalado: lo usaremos en los labs 13 y 14.
