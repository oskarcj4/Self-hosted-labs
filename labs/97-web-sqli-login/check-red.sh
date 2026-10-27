#!/usr/bin/env bash
# RED: ¿capturaste la flag? Pégala en ~/flag.txt (o /home/analista/flag.txt).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
real=$(cat /opt/lab/.flag 2>/dev/null)
got=$(tr -d ' \t\r\n' < /home/analista/flag.txt 2>/dev/null || true)

echo "== Lab 97 · RED (captura) =="
if [ -z "$got" ]; then
  no "No hay flag en ~/flag.txt. Explota el login y guarda ahí la flag (TCLAB{...})."
elif [ "$got" = "$real" ]; then
  ok "Flag correcta. Sacaste la fila de admin a través del login."
else
  no "La flag de ~/flag.txt no coincide. ¿La copiaste entera, con TCLAB{...}?"
fi
echo "Resultado RED: $pass ok, $fail pend."
[ "$fail" -eq 0 ]
