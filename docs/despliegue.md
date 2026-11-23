# Publicación de la imagen y despliegue

La presentación se despliega con **GitOps**: la gestiona **Flux** en el
clúster `belters` desde el repositorio
[`ibannieto/belters-apps`](https://github.com/ibannieto/belters-apps), fichero
`apps/curso-kolbit/curso-kolbit.yaml`. Está publicada en
**<https://curso.malaleche.xyz>** mediante Gateway API.

> Un `kubectl apply` directo **no sirve**: Flux lo revierte en la siguiente
> reconciliación. Desplegar es cambiar el digest de la imagen en `belters-apps`.

## 1. Publicar la imagen en GHCR (desde el equipo local)

La imagen se construye y se publica con podman desde el portátil, porque los
minutos de GitHub Actions están agotados.

```bash
# Solo una vez: el token de gh necesita permiso para escribir paquetes
gh auth refresh -h github.com -s write:packages

make login            # gh auth token | podman login ghcr.io (repetir si el push da 403)
make image            # ghcr.io/ibannieto/curso-kolbit:<commit> y :latest
make push             # se niega si hay cambios sin commitear (FORCE=1 para forzarlo)
```

- **Paquete:** `ghcr.io/ibannieto/curso-kolbit`. Es privado y está vinculado al
  repositorio por la etiqueta OCI `org.opencontainers.image.source`.
- **Tags:** el commit corto (inmutable) y `latest`, solo como referencia. En
  el clúster se fija `tag@sha256:digest`.
- **Plataforma:** `linux/amd64`, porque los nodos de Hetzner son x86_64.

## 2. Desplegar (GitOps)

```bash
make deploy           # commit "Deploy curso-kolbit <commit>" en ../belters-apps (sin push)
make deploy PUSH=1    # además: push, flux reconcile y espera al rollout
make version          # compara el commit local con https://curso.malaleche.xyz/version.json
```

`make deploy` ejecuta `scripts/gitops-deploy.sh`, que:

1. Comprueba que el clon de `belters-apps` (`BELTERS_APPS`, por defecto
   `../belters-apps`) está en `main`, sin cambios, y lo actualiza con
   `git pull --ff-only`.
2. Obtiene con `skopeo` el digest de `IMAGE:TAG`. Si la imagen no está en el
   registro, se detiene.
3. Sustituye la línea `image:` del manifiesto por `IMAGE:TAG@sha256:…` y hace
   commit siguiendo las convenciones del repositorio. Sus hooks de pre-commit se
   ejecutan, incluido `no-ai-attribution`.
4. Sin `PUSH=1`, se detiene e indica el comando para publicarlo, porque es el
   repositorio GitOps de producción.

Comprobaciones:

```bash
flux get kustomizations
make k8s-status       # Deployment, Pods, Service… e imagen en uso
make k8s-smoke        # port-forward temporal y smoke test
make version
```

### Qué hay en el clúster

La definición vive en `belters-apps` (no en este repositorio):

| Recurso | Detalle |
| --- | --- |
| Namespace `curso-kolbit` | Pod Security `restricted`, Secret de pull `ghcr-pull` (External Secrets) y permiso para colgar rutas del Gateway público |
| Deployment `curso-kolbit` | 2 réplicas, rolling update sin pérdida de disponibilidad, reparto entre nodos, sin token de ServiceAccount, sistema de ficheros de solo lectura |
| Service, PDB y NetworkPolicy | Equivalentes a `k8s/base` de este repositorio |
| HTTPRoute | `curso.malaleche.xyz` en el Gateway `gateway/public` (HTTPS) |

### Retirar la presentación

Se quita `curso-kolbit` de `apps/kustomization.yaml` en `belters-apps`, se hace
commit y push, y Flux borra los recursos (con `prune`).

## 3. Clúster local con kind (lab 18)

`k8s/` contiene la versión didáctica del despliegue: una base de Kustomize y el
overlay `kind`.

```bash
make image
podman save localhost/curso-kolbit:dev -o /tmp/curso-kolbit.tar
kind load image-archive /tmp/curso-kolbit.tar     # con Docker: kind load docker-image curso-kolbit:dev
kubectl apply -k k8s/overlays/kind
kubectl -n curso-kolbit port-forward svc/curso-kolbit 8081:80
```

El componente `k8s/components/httproute` muestra cómo se publicaría con Gateway
API, y se usa como reto en el lab 18.
