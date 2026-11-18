#!/usr/bin/env bash
# Lab 219: rolling deploy con Ansible bajo tráfico real.
# Producción: HAProxy :8080 -> 3 instancias (web1..3, systemd web@, puertos 8001-8003).
# Un generador de tráfico (~100 peticiones/s) registra cada segundo cuántas fallan.
# Plantado: el playbook de despliegue
#  - actualiza las 3 instancias A LA VEZ (sin serial);
#  - reinicia sin sacar la instancia del balanceador y sin esperar al health check;
#  - si una release viene rota, la despliega igual en todas;
# y HAProxy no tiene health checks. La app tarda ~4 s en calentar (503 mientras tanto).
set -e
export HOME=/root

useradd -r -d /srv/web -s /usr/sbin/nologin web
mkdir -p /srv/web /etc/web /opt/releases /var/log/trafico

# --- Releases (v1 en producción; v2, v3 y una rota en el repositorio de artefactos) ---
mkrel() {  # mkrel VERSION ROTA(0/1)
  local d; d=$(mktemp -d)
  mkdir -p "$d/$1"
  echo "$1" > "$d/$1/VERSION"
  cat > "$d/$1/app.py" <<'PY'
#!/usr/bin/env python3
"""Web de la tienda. Calienta ~4 s (503 mientras tanto) y apaga con gracia en SIGTERM."""
import http.server, os, signal, threading, time

DIR = os.path.dirname(os.path.abspath(__file__))
VERSION = open(os.path.join(DIR, "VERSION")).read().strip()
ROTA = os.path.exists(os.path.join(DIR, "ROTA"))
PUERTO = int(os.environ.get("PUERTO", "8001"))
NOMBRE = os.environ.get("NOMBRE", "web")
LISTA = time.time() + 4  # "carga de caché" al arrancar

class H(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def responde(self, code, cuerpo):
        b = cuerpo.encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(b)))
        self.send_header("X-Version", VERSION)
        self.send_header("X-Instancia", NOMBRE)
        self.end_headers()
        self.wfile.write(b)
    def do_GET(self):
        calentando = time.time() < LISTA
        if self.path == "/version":
            return self.responde(200, VERSION)
        if self.path == "/salud":
            if ROTA:
                return self.responde(500, "error: no conecta con la caché")
            return self.responde(503 if calentando else 200, "calentando" if calentando else "ok")
        if calentando:
            return self.responde(503, "calentando")
        if ROTA:
            return self.responde(500, "error interno")
        time.sleep(0.01)
        self.responde(200, f"Tienda {VERSION} · {NOMBRE}\n")
    def log_message(self, *a):
        pass

class S(http.server.ThreadingHTTPServer):
    daemon_threads = True       # al apagar NO espera: lo que esté en curso se corta
    allow_reuse_address = True

