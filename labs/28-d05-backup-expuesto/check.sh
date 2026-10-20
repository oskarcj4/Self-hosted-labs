#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 28 (Día 05).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
IP=$(hostname -I | awk '{print $1}')
B="http://$IP"
W=/var/www/shop

echo "== Lab 28 · Día 05 — comprobación =="

for u in /backup-2026-10-01.tar.gz /assets/.cache/site-old.tgz; do
  c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$B$u")
  if [ "$c" = "200" ]; then no "$u todavía se descarga desde la web."; else ok "$u ya no es descargable ($c)."; fi
done

# Ningún archivo de backup (por extensión o por contenido) dentro del web root
SHA=$($SUDO cat /root/.tclab-backup.sha 2>/dev/null)
leftover=$($SUDO find "$W" -type f \( -iname '*.tar' -o -iname '*.tar.gz' -o -iname '*.tgz' \
            -o -iname '*.sql' -o -iname '*.sql.gz' -o -iname '*.bak' -o -iname '*.old' \
            -o -iname '*backup*' \) 2>/dev/null)
if [ -n "$SHA" ]; then
  while IFS= read -r f; do
    [ "$($SUDO sha256sum "$f" | cut -d' ' -f1)" = "$SHA" ] && leftover="$leftover"$'\n'"$f"
  done < <($SUDO find "$W" -type f 2>/dev/null)
fi
leftover=$(echo "$leftover" | grep . | sort -u)
if [ -z "$leftover" ]; then
  ok "No queda ningún backup dentro del web root (ni renombrado)."
else
  no "Quedan backups dentro de $W: $(echo $leftover)"
fi

okweb=1
for f in / /css/style.css /img/logo.svg /downloads/press-kit.zip; do
  c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$B$f")
  [ "$c" = "200" ] || { okweb=0; no "$f debería seguir respondiendo 200 (responde $c)."; }
done
[ "$okweb" -eq 1 ] && ok "La web y el kit de prensa (.zip legítimo) siguen publicados."

if $SUDO nginx -t >/dev/null 2>&1 && systemctl is-active --quiet nginx; then
  ok "nginx válido y activo."
else
  no "nginx -t falla o nginx no está activo."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Backup expuesto retirado sin romper la web. ¡Día 05 resuelto!"; exit 0; } || exit 1
