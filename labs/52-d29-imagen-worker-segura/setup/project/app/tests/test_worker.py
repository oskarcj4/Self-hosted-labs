"""Pruebas del worker (usan la base de datos de staging, ver .env.debug)."""
import csv


def test_total():
    with open("data/pedidos.csv") as f:
        rows = list(csv.DictReader(f))
    assert round(sum(float(r["importe"]) for r in rows), 2) == 301.25
