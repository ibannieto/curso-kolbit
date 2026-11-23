# Convenciones de las diapositivas

Las diapositivas están en Markdown dentro de `slides/` y las renderiza el plugin
Markdown de reveal.js. El script `scripts/build.mjs` crea una `<section>` por
cada fichero `NN-nombre.md`, en orden alfabético.

## Estructura de un módulo

```markdown
<!-- .slide: class="module" -->

<span class="kicker">Módulo 2 · Día 1–2</span>

# Introducción a Docker

<div class="agenda">

Instalación · Contenedores · Imágenes · Redes · Volúmenes · Compose

</div>

---

## Título de la diapositiva

- Idea 1
- Idea 2

Note:
Notas del ponente (tecla S). No aparecen en el PDF.
```

- **Separador de diapositivas:** una línea con solo `---`, con una línea en
  blanco antes y otra después.
- **Notas del ponente:** todo lo que va después de una línea `Note:`.
- **Atributos de la diapositiva:** `<!-- .slide: class="..." -->` como primera
  línea de la diapositiva.
- **Atributos de un elemento:** `<!-- .element: class="fragment" -->` justo
  después del elemento.

## Clases disponibles (`slides/css/kolbit.css`)

| Clase | Uso |
| --- | --- |
| `module` (slide) | Portada de módulo, con `.kicker`, `h1` y `.agenda` |
| `docker` (slide) | Pone en azul Docker el borde del `h2`, para los módulos de Docker |
| `lab` (slide) | Diapositiva de laboratorio: añade el prefijo «LAB ·» al `h2` |
| `meme` (slide) | Diapositiva de meme (centrada) |
| `meme-term` | Terminal falso con `.bar` (título) y `<pre>`; colores `.red`, `.green`, `.yellow` |
| `meme-bubble` | Personaje oficial (Phippy & friends) con bocadillo `.bubble` |
| `meme-two` | Dos paneles (expectativa/realidad, lo que pido/lo que llega…) con `.tag` |
| `meme-stamp` | Sello circular («Works on my machine») |
| `meme-caption` | Pie grande de meme (`.top` para ponerlo arriba) |
| `meme-iceberg` | Iceberg por niveles: hijos `.sky`, `.l1`…`.l5` con `data-label` y un `<span>` |
| `meme-poll` | Encuesta: `.q` con la pregunta y una `<ol>` de opciones |
| `meme-sticker` | Pegatina: `<b>` con el texto grande y `<span>` con el pequeño |
| `quiz` (slide) | Quiz del día: lista numerada con la respuesta en `<span class="fragment answer">` |
| `svg.diagram` | Diagrama SVG en línea, con las clases `box` (`k8s`, `node`, `pod`, `off`), `arrow` (`dashed`), `title`, `sub`, `mono`, `edge` y `step`. Sin líneas en blanco dentro del `<svg>` |
| `center-v` (slide) | Centra el contenido en vertical |
| `cols`, `cols three`, `cols wide-left` | Columnas: hijos `<div>`, con una línea en blanco tras abrir el `<div>` para que se interprete el Markdown |
| `box`, `box tip`, `box warn`, `box danger` | Cajas destacadas |
| `logo-row` | Fila de logos |
| `small` | Texto secundario |
| `credit` | Créditos de una imagen, abajo a la derecha |
| `pre.big` / `pre.small` | Tamaño del bloque de código (en `<pre>`, se aplica con `<!-- .element: class="small" -->` tras el bloque) |

## Reglas de estilo

1. **Como máximo 6 viñetas por diapositiva**, y mejor si no pasan de unas 40
   palabras. El detalle va a las notas.
2. **Bloques de código de 14 líneas como máximo.** Indica siempre el lenguaje
   (`bash`, `yaml`, `dockerfile`, `python`, `console`). Para resaltar líneas
   paso a paso: ` ```yaml [1-3|5-8] `.
3. **Comandos reales y probados**, con las versiones de
   [`docs/versiones.md`](versiones.md).
4. **Imágenes con rutas relativas a la raíz:** `assets/img/...`. Solo se usan
   imágenes descargadas en el repositorio, sin URLs externas en tiempo de
   ejecución.
5. **Un meme cada 8–12 diapositivas** como mucho, siempre relacionado con lo
   que se está explicando. Los memes son **componentes HTML/CSS** (`meme-*`):
   un SVG cargado con `<img>` no puede usar las fuentes de la página. No se usan
   plantillas de memes con copyright (Drake, «This is fine»…); sí los personajes
   oficiales de la CNCF de `assets/img/phippy/`, los formatos clásicos de la
   comunidad recreados en HTML (iceberg, encuesta, pegatina) y los propios.
6. **Idioma:** español y tuteo. Los términos técnicos se dejan en inglés cuando
   es lo habitual (Pod, Deployment, rolling update…).
7. Cada bloque teórico termina con una **diapositiva de laboratorio**
   (`class="lab"`) que enlaza `labs/lab-NN-*.md` e indica la duración estimada.
8. Las diapositivas de notas, enlaces o referencias van al final de cada módulo.
