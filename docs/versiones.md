# Versiones de referencia

Versiones vigentes al preparar el curso (**22/11/2026**), consultadas en las
releases oficiales de GitHub y en los registros de imágenes y paquetes. Los
ejemplos de la presentación y de los laboratorios usan estas versiones.

| Componente | Versión | Notas |
| --- | --- | --- |
| Docker Engine (moby) | 29.10.0 | containerd image store por defecto desde la 29 |
| Docker Compose | v5.8.0 | Plugin `docker compose`; el binario `docker-compose` v1 está muerto desde 2023 |
| Docker Buildx / BuildKit | 0.39.1 | BuildKit es el builder por defecto |
| Podman | 6.2.0 | Alternativa daemonless y rootless, compatible con la CLI de Docker |
| containerd | 2.4.2 | Runtime CRI de la mayoría de distribuciones de Kubernetes |
| Kubernetes | 1.37.2 | Tres minors al año; la 1.38 está prevista para diciembre de 2026 |
| kind | 0.33.0 | Clúster local para los laboratorios |
| minikube | 1.39.0 | Alternativa a kind |
| k3s | 1.37.2+k3s1 | Distribución ligera |
| Talos Linux | 1.14.6 | SO del clúster Hetzner del profesor |
| Helm | 4.3.2 | Helm 4 (noviembre de 2025) |
| Kustomize | 5.8.3 | Integrado en `kubectl apply -k` |
| Gateway API | 1.7.0 | Sustituto recomendado de Ingress |
| metrics-server | 0.9.1 | Necesario para `kubectl top` y HPA |
| reveal.js | 6.0.2 | Framework de la presentación |
| Node.js | 26 LTS | Imagen de build `node:26.13.1-alpine` |
| nginx-unprivileged | 1.30.6 | Imagen final `nginxinc/nginx-unprivileged:1.30.6-alpine-slim` |
| decktape | 3.17.0 | Exportación a PDF |

## Cambios recientes del ecosistema que se cuentan en el curso

- **Ingress NGINX ha sido retirado.** Recibió mantenimiento mínimo hasta marzo
  de 2026 y el repositorio está archivado. Para tráfico de entrada se recomienda
  **Gateway API**.
- **dockershim** se eliminó en Kubernetes 1.24. Kubernetes usa runtimes CRI
  (containerd, CRI-O), y las imágenes construidas con Docker son imágenes OCI y
  siguen funcionando igual.
- **cgroup v2** es el estándar, y el soporte de cgroup v1 está en retirada en
  Kubernetes.
- Funcionalidades que ya son GA: **sidecar containers** (`initContainers` con
  `restartPolicy: Always`), **in-place pod resize** y la **API de VolumeSnapshot**.
- Docker Hub limita los **pulls** anónimos. Por eso conviene usar `docker login`,
  un mirror o un registro propio como GHCR o Harbor.
- **Bitnami** retiró en 2025 su catálogo gratuito de imágenes con versión
  (ahora en `bitnamilegacy`). Es un buen ejemplo de por qué conviene fijar la
  versión de las imágenes y controlar sus fuentes.
- La versión de **Compose** está en el propio fichero: `compose.yaml` y la
  Compose Specification, sin la clave `version:`.
