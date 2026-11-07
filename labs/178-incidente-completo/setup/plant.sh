#!/usr/bin/env bash
# Lab 178: incidente completo. Un cambio puso LOG_LEVEL=DEBUG en pedidos y no
# hay rotación de logs: el volumen de logs (32 MB) se llena, la app ya no
# puede escribir y nginx devuelve 502. El alumno restaura, previene, comunica
# y escribe el postmortem (sin culpables).
set -e
H=/home/analista
L=/var/log/pedidos
I=$H/incidente
mkdir -p $L $I /opt/pedidos

grep -q " $L " /proc/mounts || mount -t tmpfs -o size=32m,mode=0755 tmpfs $L
echo "tmpfs $L tmpfs size=32m,mode=0755 0 0" >> /etc/fstab

cat > /opt/pedidos/app.py <<'PY'
#!/usr/bin/env python3
"""pedidos: API interna detrás de nginx. Escribe su log en /var/log/pedidos/app.log."""
import json, os, time, uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

NIVEL = os.environ.get("LOG_LEVEL", "INFO").upper()
LOG = open("/var/log/pedidos/app.log", "a", buffering=1)


def log(nivel, msg, **extra):
    if nivel == "DEBUG" and NIVEL != "DEBUG":
        return
    LOG.write(json.dumps({"ts": time.strftime("%Y-%m-%dT%H:%M:%S"), "nivel": nivel, "msg": msg, **extra}) + "\n")


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        rid = str(uuid.uuid4())
        log("DEBUG", "petición recibida", id=rid, cabeceras=dict(self.headers), ruta=self.path,
            volcado="x" * 8000)
        body = json.dumps({"pedidos": 3, "id": rid}).encode()
        log("INFO", "GET " + self.path, id=rid, estado=200)
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a):
        pass


log("INFO", "arranque", nivel=NIVEL)
ThreadingHTTPServer(("127.0.0.1", 8081), H).serve_forever()
PY
cat > /etc/systemd/system/pedidos.service <<'U'
[Unit]
Description=API de pedidos
After=network.target
[Service]
ExecStart=/usr/bin/python3 /opt/pedidos/app.py
Environment=LOG_LEVEL=DEBUG
Restart=always
RestartSec=2
[Install]
WantedBy=multi-user.target
U
cat > /etc/nginx/sites-available/default <<'N'
server {
    listen 8080 default_server;
    location / { proxy_pass http://127.0.0.1:8081; proxy_read_timeout 5s; }
}
N
cat > /usr/local/bin/clientes <<'SH'
#!/usr/bin/env bash
while true; do curl -s -o /dev/null --max-time 5 http://127.0.0.1:8080/pedidos; sleep 0.1; done
SH
chmod 0755 /usr/local/bin/clientes
cat > /etc/systemd/system/clientes.service <<'U'
[Unit]
Description=Tráfico de clientes
[Service]
ExecStart=/usr/local/bin/clientes
Restart=always
[Install]
WantedBy=multi-user.target
U

# Logs "de días anteriores" (sin rotar ni comprimir).
python3 - <<'PY'
import json, random
for d in range(1, 4):
    with open(f"/var/log/pedidos/app.log.{d}", "w") as f:
        for i in range(3200):
            f.write(json.dumps({"ts": f"2026-11-0{6-d}T1{i%10}:00:00", "nivel": "INFO", "msg": "GET /pedidos",
                                "relleno": "y" * random.randint(2000, 3000)}) + "\n")
PY
systemctl daemon-reload
systemctl enable --now pedidos nginx clientes
echo "$(date '+%F %T') deploy pedidos v3.4.1 · cambio: LOG_LEVEL=DEBUG en pedidos.service (para depurar el bug PED-311) · autor: marta" \
  >> /var/log/despliegues.log

# Esperar a que el volumen se llene y la app empiece a fallar.
for _ in $(seq 1 240); do
  [ "$(df --output=pcent $L | tail -1 | tr -dc 0-9)" -ge 100 ] && break; sleep 1
done
sleep 5
FIRST=$(journalctl -u pedidos --no-pager -o short-iso 2>/dev/null | grep -m1 -E 'No space left|OSError' | awk '{print $1}')
[ -n "$FIRST" ] || FIRST=$(date -Iseconds)
echo "$FIRST" > /opt/lab/.primer_error; chmod 0600 /opt/lab/.primer_error
date '+%F %T' > /opt/lab/.alerta
cat > $I/alerta.txt <<A
[$(cat /opt/lab/.alerta)] ALERTA PagerDuty · tienda-web · tasa de 5xx > 50 % durante 5 min
Clientes: "no carga la lista de pedidos" (soporte, 3 tickets)
A
cat > $I/plantilla-postmortem.md <<'MD'
# Postmortem: <título>

## Resumen

## Impacto

## Línea de tiempo
<!-- hora (HH:MM) - qué pasó -->

## Causa raíz

## Qué funcionó y qué no

## Acciones
<!-- - [ ] acción · responsable · fecha -->
MD
chown -R analista:analista $I

cat > $H/TAREA.txt <<'TXT'
TAREA · Incidente completo (ver ~/incidente/alerta.txt)

Estás de guardia. Salta la alerta: la tienda devuelve 5xx.

1. Restaura el servicio (curl localhost:8080/pedidos debe dar 200), sin
   borrar a ciegas el log que la app tiene abierto.
2. Quita la causa: la app no debe seguir en DEBUG.
3. Que no vuelva a pasar: /etc/logrotate.d/pedidos que rote por tamaño,
   comprima, guarde un número limitado de copias y no rompa el fichero que
   la app tiene abierto.
4. Comunica: ~/incidente/comunicado.txt con al menos dos actualizaciones de
   estado con hora (p. ej. "HH:MM Investigando ..." y "HH:MM Resuelto ...").
5. Postmortem SIN CULPABLES en ~/incidente/postmortem.md (usa la plantilla):
   resumen, impacto, línea de tiempo con horas reales (despliegue, primer
   error, alerta, arreglo), causa raíz, qué funcionó y acciones con
   responsable y fecha.  Pistas de las horas: /var/log/despliegues.log,
   journalctl -u pedidos, ~/incidente/alerta.txt.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 178 plantado."
