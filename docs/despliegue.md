# Publicación de la imagen y despliegue en Kubernetes

## 1. Publicar la imagen en GHCR (desde el equipo local)

La imagen se construye y se publica con podman desde el portátil, porque los
minutos de GitHub Actions están agotados.

```bash
# Solo una vez: el token de gh necesita permiso para escribir paquetes
gh auth refresh -h github.com -s write:packages

make login            # gh auth token | podman login ghcr.io
make image            # ghcr.io/ibannieto/curso-kolbit:<commit> y :latest
make push             # se niega si hay cambios sin commitear (FORCE=1 para forzarlo)
```

- **Paquete:** `ghcr.io/ibannieto/curso-kolbit`. Es privado y está vinculado al
  repositorio por la etiqueta OCI `org.opencontainers.image.source`.
- **Tags:** el commit corto (inmutable, es el que se despliega) y `latest`, solo
  como referencia.
- **Plataforma:** `linux/amd64`, porque los nodos de Hetzner son x86_64. Se
  puede cambiar con `PLATFORM=...`.

## 2. Desplegar en el clúster Hetzner

```bash
kubectl config current-context    # admin@belters
make deploy                       # fija el tag, aplica el overlay y espera al rollout
make k8s-status
make k8s-smoke                    # port-forward temporal y smoke test
make k8s-forward                  # http://localhost:8081
```

`make deploy` escribe el tag en `k8s/overlays/hetzner/kustomization.yaml` (en
la línea `# managed-by: make deploy`). Commitea ese cambio para que el
repositorio refleje lo que está desplegado.

### Qué se despliega (`k8s/base`)

| Recurso | Detalle |
| --- | --- |
| Namespace `curso-kolbit` | Pod Security Admission `restricted` |
| Deployment `curso-kolbit` | 2 réplicas, rolling update sin pérdida de disponibilidad, reparto entre nodos, sin token de ServiceAccount, sistema de ficheros de solo lectura con `emptyDir` en `/tmp`, probes en `/healthz` |
| Service `curso-kolbit` | ClusterIP, puerto 80 → 8080 |
| PodDisruptionBudget | `minAvailable: 1` |
| NetworkPolicy | Solo entrada al 8080 y ninguna salida |

### Particularidades del overlay `hetzner`

- **Imagen privada:** el namespace lleva la etiqueta
  `registry.malaleche.xyz/ghcr: enabled`, y la ClusterExternalSecret
  `ghcr-pull` (External Secrets Operator) crea en él el Secret `ghcr-pull`,
  que el Deployment usa como `imagePullSecrets`. Así no hay ningún token en el
  repositorio.
- **Acceso:** por defecto solo dentro del clúster (port-forward). Para
  publicarlo con **Gateway API**, ajusta `k8s/components/httproute` (Gateway y
  hostname) y descomenta `components:` en el overlay. El clúster tiene la
  GatewayClass `cilium` y cert-manager con `letsencrypt-prod`.
- **GitOps:** el clúster lo gestiona Flux desde `belters-apps`. Este despliegue
  se aplica con `kubectl` en un namespace que Flux no gestiona. Para llevarlo a
  GitOps, añade una `Kustomization` de Flux que apunte a
  `k8s/overlays/hetzner` de este repositorio.

## 3. Clúster local con kind

```bash
make image
podman save localhost/curso-kolbit:dev -o /tmp/curso-kolbit.tar
kind load image-archive /tmp/curso-kolbit.tar     # con Docker: kind load docker-image curso-kolbit:dev
kubectl apply -k k8s/overlays/kind
kubectl -n curso-kolbit port-forward svc/curso-kolbit 8081:80
```

## 4. Retirar la presentación

```bash
make k8s-delete
```
