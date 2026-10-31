#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 116.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"

echo "== Lab 116 · Auditoría de binarios SUID — comprobación =="
CUR=$($SUDO find / -xdev -perm -4000 -type f 2>/dev/null | sort)
REF=$($SUDO cat /opt/lab/.ref-suid)
EXTRA=$(comm -13 <(echo "$REF") <(echo "$CUR"))
MISSING=$(comm -23 <(echo "$REF") <(echo "$CUR"))
[ -z "$EXTRA" ] && ok "No hay SUID fuera de la referencia." || no "SUID que no están en la referencia: $(echo $EXTRA)"
[ -z "$MISSING" ] && ok "Los SUID legítimos siguen intactos (sudo, passwd, su...)." || no "Quitaste SUID legítimos: $(echo $MISSING)"
CAPS=$($SUDO getcap -r / 2>/dev/null | sort)
if [ "$CAPS" = "$($SUDO cat /opt/lab/.ref-caps)" ]; then ok "No hay capabilities de fichero nuevas."; else no "getcap -r / muestra capabilities que no estaban en la referencia."; fi
VIM=$(ls /usr/bin/vim.basic /usr/bin/vim.tiny 2>/dev/null | head -1)
[ -x "$VIM" ] && ok "El editor del sistema ($VIM) sigue instalado (se quita el bit, no el paquete)." || no "Borraste un binario de paquete: basta con chmod u-s."
[ -e /tmp/.cache/.dbus-helper ] && no "La copia escondida en /tmp sigue en disco (consérvala fuera de /tmp o bórrala)." || ok "Copia SUID de /tmp retirada."

I=/home/analista/auditoria/informe.txt
miss=""
for p in /tmp/.cache/.dbus-helper "$VIM" /usr/local/lib/.pyhelper; do grep -qF "$p" $I 2>/dev/null || miss="$miss $p"; done
[ -z "$miss" ] && ok "informe.txt documenta los tres hallazgos." || no "En ~/auditoria/informe.txt faltan:$miss"

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Privilegios de vuelta a la referencia."; exit 0; } || exit 1
