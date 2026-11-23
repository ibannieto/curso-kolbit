<!-- .slide: class="module center-v" -->

<span class="kicker">Día 7 · Proyecto final y cierre</span>

# De `docker run` a producción

<div class="agenda">

Proyecto final · Repaso · CaaS · Próximos pasos

</div>

---

<!-- .slide: class="lab" -->

## Lab 18 · Proyecto final

<div class="cols wide-left">
<div>

- Lo que estás viendo es un **contenedor**: reveal.js + nginx-unprivileged en el puerto 8080
- Imagen: `ghcr.io/ibannieto/curso-kolbit:<tag>`
- Manifiestos en `k8s/`: base de Kustomize + overlays `kind` y `hetzner`
- Namespace `curso-kolbit` · Deployment y Service `curso-kolbit` (80 → 8080)

</div>
<div>

```bash
make image          # podman/docker build
make run            # localhost:8080
make deploy         # kubectl apply -k
make k8s-status
```

</div>
</div>

<small>⏱ 90 min · `labs/lab-18-proyecto-final.md`</small>

---

## Todo lo que hay detrás de esta diapositiva

| Pieza | Dónde lo vimos |
| --- | --- |
| Imagen multi-stage, no root, versiones fijadas | M3 |
| Registro (GHCR) y tags inmutables | M2 |
| Deployment + Service + probes | M4 y M5 |
| requests/limits, PDB y antiafinidad | M6 |
| securityContext `restricted` | M6 |
| Kustomize con overlays por entorno | M5 |

```bash
kubectl -n curso-kolbit get deploy,pods,svc -o wide
```

---

## Repaso del curso

<div class="cols">
<div>

**Docker**

- Contenedor = proceso aislado (namespaces + cgroups)
- Imágenes OCI, registros, redes, volúmenes y Compose
- Dockerfile: multi-stage, caché, no root

</div>
<div>

**Kubernetes**

- Estado deseado + bucles de control
- Pods, Deployments, Services, ConfigMaps, Secrets, probes y HPA
- Recursos, scheduling, RBAC, cuotas y PV/PVC

</div>
</div>

---

<!-- .slide: class="meme" -->

<div class="meme-sticker"><b>There is no cloud</b><span>it's just someone else's computer</span></div>

<p class="meme-caption">Y en CaaS, el contenedor es tuyo… pero el resto es de otro.</p>

Note:
La pegatina clásica de la FSFE. Da pie a hablar de qué delegas al elegir un CaaS: operación del control plane, parches del SO, escalado de nodos… y qué sigue siendo responsabilidad tuya (la imagen, la configuración, los datos y la seguridad de tu app).

---

## CaaS, otra vez: ¿qué elijo?

| Necesito… | Opción |
| --- | --- |
| Una API o web sin estado, sin equipo de plataforma | **Serverless containers**: Cloud Run, Fargate, Azure Container Apps |
| Muchos servicios, estándar y portabilidad | **Kubernetes gestionado**: EKS, GKE, AKS |
| Control total, coste ajustado y un equipo que lo opere | **Autogestionado**: Talos/kubeadm en Hetzner u on-premise |
| Un par de contenedores en una VM | **Docker Compose** (sí, de verdad) |

<small>En todos los casos, el contrato es el mismo: una **imagen OCI** bien construida.</small>

---

## Próximos pasos

<div class="cols">
<div>

**Certificaciones (CNCF / Linux Foundation)**

- **KCNA**: fundamentos cloud native
- **CKAD**: desarrollo sobre Kubernetes
- **CKA**: administración
- **CKS**: seguridad (requiere la CKA)

</div>
<div>

**Recursos**

- kubernetes.io/docs y docs.docker.com
- landscape.cncf.io y killer.sh (simulador de examen)

</div>
</div>

<div class="box tip">

Practica con tu propio clúster kind: rómpelo, arréglalo y vuelve a empezar.

</div>

---

<!-- .slide: class="quiz" -->

## Día 7

1. ¿Qué objeto da a un Pod una identidad para hablar con la API? <span class="fragment answer">Un ServiceAccount</span>
2. Role frente a ClusterRole <span class="fragment answer">Role: dentro de un namespace · ClusterRole: todo el clúster o reutilizable con un RoleBinding</span>
3. Un PVC con `WaitForFirstConsumer` está en Pending. ¿Hay un error? <span class="fragment answer">No: el volumen se crea cuando un Pod lo usa, en la zona de su nodo</span>
4. Por defecto, ¿pueden hablar todos los Pods entre sí? <span class="fragment answer">Sí. Para restringirlo: NetworkPolicy, con un CNI que la aplique</span>

---

## Tu opinión cuenta

- **Encuesta de satisfacción**: 5 minutos, ahora mismo
- ¿Qué te ha sobrado? ¿Qué te ha faltado?
- Dudas pendientes: este es el momento

<div class="box">

Recibirás el **PDF de la presentación**, los laboratorios y la app de ejemplo.

</div>

---

<!-- .slide: class="center-v" -->

## ¡Gracias!

**Iban Nieto Castillero** · Que tus Pods estén siempre `Running` y tus despliegues siempre en verde.

<div class="center">

<img src="assets/img/phippy/group.svg" alt="Phippy and friends" style="width:100%; max-height:380px; object-fit:contain; background:#fff; border-radius:16px; padding:12px; box-sizing:border-box">

</div>

<small>Phippy and Friends · CNCF</small>
