#!/usr/bin/env bash
# Solución BLUE: sin shell + validación del host. (RED se deja al alumno.)
set -e
A=/srv/app
python3 - <<'PY'
import pathlib
p = pathlib.Path("/srv/app/app.py")
s = p.read_text()
vuln = '''def lookup(host):
    # --- VULNERABLE: host va a una shell sin validar ---
    cmd = "getent hosts " + host
    out = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=5)
    return out.stdout + out.stderr'''
fix = '''import re
_HOST = re.compile(r"^[A-Za-z0-9._-]{1,253}$")

def lookup(host):
    if not _HOST.match(host):
        return "host invalido\\n"
    # sin shell: host es un argumento, nunca codigo
    out = subprocess.run(["getent", "hosts", host],
                         capture_output=True, text=True, timeout=5)
    return out.stdout + out.stderr'''
assert vuln in s, "bloque vulnerable no encontrado"
p.write_text(s.replace(vuln, fix))
PY
chown analista:analista "$A/app.py"
touch "$A/reload"; sleep 3
echo "Arreglo aplicado y app recargada."
