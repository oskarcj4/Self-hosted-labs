#!/usr/bin/env bash
# Solución BLUE: quitar las dos reglas que dejan saltar el firewall.
# (La vía RED se deja al alumno.)
set -e
F=/srv/fw/rules.sh

python3 - <<'PY'
import pathlib, re
p = pathlib.Path("/srv/fw/rules.sh")
s = p.read_text()
# BUG #1: confiar en el puerto de origen 53.
s = re.sub(r'(?m)^.*--sport 53 -j ACCEPT.*\n', '', s)
# quita el comentario que la acompaña
s = s.replace('# "Para que vuelvan las respuestas DNS": confiar en el puerto de origen 53.\n', '')
# BUG #2: ACCEPT de depuración del 9002 (antes del DROP).
s = re.sub(r'(?m)^.*--dport 9002 -j ACCEPT.*\n', '', s)
s = s.replace('# Consola admin (9002): ACCEPT de depuración que quedó puesto, antes del DROP.\n',
              '# Consola admin (9002): bloqueada.\n')
p.write_text(s)
PY

chown analista:analista "$F"
sh "$F"
echo "Reglas corregidas y aplicadas."
