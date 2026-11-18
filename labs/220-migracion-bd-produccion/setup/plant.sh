#!/usr/bin/env bash
# Lab 220: migración de PostgreSQL en plena producción, con tráfico real y 0 downtime.
# La tabla pedidos (3 M filas) tiene id integer y su secuencia está a ~1 000 000
# valores de 2^31: en unas horas los INSERT empiezan a fallar. Hay que pasar
# id a bigint SIN cortar el tráfico (lecturas, escrituras y updates continuos).
# Lo que rompe el tráfico (y el check detecta):
#  - ALTER COLUMN ... TYPE bigint: reescribe la tabla con ACCESS EXCLUSIVE (segundos bloqueado);
#  - un UPDATE de 3 M filas de golpe: bloquea las filas que la app actualiza;
#  - CREATE INDEX sin CONCURRENTLY: bloquea las escrituras;
#  - parar la app o la base de datos.
set -e
export HOME=/root
PGV=$(ls /usr/lib/postgresql/)
mkdir -p /var/log/trafico /home/analista/migracion

# Configuración de producción "normal": WAL holgado (sin checkpoints forzados a mitad de
# una operación grande) y compresión de WAL.
cat > /etc/postgresql/$PGV/main/conf.d/produccion.conf <<'CONF'
max_wal_size = 4GB
checkpoint_timeout = 15min
wal_compression = on
shared_buffers = 256MB
backend_flush_after = 256kB
CONF
systemctl enable postgresql && systemctl restart postgresql
until runuser -u postgres -- pg_isready -q; do sleep 1; done
P(){ runuser -u postgres -- psql -v ON_ERROR_STOP=1 -qAt "$@"; }

P -c "CREATE ROLE tienda LOGIN PASSWORD 'Tienda-220'"
P -c "CREATE DATABASE tienda OWNER tienda"
P -d tienda <<'SQL'
SET ROLE tienda;
CREATE TABLE pedidos (
  id        serial PRIMARY KEY,
  ref       text   NOT NULL,
  cliente   int    NOT NULL,
  total     numeric(10,2) NOT NULL,
  estado    text   NOT NULL DEFAULT 'nuevo',
  creado    timestamptz NOT NULL DEFAULT now()
);
-- histórico: 3 M pedidos; ref = 'h' || id (así se comprueba que nadie cambia los ids)
INSERT INTO pedidos (id, ref, cliente, total, estado, creado)
SELECT g, 'h' || g, ((g::bigint * 7919) % 50000)::int, ((g * 31) % 50000) / 100.0,
       (ARRAY['nuevo','pagado','enviado','entregado'])[1 + g % 4],
       now() - (3000000 - g) * interval '10 seconds'
FROM generate_series(1, 3000000) g;
CREATE INDEX pedidos_cliente_idx ON pedidos (cliente);
-- la secuencia, a 200 000 valores del máximo de integer
SELECT setval('pedidos_id_seq', 2147483647 - 1000000);
SQL
P -d tienda -c "VACUUM ANALYZE pedidos"
# Copia intacta para poder reiniciar el escenario (reiniciar-tienda).
P -c "CREATE DATABASE tienda_plantilla TEMPLATE tienda OWNER tienda"
P -c "ALTER DATABASE tienda_plantilla WITH ALLOW_CONNECTIONS false"
P -c "CHECKPOINT"

# El analista administra la base (como hace el DBA de guardia).
P -c "CREATE ROLE analista LOGIN SUPERUSER"
P -c "CREATE DATABASE analista OWNER analista"

# --- La aplicación: tráfico real contra la tabla --------------------------------------
cat > /usr/local/bin/trafico.py <<'PY'
#!/usr/bin/env python3
"""Tráfico real de la tienda contra PostgreSQL.
 - 3 hilos crean pedidos (INSERT ... RETURNING id) y apuntan la ref confirmada;
 - 3 hilos leen pedidos por id;  - 2 hilos actualizan el estado de pedidos al azar.
Como en producción, la app usa lock_timeout = 1 s: si una operación espera un
bloqueo más de 1 s, falla (LockNotAvailable) y el cliente ve un error. También
cuenta como error cualquier operación que tarde más de 10 s.
Cada segundo escribe en /var/log/trafico/segundos.log:
    <epoch> <ok> <errores> <latencia_max_ms> <inserts_ok>
Panel: http://127.0.0.1:9090/"""
import collections, http.server, os, random, threading, time, uuid
import psycopg2

