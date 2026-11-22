# Laboratorios

Prácticas guiadas del curso. Cada laboratorio indica sus objetivos, duración,
requisitos, pasos con la salida esperada, retos extra y limpieza.

| Lab | Día | Módulo | Título | Duración |
| --- | --- | --- | --- | --- |
| [00](lab-00-entorno.md) | 1 | — | Preparación del entorno | 30 min |
| [01](lab-01-primeros-contenedores.md) | 1 | M2 | Primeros contenedores | 45 min |
| [02](lab-02-gestion-contenedores.md) | 1 | M2 | Gestión de contenedores | 45 min |
| [03](lab-03-imagenes-registros.md) | 2 | M2 | Imágenes y registros | 60 min |
| [04](lab-04-redes-volumenes.md) | 2 | M2 | Redes y volúmenes | 60 min |
| [05](lab-05-compose.md) | 2 | M2 | Docker Compose | 60 min |
| [06](lab-06-dockerfile.md) | 3 | M3 | Dockerfile paso a paso | 75 min |
| [07](lab-07-buenas-practicas.md) | 3 | M3 | Buenas prácticas de imágenes | 75 min |
| [08](lab-08-cluster-kind.md) | 4 | M4 | Clúster local con kind | 45 min |
| [09](lab-09-pods-services.md) | 4 | M4 | Pods y Services | 60 min |
| [10](lab-10-deployments.md) | 4 | M4 | Deployments: escalado y actualizaciones | 60 min |
| [11](lab-11-despliegue-contador.md) | 5 | M5 | Desplegar contador con Kustomize | 60 min |
| [12](lab-12-autoescalado.md) | 5 | M5 | Autoescalado con HPA | 45 min |
| [13](lab-13-monitorizacion-logs.md) | 5 | M5 | Monitorización y logs | 60 min |
| [14](lab-14-recursos-scheduling.md) | 6 | M6 | Recursos, límites y scheduling | 75 min |
| [15](lab-15-troubleshooting.md) | 6 | M6 | Troubleshooting | 90 min |
| [16](lab-16-rbac.md) | 7 | M6 | Usuarios y RBAC | 60 min |
| [17](lab-17-cuotas-almacenamiento.md) | 7 | M6 | Cuotas y almacenamiento persistente | 60 min |
| [18](lab-18-proyecto-final.md) | 7 | — | Proyecto final: desplegar esta presentación | 60 min |

## Entorno

- **Docker** Engine 29 o Docker Desktop. **Podman** 5 o superior también vale:
  `alias docker=podman`.
- **kubectl** 1.37, **kind** 0.33 y, opcionalmente, **helm** 4 y **k9s**.
- La app de ejemplo [`examples/contador`](../examples/contador) se usa desde el
  lab 04 hasta el 17.

## Consejos

- Copia los comandos de uno en uno y lee la salida: es la mitad del aprendizaje.
- Si algo falla, aplica la metodología del curso: `get` → `describe` → `logs` →
  `events`.
- Al terminar cada lab, haz la **limpieza** para no arrastrar recursos al
  siguiente.
