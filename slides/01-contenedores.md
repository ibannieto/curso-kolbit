<!-- .slide: class="module center-v" -->

<span class="kicker">Módulo 1 · Día 1</span>

# Introducción a los contenedores

<div class="agenda">

Qué es un contenedor · Contenedores vs. máquinas virtuales · Ecosistema · Docker y Kubernetes · CaaS

</div>

---

## El problema de siempre

<div class="cols">
<div>

- «En mi máquina funciona»
- Versiones distintas de librerías, runtime y SO
- Despliegues manuales y frágiles
- Entornos de dev, test y prod que no se parecen en nada
- Servidores «mascota» que nadie se atreve a tocar

</div>
<div class="center">

<div class="meme-stamp">Works on my machine<small>certified ✔</small></div>

</div>
</div>

Note:
Preguntar si alguien ha vivido un «en mi máquina funciona». Siempre hay alguien.

---

<!-- .slide: class="meme" -->

<div class="meme-two">
<div>
<span class="tag">Dev</span>

«En mi máquina funciona»

</div>
<div>
<span class="tag">Ops</span>

«Pues entonces desplegamos tu máquina»

</div>
</div>

<p class="meme-caption">…y así, más o menos, nacieron los contenedores.</p>

---

## ¿Qué es un contenedor?

> Un **proceso** (o grupo de procesos) **aislado** del resto del sistema, que se ejecuta con su propio sistema de ficheros, su red y sus límites de recursos, **compartiendo el kernel del host**.

- No es una máquina virtual ligera
- Es un proceso Linux con «gafas» que limitan lo que ve y lo que puede usar
- Se empaqueta con todas sus dependencias en una **imagen**

---

## Los ladrillos del kernel Linux

<div class="cols">
<div>

**Namespaces**: qué puede *ver*

- `pid`: árbol de procesos propio
- `net`: interfaces, IPs y puertos
- `mnt`: puntos de montaje
- `uts`: hostname
- `ipc`, `user`, `cgroup`, `time`

</div>
<div>

**cgroups v2**: qué puede *usar*

- CPU, memoria, I/O, PIDs
- Límites y contabilidad

**Otros**

- Capabilities, seccomp, AppArmor/SELinux
- OverlayFS: capas de la imagen

</div>
</div>

---

## Demostración: un contenedor «a mano»

```bash
# Un shell en nuevos namespaces de PID, montaje, hostname y red
sudo unshare --pid --fork --mount-proc --uts --net bash

hostname contenedor-casero
ps aux          # ¡solo vemos nuestros procesos!
ip addr         # solo loopback
```

<div class="box tip">

Docker, Podman y containerd automatizan esto, y añaden imágenes, redes, volúmenes y una API.

</div>

Note:
Demo en una VM Linux. Enseñar que ps solo muestra bash y ps, y que ip addr solo muestra lo. Salir con exit.

---

## Contenedores vs. máquinas virtuales

<div class="cols">
<div>

**Máquina virtual**

- Hipervisor y **SO invitado completo**
- Arranque en minutos
- GB de disco
- Aislamiento fuerte (hardware virtual)

</div>
<div>

**Contenedor**

- Comparte el **kernel del host**
- Arranque en milisegundos o segundos
- MB de disco
- Aislamiento a nivel de proceso

</div>
</div>

<div class="box warn">

No son excluyentes: en la nube, los contenedores casi siempre corren **dentro de VMs**.

</div>

---

## Comparativa

| | VM | Contenedor |
| --- | --- | --- |
| Unidad | SO completo | Proceso + dependencias |
| Arranque | Minutos | Milisegundos o segundos |
| Tamaño | GB | MB |
| Densidad por host | Decenas | Cientos |
| Aislamiento | Fuerte | Bueno (kernel compartido) |
| Portabilidad | Imagen de disco | Imagen OCI estándar |
| Kernel distinto del host | Sí | No* |

<small>* En Mac y Windows, Docker Desktop usa una VM Linux por debajo</small>

---

## Ventajas de los contenedores

- **Portabilidad**: la misma imagen en el portátil, en CI y en producción
- **Inmutabilidad**: no se parchea un contenedor, se reemplaza
- **Velocidad**: arranque rápido, escalado en segundos
- **Densidad**: más aplicaciones por servidor
- **Aislamiento de dependencias**: Python 3.10 y 3.15 en el mismo host, sin pelearse
- **Base del cloud native**: microservicios, CI/CD, GitOps…

---

## Breve historia

| Año | Hito |
| --- | --- |
| 1979 | `chroot` en Unix V7 |
| 2000–2008 | FreeBSD Jails, Solaris Zones, cgroups y LXC |
| **2013** | **Docker** lo hace fácil y popular |
| 2014 | Google publica **Kubernetes** (inspirado en Borg) |
| 2015 | Nacen la **OCI** y la **CNCF** |
| 2017 | containerd se dona a la CNCF |
| 2022 | Kubernetes 1.24 elimina dockershim |
| 2026 | Kubernetes 1.37 · Docker 29 · Ingress NGINX retirado → Gateway API |

