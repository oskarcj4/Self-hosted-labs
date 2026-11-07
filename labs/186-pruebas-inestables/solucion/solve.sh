#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cd ~/pedidos

# Inyectar el reloj y el generador aleatorio (parámetros opcionales: el
# código de producción sigue llamándolas igual).
python3 - <<'PY'
p = "pedidos.py"
s = open(p, encoding="utf-8").read()
s = s.replace('''def fecha_entrega():
    """Entrega en 2 días desde hoy. El almacén trabaja en UTC."""
    return (datetime.now(timezone.utc) + timedelta(days=2)).date()''',
'''def fecha_entrega(ahora=None):
    """Entrega en 2 días desde hoy. El almacén trabaja en UTC."""
    ahora = ahora or datetime.now(timezone.utc)
    return (ahora + timedelta(days=2)).date()''')
s = s.replace("def repartir(pedidos, repartidores):", "def repartir(pedidos, repartidores, rng=None):")
s = s.replace("    random.shuffle(orden)", "    (rng or random).shuffle(orden)")
open(p, "w", encoding="utf-8").write(s)
PY

cat > tests/test_pedidos.py <<'PY'
import random
from datetime import date, datetime, timezone

import pedidos


def test_total_con_iva():
    assert pedidos.total_con_iva([10, 20]) == 36.3


def test_fecha_entrega():
    # Reloj fijo, justo antes de medianoche UTC: el caso que antes fallaba.
    ahora = datetime(2026, 3, 9, 23, 30, tzinfo=timezone.utc)
    assert pedidos.fecha_entrega(ahora) == date(2026, 3, 11)


def test_repartir():
    lista = ["p1", "p2", "p3", "p4", "p5", "p6"]
    r = pedidos.repartir(lista, ["ana", "luis"], rng=random.Random(7))
    # Lo que la función SÍ garantiza: todos repartidos una vez y en partes iguales.
    assert sorted(r["ana"] + r["luis"]) == lista
    assert len(r["ana"]) == len(r["luis"]) == 3
    # Y con la misma semilla, el mismo resultado (reproducible).
    assert r == pedidos.repartir(lista, ["ana", "luis"], rng=random.Random(7))
PY

cat > tests/test_carrito.py <<'PY'
import pytest

import pedidos


@pytest.fixture(autouse=True)
def carrito_limpio(monkeypatch):
    # Cada test con su propio carrito: no importa en qué orden se ejecuten.
    monkeypatch.setattr(pedidos, "CARRITO", [])


def test_carrito_empieza_vacio():
    assert pedidos.CARRITO == []


def test_anadir():
    assert pedidos.anadir("taza") == 1
    assert pedidos.anadir("gorra") == 2
PY

cat > tests/test_servidor.py <<'PY'
import json, threading
from urllib.request import urlopen

import pytest

from servidor import crear_servidor


@pytest.fixture
def puerto():
    srv = crear_servidor(0)                # puerto 0: el SO elige uno libre
    # El socket ya escucha al volver crear_servidor: no hay carrera ni sleep.
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    yield srv.server_address[1]
    srv.shutdown()
    srv.server_close()


def test_salud(puerto):
    r = urlopen(f"http://127.0.0.1:{puerto}/salud", timeout=5)
    assert json.load(r)["estado"] == "ok"
PY
python3 -m pytest -q -p no:cacheprovider
echo "solve.sh completado."
