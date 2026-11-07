#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
F=/etc/tienda/flags.json
A=/home/analista/tienda
cp -p $F /tmp/c190.flags

echo "== Lab 190 · Feature flags — comprobación =="

if ! systemctl is-active -q tienda || ! curl -sf --max-time 3 http://127.0.0.1:8080/ >/dev/null; then
  no "La tienda no responde en :8080 (journalctl -u tienda)."
  echo "Resultado: $pass superados, $((fail)) pendientes."; exit 1
fi
PID0=$(systemctl show tienda -p MainPID --value)

pon(){ printf '%s' "$1" > $F; chown analista:analista $F; sleep 6; }
# mide USUARIOS: imprime "nuevos errores lista-de-nuevos" para u-1..u-N
mide(){ python3 - "$1" <<'PY'
import json, sys, urllib.request
n, nuevos, err = int(sys.argv[1]), [], 0
for i in range(1, n + 1):
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:8080/checkout?usuario=u-{i}", timeout=3) as r:
            if json.load(r).get("checkout") == "nuevo":
                nuevos.append(i)
    except Exception:
        err += 1
print(len(nuevos), err, ",".join(map(str, nuevos)))
PY
}
uno(){ curl -s --max-time 3 "http://127.0.0.1:8080/checkout?usuario=$1" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("checkout"))' 2>/dev/null; }

pon '{"nuevo_checkout": {"activo": true, "porcentaje": 0, "usuarios": []}}'
read -r N0 E0 _ <<< "$(mide 200)"
pon '{"nuevo_checkout": {"activo": true, "porcentaje": 20, "usuarios": []}}'
read -r N20 E20 L20 <<< "$(mide 1000)"
read -r N20b _ L20b <<< "$(mide 1000)"
if [ "$N0" = 0 ] && [ "$N20" -ge 150 ] && [ "$N20" -le 250 ]; then
  ok "Porcentaje desde flags.json: 0 % → 0 usuarios, 20 % → $N20 de 1000."
else
  no "Con 0 % ven el nuevo $N0 de 200 y con 20 %, $N20 de 1000 (esperado 0 y ~200): ¿se lee flags.json?"
fi
if [ "$N20" -gt 0 ] && [ "$L20" = "$L20b" ]; then
  ok "Cada usuario ve siempre lo mismo (1000 usuarios, dos pasadas idénticas)."
else
  no "Los mismos 1000 usuarios dan resultados distintos en dos pasadas: no es estable (¿random?)."
fi

pon '{"nuevo_checkout": {"activo": true, "porcentaje": 50, "usuarios": []}}'
read -r N50 _ L50 <<< "$(mide 1000)"
PERDIDOS=$(python3 -c 'import sys;a=set(sys.argv[1].split(","))-{""};b=set(sys.argv[2].split(","));print(len(a-b))' "$L20" "$L50")
if [ "$N50" -ge 420 ] && [ "$N50" -le 580 ] && [ "$PERDIDOS" = 0 ]; then
  ok "Subir al 50 % ($N50 usuarios) mantiene a todos los que ya lo veían."
else
  no "Al 50 %: $N50 usuarios, y $PERDIDOS de los del 20 % dejan de verlo."
fi

pon '{"nuevo_checkout": {"activo": true, "porcentaje": 0, "usuarios": ["u-interna", "u-qa"]}}'
I1=$(uno u-interna); I2=$(uno u-qa); read -r NI _ _ <<< "$(mide 200)"
[ "$I1" = nuevo ] && [ "$I2" = nuevo ] && [ "$NI" = 0 ] \
  && ok "La lista de usuarios ve el nuevo aunque el porcentaje sea 0." \
  || no "Usuarios de la lista: u-interna=$I1, u-qa=$I2; resto con 0 %: $NI (esperado nuevo, nuevo, 0)."

pon '{"nuevo_checkout": {"activo": false, "porcentaje": 100, "usuarios": ["u-interna"]}}'
read -r NK _ _ <<< "$(mide 200)"; IK=$(uno u-interna)
[ "$NK" = 0 ] && [ "$IK" = clasico ] && ok "activo=false apaga el flag para todos (también la lista)." \
                                     || no "Con activo=false: $NK de 200 ven el nuevo y u-interna ve '$IK'."

pon '{"nuevo_checkout": {"activo": true, "porcentaje": 100, "usuarios": []}}'
read -r N100 _ _ <<< "$(mide 200)"
pon '{"nuevo_checkout": {"activo": tru'
read -r NR ER _ <<< "$(mide 200)"
[ "$N100" = 200 ] && [ "$NR" = 200 ] && [ "$ER" = 0 ] && ok "Con el fichero roto mantiene la última configuración buena, sin errores." \
                                 || no "Al 100 %: $N100 de 200; después, con flags.json roto: $NR de 200 con el nuevo (esperado 200) y $ER errores."

PID1=$(systemctl show tienda -p MainPID --value)
[ "$PID0" = "$PID1" ] && ok "Todos los cambios se aplicaron sin reiniciar el servicio (PID $PID1)." \
                      || no "El servicio se reinició durante la prueba (PID $PID0 → $PID1): los cambios deben aplicarse en caliente."

if grep -rqi 'navidad' $A /etc/systemd/system/tienda.service /etc/systemd/system/tienda.service.d 2>/dev/null \
   || grep -q 'NUEVO_CHECKOUT' /etc/systemd/system/tienda.service; then
  no "Quedan restos de los flags viejos (BANNER_NAVIDAD_2023 o NUEVO_CHECKOUT) en el código o en la unidad."
else
  ok "Flag muerto y variables de entorno viejas eliminados."
fi
cp -p /tmp/c190.flags $F

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Flags en caliente, estables por usuario y con interruptor de emergencia."; exit 0; } || exit 1
