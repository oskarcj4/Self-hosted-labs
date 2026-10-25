#!/usr/bin/env bash
# RED: ¿leíste la flag vía XXE? Pégala en ~/flag.txt.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
real=$(cat /opt/lab/.flag 2>/dev/null)
got=$(tr -d ' \t\r\n' < /home/analista/flag.txt 2>/dev/null || true)

echo "== Lab 101 · RED (captura) =="
if [ -z "$got" ]; then
  no "No hay flag en ~/flag.txt. Define una entidad externa a /srv/app/flag.txt y mándala en <name>."
elif [ "$got" = "$real" ]; then
  ok "Flag correcta. Leíste el fichero del servidor vía XXE."
else
  no "La flag de ~/flag.txt no coincide."
fi
echo "Resultado RED: $pass ok, $fail pend."
[ "$fail" -eq 0 ]
