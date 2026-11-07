#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cat > ~/causas.txt <<'TXT'
pool: el camino de "pago rechazado" (HTTPError) hace return sin POOL.devolver(); tras 5 rechazos /pool marca en_uso=5 y todo da 503.
cpu: tienda.service tiene CPUQuota=5%; cpu.stat muestra nr_throttled creciendo y calcular_total tarda 20x.
dns: /etc/resolv.conf pone primero 127.0.0.2, que no responde; cada resolución de pagos.interno espera 2 s de timeout.
TXT

# 1. Pool: devolver siempre la conexión (try/finally).
python3 - <<'PY'
import os
p = os.path.expanduser("~/tienda/app.py")
s = open(p, encoding="utf-8").read()
viejo = '''        try:
            urllib.request.urlopen(f"http://pagos.interno:8090/autorizar?tarjeta={tarjeta}", timeout=5)
        except urllib.error.HTTPError as e:
            return self._r(402, f"pago rechazado ({e.code})")
        total = calcular_total()
        POOL.devolver()
        return self._r(200, f"compra ok: {total}")
'''
nuevo = '''        try:
            try:
                urllib.request.urlopen(f"http://pagos.interno:8090/autorizar?tarjeta={tarjeta}", timeout=5)
            except urllib.error.HTTPError as e:
                return self._r(402, f"pago rechazado ({e.code})")
            total = calcular_total()
        finally:
            POOL.devolver()
        return self._r(200, f"compra ok: {total}")
'''
assert viejo in s
open(p, "w", encoding="utf-8").write(s.replace(viejo, nuevo))
PY

# 2. CPU: quitar la cuota.
sudo sed -i '/^# Límite puesto/d; /^CPUQuota=/d' /etc/systemd/system/tienda.service

# 3. DNS: quitar el servidor muerto.
sudo sed -i '/^nameserver 127\.0\.0\.2$/d' /etc/resolv.conf

sudo systemctl daemon-reload
sudo systemctl restart tienda
sleep 2
time getent hosts pagos.interno
curl -s -w ' %{http_code} %{time_total}s\n' 'localhost:8080/comprar'
echo "solve.sh completado."
