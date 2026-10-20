#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 30 (Día 07).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
U=/var/www/media/uploads

echo "== Lab 30 · Día 07 — comprobación =="

ww=$($SUDO find "$U" -perm -0002 2>/dev/null)
if [ -z "$ww" ]; then ok "Nada dentro de uploads/ es escribible por todos."
else no "Sigue habiendo rutas world-writable: $(echo $ww)"; fi

intruder=0
for d in "$U" "$U/avatars" "$U/docs"; do
  f="$d/.tclab-intruso-$$"
  if $SUDO runuser -u nobody -- touch "$f" 2>/dev/null; then intruder=1; $SUDO rm -f "$f"; fi
done
if [ "$intruder" -eq 0 ]; then ok "Un usuario ajeno (nobody) ya no puede crear ficheros en uploads/."
else no "Un usuario ajeno (nobody) todavía puede escribir en uploads/."; fi

app=1
for sub in "" avatars docs; do
  n="tclab-check-$$.txt"
  r=$(curl -s --max-time 3 -X POST --data-binary "check" "http://127.0.0.1:8300/upload?name=$n&dir=$sub")
  p="$U/${sub:+$sub/}$n"
  if echo "$r" | grep -q guardado && [ "$($SUDO stat -c %U "$p" 2>/dev/null)" = "www-data" ]; then
    $SUDO rm -f "$p"
  else
    app=0; no "La app no puede guardar en uploads/${sub} ($(echo "$r" | head -1))."
  fi
done
[ "$app" -eq 1 ] && ok "media-app sigue guardando subidas en uploads/, avatars/ y docs/."

if $SUDO test -s "$U/avatars/u1001.png" && $SUDO test -s "$U/docs/factura-0001.pdf"; then
  ok "Los ficheros ya subidos siguen ahí."
else
  no "Faltan ficheros que ya estaban subidos (no borres contenido de usuarios)."
fi

if systemctl is-active --quiet media-app && [ "$(systemctl show media-app -p User --value)" = "www-data" ]; then
  ok "media-app sigue activo como www-data (sin darle más privilegios)."
else
  no "media-app no está activo o ya no corre como www-data."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Uploads sin world-write y la app escribiendo. ¡Día 07 resuelto!"; exit 0; } || exit 1
