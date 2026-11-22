# Exportar la presentación a PDF

```bash
make pdf                # output/curso-kolbit.pdf
```

1. Si no está en marcha, se arranca el contenedor de la presentación
   (`make run`) en la red de podman `kolbit`.
2. [decktape](https://github.com/astefanutti/decktape) 3.17, que es Chromium
   headless en contenedor, recorre todas las diapositivas y genera un PDF con
   una página de 1280×720 por diapositiva.
3. Las notas del ponente (`Note:`) no se incluyen en el PDF.

## Para repartir a los alumnos

- Genera el PDF **al final del curso**, con la última versión de las
  diapositivas.
- Revisa antes las capturas con `make shots` (en `output/shots/*.png`) por si
  alguna diapositiva se desborda.
- `output/` está en `.gitignore`: el PDF no se versiona. Para publicarlo en
  GitHub, crea una release y adjunta el PDF:

```bash
gh release create v1.0 output/curso-kolbit.pdf --title "Curso Docker & Kubernetes & CaaS" --notes "PDF del curso"
```

## Alternativa manual

Abre la presentación con `?print-pdf` (por ejemplo,
`http://localhost:8080/?print-pdf`) en Chrome y usa **Imprimir → Guardar como
PDF**, con márgenes «Ninguno» y la opción de gráficos de fondo activada.
