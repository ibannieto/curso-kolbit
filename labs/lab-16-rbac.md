# Lab 16 · Usuarios y RBAC

## Objetivos

- Crear una ServiceAccount con un Role de mínimo privilegio
- Comprobar permisos con `kubectl auth can-i --as`
- Crear un usuario humano (`alumno`) con certificado X.509 mediante la API CSR
- Configurar un contexto de kubeconfig con permisos de solo lectura
- Aislar Redis con una NetworkPolicy para que solo la API pueda conectarse

## Duración

75 minutos.

## Requisitos

- Clúster kind `curso` y namespace `contador` (lab 11)
- `openssl` instalado
- Contexto de administración `kind-curso` activo

## Pasos

### 1. Aplicar los objetos RBAC

```bash
kubectl apply -f examples/contador/k8s/admin/rbac.yaml
kubectl get sa,role,rolebinding -n contador
```

Revisa el fichero: `ci-deployer` puede gestionar Deployments, Services y ConfigMaps, pero
**no** puede borrar ni ver Secrets. `viewer` solo lee.

### 2. ¿Qué puede hacer la ServiceAccount?

```bash
SA=system:serviceaccount:contador:ci-deployer
kubectl auth can-i create deployments -n contador --as=$SA   # yes
kubectl auth can-i delete deployments -n contador --as=$SA   # no
kubectl auth can-i get secrets -n contador --as=$SA          # no
kubectl auth can-i create deployments -n default --as=$SA    # no (otro namespace)
kubectl auth can-i --list -n contador --as=$SA
```

### 3. Usar un token de la ServiceAccount

```bash
TOKEN=$(kubectl create token ci-deployer -n contador --duration=30m)
kubectl config set-credentials ci-deployer --token="$TOKEN"
kubectl config set-context ci@curso --cluster=kind-curso --user=ci-deployer --namespace=contador

kubectl --context ci@curso get deployments                 # funciona
kubectl --context ci@curso get secrets                     # Forbidden
kubectl --context ci@curso auth whoami
```

Salida esperada del último comando: `Username  system:serviceaccount:contador:ci-deployer`.

Decodifica el token (es un JWT) y mira su caducidad:

```bash
cut -d. -f2 <<<"$TOKEN" | base64 -d 2>/dev/null; echo
```

### 4. Crear el usuario `alumno` con un certificado

Clave y petición de certificado (CN = usuario, O = grupo):

```bash
mkdir -p ~/k8s-alumno && cd ~/k8s-alumno
openssl genrsa -out alumno.key 2048
openssl req -new -key alumno.key -out alumno.csr -subj "/CN=alumno/O=alumnos"
```

Envía la petición a Kubernetes:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: alumno
spec:
  request: $(base64 -w0 < alumno.csr)
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages: ["client auth"]
EOF
kubectl get csr alumno
```

Salida esperada: `CONDITION: Pending`. Como administrador, apruébala y descarga el certificado:

```bash
kubectl certificate approve alumno
kubectl get csr alumno -o jsonpath='{.status.certificate}' | base64 -d > alumno.crt
openssl x509 -in alumno.crt -noout -subject -issuer -enddate
```

<small>En macOS, usa `base64 -i alumno.csr` en vez de `base64 -w0 < alumno.csr`.</small>

### 5. Contexto de kubeconfig para `alumno`

```bash
kubectl config set-credentials alumno \
  --client-key=alumno.key --client-certificate=alumno.crt --embed-certs=true
kubectl config set-context alumno@curso --cluster=kind-curso --user=alumno --namespace=contador

kubectl --context alumno@curso auth whoami        # Username alumno, Groups [alumnos system:authenticated]
kubectl --context alumno@curso get pods           # funciona (Role viewer)
kubectl --context alumno@curso logs deploy/api    # funciona
kubectl --context alumno@curso delete pod --all   # Forbidden
kubectl --context alumno@curso get secrets        # Forbidden
kubectl --context alumno@curso get pods -n kube-system   # Forbidden
```

### 6. Dar permisos a un grupo en vez de a un usuario

Asigna el ClusterRole predefinido `view` al **grupo** `alumnos` solo en `default`:

```bash
kubectl create rolebinding alumnos-view -n default --clusterrole=view --group=alumnos
kubectl --context alumno@curso get pods -n default   # ahora sí
```

### 7. NetworkPolicy: Redis solo para la API

Antes de aplicar nada, cualquier Pod del clúster llega a Redis:

```bash
kubectl run intruso -n contador --rm -it --image=busybox:1.38 --restart=Never -- \
  nc -zv -w 3 redis 6379
# redis (10.96.x.x:6379) open
```

Verás un aviso de Pod Security (`would violate PodSecurity "restricted"`): el
namespace solo *avisa* de `restricted`, así que el Pod se crea igualmente.

Aplica las políticas y repite la prueba:

```bash
kubectl apply -f examples/contador/k8s/admin/networkpolicy.yaml
kubectl get networkpolicy -n contador

kubectl run intruso -n contador --rm -it --image=busybox:1.38 --restart=Never -- \
  nc -zv -w 3 redis 6379
# nc: redis (10.96.x.x:6379): Connection timed out
```

La API sigue funcionando, porque sus Pods sí tienen permitido el acceso:

```bash
kubectl -n contador port-forward svc/api 8080:80 &
curl -s localhost:8080/        # el contador sigue subiendo
kill %1
```

> El tráfico denegado **no da error**: simplemente no llega (timeout). Es lo que
> verás cuando una NetworkPolicy bloquee algo que no esperabas.

## Retos extra

1. Revisa quién tiene `cluster-admin` en tu clúster:
   `kubectl get clusterrolebindings -o wide | grep cluster-admin`.
2. Crea un Pod que use la ServiceAccount `ci-deployer` (`serviceAccountName`) con la imagen
   oficial `registry.k8s.io/kubectl:v1.37.2`, y lista los Deployments desde dentro.
   ¿Qué pasa con `automountServiceAccountToken: false`?
3. El namespace `contador` aplica `baseline` y solo avisa de `restricted`. Sube el nivel con
   `kubectl label ns contador pod-security.kubernetes.io/enforce=restricted --overwrite`
   y comprueba que la API y Redis siguen arrancando, pero un `kubectl run` de busybox ya no.
4. ¿Cómo «revocarías» el certificado de `alumno`? (Pista: no se puede; borra su RoleBinding.)

## Limpieza

```bash
kubectl config use-context kind-curso
kubectl config delete-context alumno@curso; kubectl config delete-user alumno
kubectl config delete-context ci@curso;     kubectl config delete-user ci-deployer
kubectl delete csr alumno
kubectl delete rolebinding alumnos-view -n default
kubectl delete -f examples/contador/k8s/admin/networkpolicy.yaml
```
