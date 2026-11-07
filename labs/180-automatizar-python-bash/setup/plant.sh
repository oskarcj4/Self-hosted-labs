#!/usr/bin/env bash
# Lab 180: dos scripts de operaciones "que funcionan en mi máquina". El alumno
# los convierte en herramientas fiables; el check los prueba con casos ocultos.
set -e
H=/home/analista
S=$H/scripts
mkdir -p $S $H/backups-ejemplo $H/logs-ejemplo /opt/lab/tests
install -m 0644 /opt/lab/setup/casos.py /opt/lab/tests/casos.py

cat > $S/rotar-backups.sh <<'SH'
#!/bin/bash
# Borra los backups viejos. Se lanza desde cron cada hora.
DIR=$1
cd $DIR
for f in $(ls -t | tail -n +8); do
  rm -rf $f
done
echo hecho
SH
cat > $S/informe_errores.py <<'PY'
# Informe de errores 5xx a partir de logs de nginx.
import sys

total = 0
errores = {}
for linea in open(sys.argv[1]):
    total += 1
    partes = linea.split()
    if partes[8].startswith("5"):
        errores[partes[6]] = errores.get(partes[6], 0) + 1
print({"total": total, "errores": errores})
PY
chmod 0755 $S/*

# Datos de ejemplo para probar a mano.
python3 - <<'PY'
import datetime, gzip, os, random
random.seed(180)
b = "/home/analista/backups-ejemplo"
d0 = datetime.date(2026, 9, 28)
for i in range(40):
    d = d0 + datetime.timedelta(days=i)
    p = f"{b}/db-{d}.tar.gz"
    open(p, "wb").write(b"x" * 64)
    t = random.randint(1_700_000_000, 1_790_000_000)      # mtime desordenada (copias restauradas)
    os.utime(p, (t, t))
open(f"{b}/db-2026-10-15 (copia).tar.gz", "wb").write(b"x")
open(f"{b}/LEEME.txt", "w").write("No borrar: política de backups en la wiki.\n")

rutas = ["/", "/productos", "/carrito", "/pagar", "/buscar"]
def linea(i):
    r = random.choice(rutas)
    q = f"?q={random.randint(1, 99)}" if r == "/buscar" else ""
    st = random.choice([200] * 17 + [404, 502, 500])
    return (f'10.0.0.{i % 250} - - [06/Nov/2026:10:{i % 60:02d}:00 +0000] "GET {r}{q} HTTP/1.1" {st} 512 '
            f'"-" "Mozilla/5.0 (X11; Linux x86_64)"\n')
l = "/home/analista/logs-ejemplo"
with open(f"{l}/access.log", "w") as f:
    f.writelines(linea(i) for i in range(400))
    f.write("línea corrupta por un reinicio\n")
with gzip.open(f"{l}/access.log.1.gz", "wt") as f:
    f.writelines(linea(i) for i in range(600))
PY
chown -R analista:analista $S $H/backups-ejemplo $H/logs-ejemplo

cat > $H/TAREA.txt <<'TXT'
TAREA · Automatizar con Bash y Python, pero bien

Dos scripts de ~/scripts se usan en producción y dan miedo. ¡No ejecutes
rotar-backups.sh tal cual: léelo primero!  Datos para probar: ~/backups-ejemplo
y ~/logs-ejemplo.

1. ~/scripts/rotar-backups.sh DIR [--dry-run]
   - Sin DIR, o si DIR no es un directorio: mensaje a stderr y código 2. No borra nada.
   - Sólo toca ficheros con nombre exacto db-AAAA-MM-DD.tar.gz. El resto, ni mirarlo.
   - Conserva los 7 más recientes (por la FECHA DEL NOMBRE, no por mtime) y
     todos los del día 01 de cada mes. Borra el resto.
   - Una línea por fichero: "borrado: NOMBRE" (o "borraría: NOMBRE" con --dry-run,
     que no borra nada).
   - Si otra ejecución tiene el cerrojo DIR/.rotar.lock (flock): código 3, sin tocar nada.
   - shellcheck sin avisos.
2. ~/scripts/informe_errores.py LOG [LOG...] [--umbral 0.05]
   - Lee logs de nginx (formato combined), también .gz.
   - Imprime JSON: {"total", "errores_5xx", "tasa", "top", "descartadas"}
       total: líneas válidas · tasa: errores_5xx/total redondeada a 4 decimales (0 si no hay)
       top: hasta 5 {"ruta", "n"} con más 5xx; ruta SIN query string;
            orden por n descendente y, si empatan, por ruta
       descartadas: líneas que no siguen el formato (también las vacías)
   - Código de salida 1 si tasa > umbral, 0 si no. Fichero inexistente: código 2.

El check prueba los dos scripts con datos que no has visto.
Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 180 plantado."