DSN = "dbname=tienda user=tienda password=Tienda-220 host=127.0.0.1 connect_timeout=3 options='-c lock_timeout=1000'"
LIMITE = 10.0   # además, cualquier operación de más de 10 s es una caída
lock = threading.Lock()
c = collections.Counter(); lat = [0.0]; err_det = []
ultimo = collections.deque(maxlen=120)
conf = open("/var/log/trafico/confirmados.log", "a", buffering=1)

def conexion():
    while True:
        try:
            k = psycopg2.connect(DSN); k.autocommit = True
            return k
        except Exception:
            time.sleep(0.5)

def anota(t0, ok, tipo, det=""):
    d = time.time() - t0
    if d > LIMITE and ok:
        ok, det = False, f"{tipo} lenta {d:.1f}s"
    with lock:
        c["ok" if ok else "err"] += 1
        if ok and tipo == "insert": c["ins"] += 1
        lat[0] = max(lat[0], d)
        if not ok: err_det.append(det)

def hilo(tipo):
    k = conexion()
    while True:
        t0 = time.time()
        try:
            cur = k.cursor()
            if tipo == "insert":
                ref = "a" + uuid.uuid4().hex[:16]
                cur.execute("INSERT INTO pedidos (ref, cliente, total) VALUES (%s, %s, %s) RETURNING id",
                            (ref, random.randint(1, 50000), round(random.uniform(5, 300), 2)))
                cur.fetchone()
                conf.write(ref + "\n")
            elif tipo == "lectura":
                cur.execute("SELECT id, ref, total, estado FROM pedidos WHERE id = %s", (random.randint(1, 3000000),))
                cur.fetchall()
            else:
                cur.execute("UPDATE pedidos SET estado = %s WHERE id = %s",
                            (random.choice(["pagado", "enviado", "entregado"]), random.randint(1, 3000000)))
            cur.close()
            anota(t0, True, tipo)
        except Exception as e:
            anota(t0, False, tipo, f"{tipo} {type(e).__name__}: {str(e).strip().splitlines()[0][:90]}")
            try: k.close()
            except Exception: pass
            k = conexion()
        time.sleep(0.12 if tipo == "insert" else 0.03)

for tipo, n in (("insert", 3), ("lectura", 3), ("update", 2)):
    for _ in range(n):
        threading.Thread(target=hilo, args=(tipo,), daemon=True).start()

