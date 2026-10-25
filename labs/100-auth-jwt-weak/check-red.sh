#!/usr/bin/env bash
# RED: ¿capturaste la flag del panel admin? Pégala en ~/flag.txt.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
real=$(cat /opt/lab/.flag 2>/dev/null)
got=$(tr -d ' \t\r\n' < /home/analista/flag.txt 2>/dev/null || true)

echo "== Lab 100 · RED (captura) =="
if [ -z "$got" ]; then
  no "No hay flag en ~/flag.txt. Forja un token que /admin acepte y léela de ahí."
elif [ "$got" = "$real" ]; then
  ok "Flag correcta. Falsificaste un token con rol admin."
else
  no "La flag de ~/flag.txt no coincide."
fi
echo "Resultado RED: $pass ok, $fail pend."
[ "$fail" -eq 0 ]
