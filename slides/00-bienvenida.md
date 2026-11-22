<!-- .slide: class="module center-v" -->

<span class="kicker">Curso · 23/11/2026 – 01/12/2026</span>

# Docker & Kubernetes & CaaS

<div class="agenda">

Iban Nieto Castillero · 37 h · Microsoft Teams

</div>

<div class="logo-row">
  <img src="assets/img/logos/docker.svg" alt="Docker">
  <img src="assets/img/logos/kubernetes.svg" alt="Kubernetes">
  <img src="assets/img/logos/podman.svg" alt="Podman">
  <img src="assets/img/logos/helm.svg" alt="Helm">
</div>

Note:
Bienvenida. Presentarse, comprobar audio y pantalla compartida en Teams.
Atajos de la presentación: S (notas), O (vista general), F (pantalla completa), Ctrl+Shift+F (buscar), Alt+clic (zoom).

---

## ¿Quién soy?

<div class="cols wide-left">
<div>

- **Iban Nieto Castillero**
- Muchos años construyendo, desplegando y rompiendo (y arreglando) plataformas
- Contenedores en producción desde los tiempos de `docker run -d` y rezar
- Hoy: Kubernetes en Hetzner con Talos Linux, GitOps con Flux y Cilium

</div>
<div class="center">

<img src="assets/img/phippy/captain_kube.svg" alt="Captain Kube" style="height:380px">

</div>
</div>

Note:
Adaptar la presentación personal. Preguntar a los alumnos: rol, experiencia con Linux, Docker y Kubernetes, y qué esperan del curso.

---

## ¿Y vosotros?

- ¿Cuál es vuestro rol? (dev, ops, QA, seguridad…)
- ¿Qué tal os manejáis con la **terminal Linux**?
- ¿Habéis usado **Docker**? ¿Y **Kubernetes**?
- ¿Qué queréis llevaros del curso?

<div class="box tip">

Ronda rápida de 1 minuto por persona.

</div>

---

## Objetivos del curso

<div class="cols">
<div>

**Docker**

- Entender qué es (y qué no es) un contenedor
- Ejecutar, inspeccionar y depurar contenedores
- Construir imágenes pequeñas, seguras y reproducibles
- Orquestar en local con Compose

</div>
<div>

**Kubernetes**

- Entender la arquitectura de un clúster
- Desplegar, escalar y actualizar aplicaciones
- Configurar, monitorizar y depurar
- Administrar recursos, usuarios y almacenamiento

</div>
</div>

---

## Calendario

| Día | Fecha | Contenido |
| --- | --- | --- |
| 1 | Lun 23/11 | M1 Contenedores · M2 Docker (I) |
| 2 | Mar 24/11 | M2 Docker (II): imágenes, redes, volúmenes, Compose |
| 3 | Mié 25/11 | M3 Construcción de imágenes |
| 4 | Jue 26/11 | M4 Introducción a Kubernetes |
| 5 | Vie 27/11 | M5 Despliegue de aplicaciones |
| 6 | Lun 30/11 | M6 Administración (I) |
| 7 | Mar 01/12 | M6 Administración (II) · Proyecto final |

<small>9:00 – 14:20 · descanso de 20 min hacia las 11:30</small>

---

## Cómo vamos a trabajar

<div class="cols">
<div>

- **30 % teoría, 70 % práctica**
- Demos en directo (y alguna fallará: también se aprende)
- Laboratorios guiados en `labs/`
- Una misma app de ejemplo durante todo el curso: **contador**

</div>
<div>

<div class="box">

**Normas de la casa**

- Pregunta en cualquier momento
- Cámara opcional, chat siempre abierto
- Si te atascas en un lab, avisa en el chat
- No hay preguntas tontas, solo YAML mal indentado

</div>

</div>
</div>

---

## Material del curso

- **Presentación:** esta misma web (reveal.js), servida desde… ¡un contenedor en Kubernetes!
- **Laboratorios:** `labs/lab-NN-*.md` paso a paso
- **App de ejemplo:** `examples/contador` (Python + Redis)
- **PDF** de la presentación al terminar el curso

```bash
# Al final del curso desplegaremos esto mismo:
kubectl -n curso-kolbit get pods
```

---

<!-- .slide: class="lab" -->

## Lab 00 · Preparar el entorno

- Instalar **Docker** (o Podman), `kubectl` y `kind`
- Verificar que todo funciona
- Clonar el material del curso

```bash
docker run --rm hello-world
kubectl version --client
kind version
```

<small>⏱ 30 min · `labs/lab-00-entorno.md`</small>
