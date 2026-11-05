#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 146.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista
TOKEN=ALLSAFE-OK-7f3a

echo "== Lab 146 · El CD de origen no confiable — comprobación =="

# 1) Clave del proveedor importada en el llavero del alumno
if sudo -u analista gpg --list-keys 2>/dev/null | grep -qi 'Allsafe Software Supply'; then
  ok "Clave pública del proveedor importada en el llavero."
else
  no "Importa la clave del proveedor: gpg --import /opt/entrega/vendor.pub"
fi

# 2) Veredicto
grep -qiE '^entregado_integro=no\s*$' $H/veredicto.txt 2>/dev/null \
  && ok "veredicto: la copia entregada NO es íntegra (sha256 no cuadra)." || no "veredicto.txt: entregado_integro debe ser 'no'."
grep -qiE '^firma_valida=no\s*$' $H/veredicto.txt 2>/dev/null \
  && ok "veredicto: la firma de la copia entregada NO es válida." || no "veredicto.txt: firma_valida debe ser 'no'."
WANT=$($SUDO sha256sum /srv/mirror/instalador.sh | cut -d' ' -f1)
grep -qE "^sha_correcto=$WANT\s*$" $H/veredicto.txt 2>/dev/null \
  && ok "veredicto: sha256 del instalador legítimo correcto." || no "veredicto.txt: sha_correcto no coincide con el del mirror."

# 3) La copia manipulada NO se ejecutó
[ -e /tmp/pwned ] && no "¡Se ejecutó la copia manipulada! (/tmp/pwned existe)." || ok "La copia manipulada no se ejecutó."

# 4) El instalador legítimo se ejecutó y dejó su marca
if [ -f $H/instalado/OK ] && grep -q "$TOKEN" $H/instalado/OK; then
  ok "El instalador legítimo se ejecutó (marca en ~/instalado/OK)."
else
  no "Falta ~/instalado/OK con el token del instalador legítimo."
fi

# 5) Se ejecutó dentro de la sandbox SIN red (prueba: no pudo contactar el beacon)
if grep -q 'contacto=sin-red' $H/salida-sandbox.txt 2>/dev/null; then
  ok "La ejecución fue aislada sin red (contacto=sin-red en la salida)."
elif grep -q 'contacto=ok' $H/salida-sandbox.txt 2>/dev/null; then
  no "Se ejecutó, pero CON red: faltó --unshare-net en la sandbox (contacto=ok)."
else
  no "~/salida-sandbox.txt debe contener la salida del instalador ejecutado en bubblewrap."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Origen verificado y ejecución contenida en sandbox."; exit 0; } || exit 1
