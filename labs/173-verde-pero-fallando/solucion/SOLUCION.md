# Solución — Verde, pero fallando

| Capa | Causa | Síntoma | Arreglo |
|------|-------|---------|---------|
| Sistema | `nameserver 127.0.0.2` muerto, primero en `/etc/resolv.conf` | +2 s por petición | quitar la línea |
| systemd | `CPUQuota=5%` en `tienda.service` | `nr_throttled` crece; CPU lenta | quitar la cuota (o un valor real) |
| App | `return` en el `except` antes de `POOL.devolver()` | `/pool` en_uso=5 y 503 | `try/finally` |

```python
try:
    try:
        urllib.request.urlopen(f"http://pagos.interno:8090/autorizar?tarjeta={tarjeta}", timeout=5)
    except urllib.error.HTTPError as e:
        return self._r(402, f"pago rechazado ({e.code})")
    total = calcular_total()
finally:
    POOL.devolver()
```

```bash
sudo sed -i '/^nameserver 127\.0\.0\.2$/d' /etc/resolv.conf
sudo sed -i '/^CPUQuota=/d' /etc/systemd/system/tienda.service
sudo systemctl daemon-reload && sudo systemctl restart tienda
```

## Por qué

- Las tres causas degradan, no rompen: ningún "¿está vivo?" las detecta.
- La fuga del pool es acumulativa: el servicio va bien tras reiniciar y empeora
  con el tiempo, lo que despista.
- El DNS lento se esconde porque la resolución "funciona", sólo que tarde.

## Más allá del lab

- Health de readiness que compruebe dependencias con timeout corto (lab 154).
- Sondas sintéticas: ejecutar `/comprar` cada minuto desde fuera y alertar por latencia.
- Usa context managers (`with pool.conexion():`) para que devolver la conexión no dependa de recordar hacerlo.
