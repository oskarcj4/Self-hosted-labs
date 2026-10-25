#!/usr/bin/env bash
# RED: ¿capturaste la flag del servicio interno? Pégala en ~/flag.txt.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
real=$(cat /opt/lab/.flag 2>/dev/null)
got=$(tr -d ' \t\r\n' < /home/analista/flag.txt 2>/dev/null || true)

echo "== Lab 99 · RED (captura) =="
# El acceso directo al interno NO da la flag (le falta la cabecera del gateway).
dir=$(curl -s http://127.0.0.1:9000/flag)
grep -qi forbidden <<<"$dir" && ok "El metadata interno rechaza el acceso directo (sin SSRF no hay flag)." \
  || no "El interno respondió sin la cabecera del gateway (revisa el escenario)."
if [ -z "$got" ]; then
  no "No hay flag en ~/flag.txt. Abusa del fetcher para alcanzar el servicio interno."
elif [ "$got" = "$real" ]; then
  ok "Flag correcta. Usaste el gateway como proxy hacia el servicio interno (SSRF)."
else
  no "La flag de ~/flag.txt no coincide."
fi
echo "Resultado RED: $pass ok, $fail pend."
[ "$fail" -eq 0 ]
