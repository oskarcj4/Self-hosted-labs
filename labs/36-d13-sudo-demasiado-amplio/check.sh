#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 36 (Día 13).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
AS_DEPLOY="$SUDO runuser -u deploy --"
S=/usr/local/sbin/rotate-app-logs

echo "== Lab 36 · Día 13 — comprobación =="

if $SUDO visudo -c >/dev/null 2>&1; then ok "La configuración de sudo es válida (visudo -c)."
else no "visudo -c da errores: arregla la sintaxis antes de nada."; fi

if id -nG deploy | tr ' ' '\n' | grep -qxE 'sudo|admin|wheel|root'; then
  no "deploy sigue en un grupo con sudo total ($(id -nG deploy))."
else
  ok "deploy no pertenece a grupos administrativos."
fi

rules=$($SUDO sudo -l -U deploy 2>/dev/null | sed -n '/may run the following/,$p' | tail -n +2 | sed 's/^ *//' | grep -v '^$')
if [ -z "$rules" ]; then
  no "deploy no tiene ninguna regla de sudo (necesita poder rotar los logs)."
elif echo "$rules" | grep -qE '(:|\)) *ALL *$|/bin/(ba)?sh|/usr/bin/(ba)?sh|\*'; then
  no "deploy sigue teniendo reglas demasiado amplias: $(echo $rules)"
elif echo "$rules" | grep -vqF "$S"; then
  no "deploy tiene reglas además de la de rotar logs: $(echo $rules)"
else
  ok "deploy sólo puede ejecutar como root: $S"
fi

if $AS_DEPLOY sudo -n cat /etc/shadow >/dev/null 2>&1; then
  no "deploy todavía puede leer /etc/shadow con sudo."
else
  ok "deploy ya no puede usar sudo para otras cosas (cat /etc/shadow bloqueado)."
fi

out=$($AS_DEPLOY sudo -n "$S" 2>&1)
if echo "$out" | grep -q "^rotados:"; then ok "deploy puede rotar los logs sin contraseña ($out)."
else no "deploy no puede ejecutar 'sudo -n $S': ${out:-sin salida}"; fi

own=$(stat -c '%U' "$S"); mode=$(stat -c '%a' "$S")
if [ "$own" = "root" ] && [ $((8#$mode & 022)) -eq 0 ]; then
  ok "El script es de root y deploy no puede modificarlo ($mode)."
else
  no "El script es $own/$mode: si deploy puede editar lo que ejecuta como root, sigue siendo root."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 sudo de deploy reducido al mínimo. ¡Día 13 resuelto!"; exit 0; } || exit 1
