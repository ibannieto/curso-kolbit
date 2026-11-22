# Lab 00 · Preparar el entorno

## Objetivos

- Instalar un motor de contenedores: Docker Engine, Docker Desktop o Podman.
- Instalar `kubectl`, `kind` y `helm`, que usaremos a partir del día 4.
- Verificar que todo funciona y clonar el material del curso.

**Duración:** 30 min · **Requisitos:** equipo con 8 GB de RAM (16 GB recomendados),
20 GB libres y permisos de administrador.

## Pasos

### 1. Motor de contenedores

Elige **una** opción.

#### Opción A: Linux con Docker Engine (recomendada)

```bash
# Script oficial de Docker (Debian, Ubuntu, Fedora, RHEL…)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Usar docker sin sudo (⚠ el grupo docker equivale a root en el host)
sudo usermod -aG docker "$USER"
newgrp docker
```

> En producción, configura el repositorio apt o dnf oficial siguiendo
> <https://docs.docker.com/engine/install/> en lugar de usar el script.

#### Opción B: Mac o Windows con Docker Desktop

1. Descarga Docker Desktop desde <https://www.docker.com/products/docker-desktop/>.
2. En Windows, activa el backend **WSL 2** y trabaja desde una terminal de WSL (Ubuntu).
3. Asígnale al menos 4 GB de RAM en *Settings → Resources*.

> Docker Desktop requiere suscripción de pago en empresas grandes. Revisa la
> licencia con tu organización.

#### Opción C: Podman (Linux, Mac o Windows)

```bash
# Linux (Fedora/RHEL: dnf · Debian/Ubuntu: apt · Arch: pacman)
sudo apt-get install -y podman
# Mac/Windows: Podman Desktop (https://podman-desktop.io) o:
podman machine init && podman machine start

alias docker=podman      # casi todos los comandos del curso funcionan igual
```

### 2. Verificar el motor de contenedores

```bash
docker version
docker run --rm hello-world
```

Salida esperada (fragmento):

```text
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

### 3. kubectl

```bash
# Linux amd64 (para arm64 cambia amd64 → arm64)
curl -LO "https://dl.k8s.io/release/v1.37.2/bin/linux/amd64/kubectl"
sudo install -m 0755 kubectl /usr/local/bin/kubectl && rm kubectl
kubectl version --client
```

En Mac: `brew install kubectl` · En Windows: `winget install Kubernetes.kubectl`.

### 4. kind (Kubernetes in Docker)

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.33.0/kind-linux-amd64
sudo install -m 0755 kind /usr/local/bin/kind && rm kind
kind version
```

En Mac: `brew install kind` · En Windows: `winget install Kubernetes.kind`.

### 5. Helm 4

```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-4 | bash
helm version
```

### 6. Prueba rápida de kind

```bash
kind create cluster --name prueba
kubectl get nodes
kind delete cluster --name prueba
```

Salida esperada:

```text
NAME                   STATUS   ROLES           AGE   VERSION
prueba-control-plane   Ready    control-plane   30s   v1.37.x
```

> **kind + Podman:** exporta `KIND_EXPERIMENTAL_PROVIDER=podman` antes de crear
> el clúster.

### 7. Material del curso

El profesor compartirá el acceso al repositorio:

```bash
git clone <URL-del-repositorio> curso-kolbit
cd curso-kolbit
tree -L 1 labs examples
```

### 8. Editor (opcional pero recomendado)

- **VS Code** con las extensiones *Container Tools* y *Kubernetes*.
- Herramientas extra: `k9s` (TUI para Kubernetes) y `jq`.

## Comprobación final

```bash
docker run --rm alpine:3.24 echo "contenedores OK"
kubectl version --client --output=yaml | grep gitVersion
kind version && helm version --short
```

## Problemas frecuentes

| Síntoma | Solución |
| --- | --- |
| `permission denied ... docker.sock` | No estás en el grupo `docker`: `newgrp docker` o vuelve a iniciar sesión |
| `Cannot connect to the Docker daemon` | `sudo systemctl start docker` / abre Docker Desktop |
| `toomanyrequests` al hacer pull | Límite de Docker Hub: `docker login` |
| kind tarda o falla en Mac/Windows | Dale más RAM y CPU a la VM de Docker Desktop o Podman |

## Limpieza

Nada que limpiar: el entorno se usa durante todo el curso.