srv = S(("127.0.0.1", PUERTO), H)
signal.signal(signal.SIGTERM, lambda *a: threading.Thread(target=srv.shutdown).start())
srv.serve_forever()
srv.server_close()
PY
  [ "$2" = 1 ] && touch "$d/$1/ROTA"
  tar -czf "/opt/releases/web-$1.tar.gz" -C "$d" "$1"
  rm -rf "$d"
}
mkrel v1 0; mkrel v2 0; mkrel v3 0; mkrel v4-rc 1
chmod 644 /opt/releases/*.tar.gz

cat > /etc/systemd/system/web@.service <<'U'
[Unit]
Description=Tienda, instancia %i
[Service]
User=web
EnvironmentFile=/etc/web/%i.env
WorkingDirectory=/srv/web/%i/current
ExecStart=/usr/bin/python3 /srv/web/%i/current/app.py
KillSignal=SIGTERM
TimeoutStopSec=10
Restart=on-failure
[Install]
WantedBy=multi-user.target
U
for i in 1 2 3; do
  printf 'PUERTO=800%s\nNOMBRE=web%s\n' $i $i > /etc/web/web$i.env
  mkdir -p /srv/web/web$i/releases
  tar -xzf /opt/releases/web-v1.tar.gz -C /srv/web/web$i/releases
  ln -sfn /srv/web/web$i/releases/v1 /srv/web/web$i/current
done
chown -R web:web /srv/web
systemctl daemon-reload
systemctl enable --now web@web1 web@web2 web@web3

# --- HAProxy sin health checks ----------------------------------------------------
cat > /etc/haproxy/haproxy.cfg <<'CFG'
global
    log /dev/log local0
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    daemon

defaults
    log     global
    mode    http
    option  httplog
    timeout connect 2s
    timeout client  10s
    timeout server  10s

frontend tienda
    bind :8080
    default_backend web

backend web
    balance roundrobin
    server web1 127.0.0.1:8001
    server web2 127.0.0.1:8002
    server web3 127.0.0.1:8003
CFG
systemctl enable haproxy && systemctl restart haproxy

# --- Tráfico real: ~100 peticiones/s, resumen por segundo ------------------------------
cat > /usr/local/bin/trafico.py <<'PY'
#!/usr/bin/env python3
"""Clientes simulados contra http://127.0.0.1:8080/.
Cada segundo escribe en /var/log/trafico/segundos.log:  <epoch> <ok> <errores> <versiones>
Los errores (códigos != 200 o sin respuesta) también van a /var/log/trafico/errores.log."""
import collections, http.client, threading, time

lock = threading.Lock()
cuenta = collections.Counter()
versiones = collections.Counter()
errores = []

def cliente():
    while True:
        try:
            c = http.client.HTTPConnection("127.0.0.1", 8080, timeout=3)
            c.request("GET", "/")
            r = c.getresponse(); r.read()
            ok, v, det = r.status == 200, r.getheader("X-Version", "?"), f"{r.status} {r.getheader('X-Instancia', '?')}"
            c.close()
        except Exception as e:
            ok, v, det = False, "?", type(e).__name__
        with lock:
            cuenta["ok" if ok else "err"] += 1
            if ok:
                versiones[v] += 1
            else:
                errores.append(det)
        time.sleep(0.05)

for _ in range(6):
    threading.Thread(target=cliente, daemon=True).start()
while True:
    time.sleep(1 - time.time() % 1)
    with lock:
        ok, err, vs, es = cuenta["ok"], cuenta["err"], dict(versiones), list(errores)
        cuenta.clear(); versiones.clear(); errores.clear()
    t = int(time.time())
    with open("/var/log/trafico/segundos.log", "a") as f:
        f.write(f"{t} {ok} {err} {','.join(f'{k}={n}' for k, n in sorted(vs.items())) or '-'}\n")
    if es:
        with open("/var/log/trafico/errores.log", "a") as f:
            for d, n in collections.Counter(es).items():
                f.write(f"{t} {n}x {d}\n")
PY
chmod 755 /usr/local/bin/trafico.py
cat > /usr/local/bin/trafico <<'SH'
#!/usr/bin/env bash
# trafico [segundos]  — resumen del tráfico real de los últimos N segundos (60 por defecto).
N=${1:-60}; DESDE=$(( $(date +%s) - N ))
awk -v d=$DESDE -v n=$N '$1>=d {ok+=$2; err+=$3; c=split($4, vs, ","); for (i=1; i<=c; i++) { split(vs[i], kv, "="); if (kv[2]) v[kv[1]]+=kv[2] } }
  END { printf "Últimos %d s: %d peticiones OK, %d con error\n", n, ok, err
        for (k in v) printf "  servidas por %s: %d\n", k, v[k] }' /var/log/trafico/segundos.log
E=$(awk -v d=$DESDE '$1>=d' /var/log/trafico/errores.log 2>/dev/null | tail -5)
[ -n "$E" ] && printf 'Últimos errores (epoch, cuántos, código e instancia):\n%s\n' "$E"
true
SH
chmod 755 /usr/local/bin/trafico
cat > /etc/systemd/system/trafico.service <<'U'
[Unit]
Description=Tráfico real de clientes contra la tienda
After=haproxy.service
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/trafico.py
Restart=always
[Install]
WantedBy=multi-user.target
U
for i in 1 2 3; do until curl -fs http://127.0.0.1:800$i/salud >/dev/null; do sleep 0.5; done; done
systemctl daemon-reload && systemctl enable --now trafico

# --- Ansible del equipo ------------------------------------------------------------
D=/home/analista/despliegue
mkdir -p $D
cat > $D/ansible.cfg <<'CFG'
[defaults]
inventory = inventario.ini
host_key_checking = False
retry_files_enabled = False
forks = 5
CFG
cat > $D/inventario.ini <<'INI'
# Los tres "servidores" web de producción. En este lab viven en la misma
# máquina (cada uno con su puerto, su carpeta y su servicio web@<nombre>).
[web]
web1 puerto=8001
web2 puerto=8002
web3 puerto=8003

[web:vars]
ansible_connection=local
ansible_python_interpreter=/usr/bin/python3
haproxy_socket=/run/haproxy/admin.sock
haproxy_backend=web
INI
cat > $D/deploy.yml <<'YML'
# Despliegue de la tienda.  Uso:  ansible-playbook deploy.yml -e version=v2
- name: Desplegar la tienda
  hosts: web
  become: true
  vars:
    version: v2
    base: "/srv/web/{{ inventory_hostname }}"

  tasks:
    - name: Descomprimir la release
      ansible.builtin.unarchive:
        src: "/opt/releases/web-{{ version }}.tar.gz"
        dest: "{{ base }}/releases/"
        remote_src: true
        owner: web
        group: web

    - name: Apuntar current a la nueva release
      ansible.builtin.file:
        src: "{{ base }}/releases/{{ version }}"
        dest: "{{ base }}/current"
        state: link
        force: true

    - name: Reiniciar la instancia
      ansible.builtin.systemd:
        name: "web@{{ inventory_hostname }}"
        state: restarted
YML
cat > $D/README.md <<'MD'
# despliegue

    ansible-playbook deploy.yml -e version=v2

Releases disponibles en /opt/releases/ (v2, v3 y v4-rc, que QA aún no ha probado).
HAProxy: /etc/haproxy/haproxy.cfg · API en caliente:
`echo "show servers state web" | sudo socat stdio /run/haproxy/admin.sock`
MD
chown -R analista:analista $D

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Desplegar sin que los clientes lo noten

La última vez que se desplegó la tienda (ansible-playbook deploy.yml) hubo
~10 segundos de errores 503 para TODOS los clientes, y el despliegue de una
release rota tumbó las tres instancias a la vez.

Ahora mismo hay tráfico real (unas 100 peticiones por segundo). Míralo:
    trafico 30          resumen de los últimos 30 s
    journalctl -u trafico, /var/log/trafico/

Arregla el despliegue (~/despliegue) para que:
  1. actualice las instancias DE UNA EN UNA;
  2. saque cada instancia de HAProxy antes de tocarla y la devuelva sólo
     cuando su /salud responda 200 con la versión nueva;
  3. si una release viene rota, se PARE en la primera instancia y los
     clientes no vean ni un error (prueba con -e version=v4-rc);
  4. HAProxy tenga health checks para no mandar tráfico a una instancia caída.

El check desplegará v4-rc (rota) y luego v3 con tu playbook, con el tráfico
en marcha, y contará los errores. Objetivo: 0.

Comprueba: bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
sleep 3
echo "Lab 219 plantado."; trafico 3
