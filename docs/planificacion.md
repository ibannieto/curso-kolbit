# Planificación del curso

- **Duración:** 37 h lectivas en 7 sesiones.
- **Horario:** de 9:00 a 14:20. El último día termina a las 14:00.
- **Modalidad:** telepresencial por Microsoft Teams.
- **Profesor:** Iban Nieto Castillero.

## Enfoque: 30 % teoría, 70 % práctica

La presentación está pensada para unas **9 o 10 h de exposición** (unas 200
diapositivas a 2,5 o 3 minutos cada una). El resto del tiempo se dedica a
demos en directo y a los **laboratorios** de [`labs/`](../labs/README.md).

Cada sesión sigue este ritmo:

| Bloque | Duración |
| --- | --- |
| Repaso del día anterior y preguntas | 10 min |
| Teoría y demo | 45–60 min |
| Laboratorio guiado | 60–75 min |
| Descanso | 20 min (hacia las 11:30) |
| Teoría y demo | 45 min |
| Laboratorio | 60 min |
| Resumen y quiz rápido | 10 min |

## Calendario

| Día | Fecha | Contenido | Ficheros | Labs |
| --- | --- | --- | --- | --- |
| 1 | Lun 23/11 | Bienvenida · **M1** Introducción a los contenedores · **M2** (I) Instalación y primeros contenedores | `00`, `01`, `02` (1.ª parte) | 00, 01, 02 |
| 2 | Mar 24/11 | **M2** (II) Imágenes, registros, redes, almacenamiento, Docker Compose | `02` (2.ª parte) | 03, 04, 05 |
| 3 | Mié 25/11 | **M3** Construcción de imágenes: Dockerfile, multi-stage, buenas prácticas y datos | `03` | 06, 07 |
| 4 | Jue 26/11 | **M4** Introducción a Kubernetes: arquitectura, clúster, Pods, Services, escalado y actualizaciones | `04` | 08, 09, 10 |
| 5 | Vie 27/11 | **M5** Despliegue de aplicaciones: manifiestos, HPA, ConfigMaps y Secrets, monitorización y logs | `05` | 11, 12, 13 |
| 6 | Lun 30/11 | **M6** (I) Administración: recursos y límites, multinodo, troubleshooting | `06` (1.ª parte) | 14, 15 |
| 7 | Mar 01/12 | **M6** (II) RBAC, cuotas, almacenamiento persistente · **Proyecto final** · Cierre y CaaS | `06` (2.ª parte), `99` | 16, 17, 18 |

## Presupuesto de diapositivas

El objetivo es mantener la presentación compacta. Se comprueba con `make stats`.

| Fichero | Módulo | Objetivo |
| --- | --- | --- |
| `00-bienvenida.md` | Portada, presentación y logística | ~10 |
| `01-contenedores.md` | M1 | ~22 |
| `02-docker.md` | M2 | ~38 |
| `03-imagenes.md` | M3 | ~30 |
| `04-kubernetes.md` | M4 | ~35 |
| `05-despliegue.md` | M5 | ~32 |
| `06-administracion.md` | M6 | ~40 |
| `99-cierre.md` | Proyecto final, CaaS y despedida | ~8 |

## Hilo conductor

Una misma aplicación de ejemplo, [`examples/contador`](../examples/contador),
recorre todo el curso. Es una API en Python con un contador guardado en Redis:

1. **M2.** `docker run` de Redis y de la API a mano, luego con redes y volúmenes, y por último con `compose.yaml`.
2. **M3.** Se escribe el Dockerfile y se optimiza con multi-stage, usuario no root y caché.
3. **M4 y M5.** Se despliega en Kubernetes con Deployment, Service, ConfigMap, Secret y HPA.
4. **M6.** Se añaden límites, cuotas, RBAC y almacenamiento persistente para Redis.
5. **Proyecto final.** Se despliega **la propia presentación del curso**, que es un
   contenedor nginx con reveal.js, en Kubernetes.

## Entorno de los alumnos

- Docker Engine o Docker Desktop, o Podman como alternativa.
- `kubectl` y `kind` para el clúster local. Opcionalmente `helm` y `k9s`.
- Editor recomendado: VS Code con las extensiones de Docker y Kubernetes.
- Guía de instalación: [`labs/lab-00-entorno.md`](../labs/lab-00-entorno.md).