---

## Estándares OCI: por qué todo es compatible

- **Image Spec**: formato de la imagen (capas + manifiesto + config)
- **Runtime Spec**: cómo ejecutar un contenedor (`runc`, `crun`, `youki`…)
- **Distribution Spec**: cómo subir y bajar imágenes de un registro

<div class="box tip">

Una imagen construida con Docker se ejecuta igual con Podman, containerd o CRI-O… y en Kubernetes.

</div>

---

## El ecosistema (simplificado)

<div class="cols three">
<div>

**Construir**

- Docker / BuildKit
- Podman / Buildah
- Kaniko, ko, Buildpacks

</div>
<div>

**Ejecutar**

- containerd, CRI-O
- runc, crun
- Docker Engine, Podman

</div>
<div>

**Orquestar y distribuir**

- Kubernetes
- Docker Hub, GHCR, Harbor, ECR…
- Helm, Kustomize, Flux, Argo CD

</div>
</div>

<div class="logo-row">
  <img src="assets/img/logos/cncf.svg" alt="CNCF" style="height:70px">
  <img src="assets/img/logos/containerd.svg" alt="containerd" style="height:70px">
</div>

---

## Docker en una diapositiva

<div class="cols wide-left">
<div>

- **Docker Engine** (`dockerd`) + CLI `docker`
- Por debajo: **containerd** → **runc**
- Construye imágenes (BuildKit), las ejecuta y las distribuye
- **Docker Desktop**: VM + Engine + UI para Mac y Windows
- Alternativa sin daemon: **Podman** (`alias docker=podman`)

</div>
<div class="center">

<img src="assets/img/logos/docker.svg" alt="Docker" style="height:260px">

</div>
</div>

---

## ¿Y cuando tengo 200 contenedores en 30 servidores?

- ¿En qué servidor arranco cada contenedor?
- ¿Quién lo reinicia si se cae, o si se cae el servidor?
- ¿Cómo escalo de 3 a 30 réplicas cuando entra tráfico?
- ¿Cómo actualizo sin cortar el servicio?
- ¿Cómo se descubren y se comunican entre sí?

<p class="fragment"><strong>→ Necesitas un orquestador.</strong></p>

---

## Kubernetes en una diapositiva

<div class="cols wide-left">
<div>

- Orquestador de contenedores **declarativo**: le dices *qué* quieres, no *cómo*
- Bucles de control que reconcilian el **estado deseado** con el **real**
- Autorreparación, escalado, rolling updates, service discovery
- Proyecto *graduated* de la CNCF, con 3 versiones al año (hoy, la **1.37**)

</div>
<div class="center">

<img src="assets/img/logos/kubernetes.svg" alt="Kubernetes" style="height:260px">

</div>
</div>

---

<!-- .slide: class="meme" -->

<div class="meme-bubble">
  <img src="assets/img/phippy/phippy.svg" alt="Phippy">
  <div class="bubble">
    «Kubernetes» viene del griego <em>timonel</em>.<br>
    Y «k8s» son 8 letras entre la k y la s.
    <small>Phippy, la app PHP que quería vivir en un contenedor · CNCF</small>
  </div>
</div>

Note:
Phippy and Friends es el material oficial de la CNCF para explicar Kubernetes a niños (y a managers): «The Illustrated Children's Guide to Kubernetes».

---

## Containers as a Service (CaaS)

<div class="cols">
<div>

- **IaaS**: tú gestionas VMs
- **CaaS**: tú gestionas **contenedores**; la plataforma, el resto
- **PaaS**: tú subes código
- **FaaS**: tú subes funciones

</div>
<div>

**Ejemplos de CaaS**

- Kubernetes gestionado: EKS, GKE, AKS, Hetzner + Talos…
- Serverless containers: Cloud Run, AWS Fargate, Azure Container Apps
- Más control ↔ menos operación

</div>
</div>

---

## ¿Quién gestiona qué?

| Capa | On-premise | IaaS | CaaS | PaaS | FaaS |
| --- | --- | --- | --- | --- | --- |
| Aplicación | Tú | Tú | Tú | Tú | Tú |
| Runtime / contenedor | Tú | Tú | **Tú** | Prov. | Prov. |
| Orquestación | Tú | Tú | Prov. | Prov. | Prov. |
| SO | Tú | Tú | Prov. | Prov. | Prov. |
| Hardware / red | Tú | Prov. | Prov. | Prov. | Prov. |

<small>CaaS: el contrato es la **imagen OCI**. Portable entre proveedores.</small>

---

## Resumen del módulo

- Contenedor = **proceso aislado** (namespaces + cgroups) que comparte el kernel
- Más ligero y rápido que una VM, aunque con un aislamiento distinto
- **OCI** hace que imágenes y runtimes sean intercambiables
- **Docker** para construir y ejecutar; **Kubernetes** para orquestar a escala
- **CaaS**: contenedores como unidad de despliegue en la nube

<div class="box tip">

Siguiente: manos a la obra con Docker.

</div>