class Panel(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        with lock: filas = list(ultimo)
        cuerpo = "segundo      ok  errores  lat_max_ms  inserts\n" + "\n".join(
            f"{time.strftime('%H:%M:%S', time.localtime(t))}  {o:5}  {e:7}  {l:10}  {i:7}" for t, o, e, l, i in reversed(filas))
        b = ("<meta http-equiv=refresh content=1><pre>" + cuerpo + "</pre>").encode()
        self.send_response(200); self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def log_message(self, *a): pass
threading.Thread(target=http.server.ThreadingHTTPServer(("0.0.0.0", 9090), Panel).serve_forever, daemon=True).start()

while True:
    time.sleep(1 - time.time() % 1)
    with lock:
        ok, err, ins, l, es = c["ok"], c["err"], c["ins"], int(lat[0] * 1000), list(err_det)
        c.clear(); lat[0] = 0.0; err_det.clear()
        t = int(time.time()); ultimo.append((t, ok, err, l, ins))
    with open("/var/log/trafico/segundos.log", "a") as f:
        f.write(f"{t} {ok} {err} {l} {ins}\n")
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
awk -v d=$DESDE -v n=$N '$1>=d {ok+=$2; err+=$3; if ($4>m) m=$4; ins+=$5}
  END { printf "Últimos %d s: %d operaciones OK, %d con error · latencia máxima %d ms · %d pedidos nuevos\n", n, ok, err, m, ins }' /var/log/trafico/segundos.log
E=$(awk -v d=$DESDE '$1>=d' /var/log/trafico/errores.log 2>/dev/null | tail -5)
[ -n "$E" ] && printf 'Últimos errores:\n%s\n' "$E"
true
SH
chmod 755 /usr/local/bin/trafico
cat > /etc/systemd/system/trafico.service <<'U'
[Unit]
Description=Tráfico real de la tienda contra PostgreSQL
After=postgresql.service
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/trafico.py
Restart=always
[Install]
WantedBy=multi-user.target
U

# --- Volver a empezar (si un intento de migración sale mal) ----------------------------
cat > /usr/local/sbin/reiniciar-tienda <<'SH'
#!/usr/bin/env bash
# Restaura la base "tienda" al estado inicial y pone a cero los contadores de tráfico.
set -e
systemctl stop trafico
P(){ runuser -u postgres -- psql -v ON_ERROR_STOP=1 -qAt "$@"; }
P -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'tienda' AND pid <> pg_backend_pid()" >/dev/null
P -c "DROP DATABASE tienda"
P -c "ALTER DATABASE tienda_plantilla WITH ALLOW_CONNECTIONS true"
P -c "CREATE DATABASE tienda TEMPLATE tienda_plantilla OWNER tienda"
P -c "ALTER DATABASE tienda_plantilla WITH ALLOW_CONNECTIONS false"
: > /var/log/trafico/segundos.log; : > /var/log/trafico/errores.log; : > /var/log/trafico/confirmados.log
systemctl start trafico
echo "Base 'tienda' restaurada y contadores a cero."
SH
chmod 750 /usr/local/sbin/reiniciar-tienda
touch /var/log/trafico/segundos.log /var/log/trafico/errores.log /var/log/trafico/confirmados.log
systemctl daemon-reload && systemctl enable --now trafico

cat > /home/analista/migracion/LEEME.md <<'MD'
# migracion

Deja aquí tus scripts SQL / bash de la migración.

Conexión de administrador:   psql tienda          (eres superusuario)
La app conecta como:         tienda / Tienda-220 @ 127.0.0.1

Si un intento sale mal:      sudo reiniciar-tienda
(restaura la base al estado inicial y pone a cero los contadores de tráfico)
MD

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · URGENTE · Los pedidos van a dejar de entrar

pedidos.id es integer (máximo 2 147 483 647) y la secuencia ya va por
2 146 483 xxx. Al ritmo actual, en unas horas TODOS los INSERT fallarán con
"nextval: reached maximum value of sequence".

Hay que pasar pedidos.id a bigint. Pero la tienda está en producción y no se
puede parar: hay lecturas, escrituras y actualizaciones continuas.

  trafico 30                     resumen del tráfico real
  http://localhost:8220          panel en vivo (se refresca cada segundo)
  /var/log/trafico/errores.log

La app usa lock_timeout = 1 s: una operación que espera un bloqueo más de
1 s falla y el cliente ve un error (para él, la tienda se ha caído).

Requisitos:
  1. pedidos.id bigint, clave primaria, con su secuencia (también bigint) como default.
  2. Los ids existentes NO cambian y no se pierde ningún pedido confirmado.
  3. 0 errores de tráfico desde que empiezas (sudo reiniciar-tienda pone el contador a 0).
  4. El tráfico no se para en ningún momento.

Comprueba: bash /opt/lab/check.sh
TXT
chown -R analista:analista /home/analista/migracion /home/analista/TAREA.txt
# Calentamiento: el primer minuto de tráfico no cuenta (cachés frías tras la carga).
sleep 20; systemctl stop trafico; runuser -u postgres -- psql -qAt -c "CHECKPOINT"
: > /var/log/trafico/segundos.log; : > /var/log/trafico/errores.log
systemctl start trafico; sleep 4
echo "Lab 220 plantado (PostgreSQL $PGV)."; trafico 3
