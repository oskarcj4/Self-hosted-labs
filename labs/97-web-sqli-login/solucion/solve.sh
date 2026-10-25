#!/usr/bin/env bash
# Solución BLUE: consulta parametrizada. (La vía RED se deja al alumno.)
set -e
A=/srv/app
python3 - <<'PY'
import re, pathlib
p = pathlib.Path("/srv/app/app.py")
s = p.read_text()
vuln = ('''    q = ("SELECT username, role, flag FROM users "
         "WHERE username = '%s' AND password = '%s'" % (user, password))
    try:
        rows = cur.execute(q).fetchall()''')
fix = ('''    q = ("SELECT username, role, flag FROM users "
         "WHERE username = ? AND password = ?")
    try:
        rows = cur.execute(q, (user, password)).fetchall()''')
assert vuln in s, "no encontre el bloque vulnerable (¿ya editado?)"
p.write_text(s.replace(vuln, fix))
PY
chown analista:analista "$A/app.py"
touch "$A/reload"
sleep 3
echo "Arreglo aplicado y app recargada."
