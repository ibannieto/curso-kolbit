"""
contador — API mínima para el curso Docker & Kubernetes.

Endpoints:
  GET /         → incrementa y devuelve el contador de visitas (guardado en Redis)
  GET /healthz  → liveness: el proceso está vivo
  GET /readyz   → readiness: Redis responde
  GET /load     → quema CPU unos segundos (para probar el HPA)
  GET /info     → configuración visible (ConfigMap/Secret) y hostname del Pod

Configuración (variables de entorno):
  PORT (8080) · REDIS_HOST (redis) · REDIS_PORT (6379) · REDIS_PASSWORD
  APP_MESSAGE · APP_COLOR · LOAD_SECONDS (2) · FAIL_ON_START (vacío)
"""

import json
import math
import os
import signal
import socket
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import redis

PORT = int(os.getenv("PORT", "8080"))
APP_MESSAGE = os.getenv("APP_MESSAGE", "¡Hola desde un contenedor!")
APP_COLOR = os.getenv("APP_COLOR", "blue")
LOAD_SECONDS = float(os.getenv("LOAD_SECONDS", "2"))
HOSTNAME = socket.gethostname()

if os.getenv("FAIL_ON_START"):
    # Usado en el laboratorio de troubleshooting (CrashLoopBackOff)
    print(f"FATAL: FAIL_ON_START={os.getenv('FAIL_ON_START')}", file=sys.stderr, flush=True)
    sys.exit(1)

db = redis.Redis(
    host=os.getenv("REDIS_HOST", "redis"),
    port=int(os.getenv("REDIS_PORT", "6379")),
    password=os.getenv("REDIS_PASSWORD") or None,
    socket_connect_timeout=1,
    socket_timeout=1,
)


class Handler(BaseHTTPRequestHandler):
    server_version = "contador/1.0"

    def _send(self, code: int, payload: dict) -> None:
        body = (json.dumps(payload, ensure_ascii=False) + "\n").encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        match self.path:
            case "/":
                try:
                    visits = db.incr("visits")
                except redis.RedisError as exc:
                    return self._send(503, {"error": f"redis no disponible: {exc}", "host": HOSTNAME})
                self._send(200, {"visits": visits, "message": APP_MESSAGE, "color": APP_COLOR, "host": HOSTNAME})
            case "/healthz":
                self._send(200, {"status": "ok"})
            case "/readyz":
                try:
                    db.ping()
                    self._send(200, {"status": "ready"})
                except redis.RedisError as exc:
                    self._send(503, {"status": "not-ready", "error": str(exc)})
            case "/load":
                end = time.monotonic() + LOAD_SECONDS
                n = 0
                while time.monotonic() < end:
                    n += 1
                    math.sqrt(n)
                self._send(200, {"iterations": n, "host": HOSTNAME})
            case "/info":
                self._send(
                    200,
                    {
                        "host": HOSTNAME,
                        "message": APP_MESSAGE,
                        "color": APP_COLOR,
                        "redis_password_set": bool(os.getenv("REDIS_PASSWORD")),
                        "python": sys.version.split()[0],
                    },
                )
            case _:
                self._send(404, {"error": "not found"})

    def log_message(self, fmt: str, *args) -> None:
        # Logs a stdout en una línea: lo que espera `docker logs` / `kubectl logs`
        print(f'{self.address_string()} "{self.requestline}" {args[1] if len(args) > 1 else ""}', flush=True)


def _graceful_exit(signum, _frame) -> None:
    # Como PID 1 en un contenedor, un proceso sin manejador IGNORA SIGTERM:
    # `docker stop` / Kubernetes esperarían el timeout y harían SIGKILL.
    print(f"recibida señal {signal.Signals(signum).name}, saliendo", flush=True)
    sys.exit(0)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, _graceful_exit)
    signal.signal(signal.SIGINT, _graceful_exit)
    print(f"contador escuchando en :{PORT} (host={HOSTNAME})", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
