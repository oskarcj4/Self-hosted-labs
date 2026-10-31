#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 117.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"

echo "== Lab 117 · Revisión de sudo — comprobación =="
$SUDO visudo -c >/dev/null 2>&1 && ok "visudo -c: configuración válida." || no "visudo -c falla."
SOP=$($SUDO sudo -l -U soporte 2>&1)
echo "$SOP" | grep -q 'not allowed' && ok "soporte ya no tiene ningún permiso de sudo." || no "soporte sigue pudiendo usar sudo."
$SUDO passwd -S soporte 2>/dev/null | awk '{print $2}' | grep -q '^L' && ok "Cuenta soporte bloqueada hasta aclararlo." || no "Bloquea la cuenta soporte (passwd -l / usermod -L)."
DEP=$($SUDO sudo -l -U deploy 2>&1)
echo "$DEP" | grep -q '/usr/bin/systemctl restart app' && ok "deploy sigue pudiendo reiniciar la app." || no "Rompiste el permiso de deploy para reiniciar la app."
if echo "$DEP" | grep -A20 'may run' | grep -q '\*'; then
  no "deploy aún tiene una regla con comodín (*): casa con rutas como /etc/app/../sudoers.d/x."
else
  ok "Sin comodines en las reglas de deploy."
fi
if echo "$DEP" | grep -qE 'tee /etc/app/app.conf|sudoedit /etc/app/app.conf'; then
  ok "deploy puede seguir editando /etc/app/app.conf (ruta exacta o sudoedit)."
else
  no "deploy perdió la forma de editar /etc/app/app.conf: dale la ruta exacta o sudoedit."
fi
I=/home/analista/informe-sudo.txt
miss=""
for k in soporte deploy '03:12' '/usr/bin/bash' 'tee' '99-mantenimiento' '198.51.100.23'; do grep -qF -- "$k" $I 2>/dev/null || miss="$miss $k"; done
[ -z "$miss" ] && ok "informe-sudo.txt reconstruye la cadena completa." || no "A ~/informe-sudo.txt le falta:$miss"

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 sudo revisado y agujero cerrado."; exit 0; } || exit 1
