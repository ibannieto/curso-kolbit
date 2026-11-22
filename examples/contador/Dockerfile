# syntax=docker/dockerfile:1
# Imagen de la app "contador" — versión final del Módulo 3 (multi-stage, no root)

FROM python:3.15.2-slim AS build
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

FROM python:3.15.2-slim
LABEL org.opencontainers.image.title="contador" \
      org.opencontainers.image.description="API de ejemplo del curso Docker & Kubernetes"
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
WORKDIR /app
COPY --from=build /install /usr/local
COPY app.py .
USER 10001:10001
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=2s --retries=3 \
  CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/healthz')"]
CMD ["python", "app.py"]
