#!/usr/bin/env bash
# Lab 186: una suite que "a veces falla". Cuatro causas clásicas: la hora,
# el orden, el azar sin semilla y una carrera con un puerto fijo.
set -e
P=/home/analista/pedidos
mkdir -p $P/tests /opt/lab/tests

cat > $P/pedidos.py <<'PY'
"""Lógica de pedidos de la tienda. No cambies las reglas de negocio:
sí puedes añadir parámetros opcionales para poder probarla."""
import random
from datetime import datetime, timedelta, timezone

IVA = 0.21
CARRITO = []


def total_con_iva(importes):
    return round(sum(importes) * (1 + IVA), 2)


def fecha_entrega():
    """Entrega en 2 días desde hoy. El almacén trabaja en UTC."""
    return (datetime.now(timezone.utc) + timedelta(days=2)).date()


def anadir(producto):
    CARRITO.append(producto)
    return len(CARRITO)


def repartir(pedidos, repartidores):
    """Reparte en turnos, en orden aleatorio para que nadie se lleve siempre los mismos."""
    orden = list(pedidos)
    random.shuffle(orden)
    reparto = {r: [] for r in repartidores}
    for i, p in enumerate(orden):
        reparto[repartidores[i % len(repartidores)]].append(p)
    return reparto
PY

cat > $P/servidor.py <<'PY'
"""Mini API de salud de la tienda."""
import json, random, time
from http.server import BaseHTTPRequestHandler, HTTPServer


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        b = json.dumps({"estado": "ok"}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def log_message(self, *a):
        pass


def crear_servidor(puerto):
    time.sleep(random.uniform(0, 0.12))       # carga el catálogo (tarda un poco, a veces más)
    return HTTPServer(("127.0.0.1", puerto), H)
PY

cat > $P/pytest.ini <<'INI'
[pytest]
testpaths = tests
pythonpath = .
INI

cat > $P/tests/test_pedidos.py <<'PY'
from datetime import date, timedelta

import pedidos


def test_total_con_iva():
    assert pedidos.total_con_iva([10, 20]) == 36.3


def test_fecha_entrega():
    assert pedidos.fecha_entrega() == date.today() + timedelta(days=2)


def test_repartir():
    r = pedidos.repartir(["p1", "p2", "p3", "p4", "p5", "p6"], ["ana", "luis"])
    # los urgentes (p1-p3) nunca deben ir todos al mismo repartidor
    assert sorted(r["ana"]) != ["p1", "p2", "p3"]
    assert sorted(r["luis"]) != ["p1", "p2", "p3"]
PY

cat > $P/tests/test_carrito.py <<'PY'
import pedidos


def test_carrito_empieza_vacio():
    assert pedidos.CARRITO == []


def test_anadir():
    assert pedidos.anadir("taza") == 1
    assert pedidos.anadir("gorra") == 2
PY

cat > $P/tests/test_servidor.py <<'PY'
import json, threading, time
from urllib.request import urlopen

from servidor import crear_servidor


def test_salud():
    def servir():
        crear_servidor(8765).serve_forever()
    threading.Thread(target=servir, daemon=True).start()
    time.sleep(0.1)                              # que le dé tiempo a arrancar
    r = urlopen("http://127.0.0.1:8765/salud", timeout=5)
    assert json.load(r)["estado"] == "ok"
PY
chown -R analista:analista $P

# Plugin del check: baraja el orden y fija la semilla de random antes de cada test.
cat > /opt/lab/tests/barajar.py <<'PY'
import os, random


def pytest_collection_modifyitems(session, config, items):
    b = os.environ.get("BARAJAR")
    if b == "inverso":
        items.reverse()
    elif b:
        random.Random(int(b)).shuffle(items)


def pytest_runtest_setup(item):
    s = os.environ.get("SEMILLA")
    if s:
        random.seed(int(s))
PY
cat > /opt/lab/tests/junit.py <<'PY'
"""Lee un junit.xml: imprime 'ok' o los tests que fallan / faltan / se saltan."""
import sys, xml.etree.ElementTree as ET
try:
    raiz = ET.parse(sys.argv[1]).getroot()
except Exception:
    print("la suite no llegó a ejecutarse"); sys.exit()
bien, mal = set(), set()
for tc in raiz.iter("testcase"):
    n = tc.get("name", "").split("[")[0]
    (mal if any(c.tag in ("failure", "error", "skipped") for c in tc) else bien).add(n)
falta = set(sys.argv[2].split()) - bien - mal
r = []
if mal:
    r.append("fallan/saltados: " + ", ".join(sorted(mal)))
if falta:
    r.append("no existen: " + ", ".join(sorted(falta)))
print("; ".join(r) or "ok")
PY
chmod 644 /opt/lab/tests/*.py

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Tests inestables

La suite de ~/pedidos "a veces falla" en CI y la gente ya le da a
"re-run" sin mirar. Hazla DETERMINISTA:

  cd ~/pedidos && python3 -m pytest -q          # prueba a lanzarla varias veces

1. Que pase SIEMPRE: en cualquier orden, con cualquier semilla, a cualquier
   hora y zona horaria, y aunque el puerto 8765 esté ocupado.
2. Sin trampas: nada de reintentos (reruns/flaky/retry), skip ni xfail, y
   no se borran ni renombran tests: test_total_con_iva, test_fecha_entrega,
   test_repartir, test_carrito_empieza_vacio, test_anadir, test_salud.
3. Los tests tienen que seguir detectando bugs reales: el check mete
   errores en pedidos.py y servidor.py y la suite debe fallar.
4. No cambies las reglas de negocio. Sí puedes añadir parámetros opcionales
   (inyectar el reloj, el generador aleatorio...).

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 186 plantado."
