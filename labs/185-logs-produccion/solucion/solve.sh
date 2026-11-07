#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cat > ~/tienda/app.py <<'PY'
"""Tienda: GET /productos, POST /login, POST /pagar, GET /error

Logs: una línea JSON por evento en stdout (el journal la recoge), con
request_id, línea de acceso por petición, trazas dentro de "exc", nivel con
LOG_LEVEL y datos sensibles enmascarados.
"""
import contextvars, json, logging, os, re, sys, time, traceback, uuid
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs

request_id = contextvars.ContextVar("request_id", default=None)

TARJETA = re.compile(r"\b(?:\d[ -]?){12,15}(\d{4})\b")
EMAIL = re.compile(r"\b([A-Za-z0-9])[A-Za-z0-9._%+-]*@([A-Za-z0-9.-]+\.[A-Za-z]{2,})\b")
BEARER = re.compile(r"(?i)\b(bearer|token|password|contraseña|secret)([=: ]+)\S+")


def enmascarar(texto):
    texto = TARJETA.sub(r"****\1", texto)
    texto = EMAIL.sub(r"\1***@\2", texto)
    return BEARER.sub(r"\1\2[REDACTADO]", texto)


class JSONFormatter(logging.Formatter):
    def format(self, r):
        o = {"ts": datetime.fromtimestamp(r.created, timezone.utc).isoformat(timespec="milliseconds"),
             "level": r.levelname, "logger": r.name, "msg": enmascarar(r.getMessage())}
        rid = request_id.get()
        if rid:
            o["request_id"] = rid
        for k, v in getattr(r, "campos", {}).items():
            o[k] = enmascarar(v) if isinstance(v, str) else v
        if r.exc_info:
            o["exc"] = enmascarar("".join(traceback.format_exception(*r.exc_info)))
        return json.dumps(o, ensure_ascii=False)


h = logging.StreamHandler(sys.stdout)
h.setFormatter(JSONFormatter())
logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO").upper(), handlers=[h], force=True)
log = logging.getLogger("tienda")
acceso = logging.getLogger("tienda.acceso")


class H(BaseHTTPRequestHandler):
    def _r(self, code, obj):
        b = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.send_header("X-Request-ID", request_id.get())
        self.end_headers()
        self.wfile.write(b)
        self._status = code

    def _form(self):
        n = int(self.headers.get("Content-Length") or 0)
        return {k: v[0] for k, v in parse_qs(self.rfile.read(n).decode()).items()}

    def _atender(self, fn):
        rid = self.headers.get("X-Request-ID") or uuid.uuid4().hex
        token = request_id.set(rid[:64])
        t0, self._status = time.perf_counter(), 500
        try:
            fn()
        finally:
            acceso.info("petición", extra={"campos": {
                "method": self.command, "path": self.path.split("?")[0], "status": self._status,
                "duration_ms": round((time.perf_counter() - t0) * 1000, 1)}})
            request_id.reset(token)

    def do_GET(self):
        self._atender(self._get)

    def do_POST(self):
        self._atender(self._post)

    def _get(self):
        log.debug("cabeceras recibidas", extra={"campos": {"cabeceras": sorted(self.headers.keys())}})
        if self.path == "/productos":
            return self._r(200, {"productos": ["taza", "gorra"]})
        if self.path == "/error":
            try:
                return self._r(200, {"media": sum([]) / len([])})
            except Exception:
                log.exception("error calculando la media")
                return self._r(500, {"error": "interno"})
        return self._r(404, {"error": "no existe"})

    def _post(self):
        f = self._form()
        if self.path == "/login":
            log.info("login", extra={"campos": {"usuario": f.get("email", "")}})
            return self._r(200, {"token": "t-" + str(int(time.time()))})
        if self.path == "/pagar":
            log.info("cobro", extra={"campos": {"importe": f.get("importe"), "tarjeta": f.get("tarjeta", "")}})
            return self._r(200, {"estado": "cobrado"})
        return self._r(404, {"error": "no existe"})

    def log_message(self, fmt, *a):
        pass                                   # el acceso ya lo registra _atender


if __name__ == "__main__":
    log.info("arrancando tienda", extra={"campos": {"puerto": 8080}})
    ThreadingHTTPServer(("127.0.0.1", int(os.environ.get("PUERTO", 8080))), H).serve_forever()
PY
sudo systemctl restart tienda
sleep 1
curl -s -H "X-Request-ID: demo-1" localhost:8080/productos; echo
curl -s localhost:8080/error; echo
sudo journalctl -u tienda -n 4 -o cat --no-pager
echo "solve.sh completado."
