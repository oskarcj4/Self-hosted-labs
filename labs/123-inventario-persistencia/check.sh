#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 123.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"

echo "== Lab 123 · Inventario de persistencia — comprobación =="
I=/home/analista/iocs.txt
miss=""
for k in systemd-netlinkd www-data apt-compat-check .bashrc authorized_keys cdn-update.example.net ssh-keys.example.net; do
  grep -qF "$k" $I 2>/dev/null || miss="$miss $k"
done
[ -z "$miss" ] && ok "iocs.txt documenta los 5 puntos y los 2 dominios." || no "A ~/iocs.txt le falta:$miss"

if systemctl is-active -q systemd-netlinkd 2>/dev/null || [ -e /etc/systemd/system/systemd-netlinkd.service ] || [ -e /usr/lib/systemd/systemd-netlinkd ]; then
  no "Persistencia 1 (servicio systemd-netlinkd): sigue activa o en disco."
else ok "Servicio malicioso eliminado (unidad y binario)."; fi
$SUDO crontab -l -u www-data 2>/dev/null | grep -q cdn-update && no "Persistencia 2: el crontab de www-data sigue." || ok "crontab de www-data limpio."
if [ -e /etc/cron.d/apt-compat-check ] || [ -e /var/lib/apt/.cache/update ]; then no "Persistencia 3: /etc/cron.d/apt-compat-check o su script siguen."; else ok "cron.d malicioso y su script eliminados."; fi
$SUDO grep -q 'base64 -d' /home/deploy/.bashrc && no "Persistencia 4: .bashrc de deploy aún decodifica y ejecuta base64." || ok ".bashrc de deploy limpio."
$SUDO grep -q 'backup@infra' /root/.ssh/authorized_keys && no "Persistencia 5: la llave backup@infra sigue en root." || ok "Llave intrusa retirada."

# Lo legítimo sigue.
$SUDO crontab -l -u root 2>/dev/null | grep -q backup-web.sh && ok "Backup de root intacto." || no "Borraste el crontab legítimo de root."
[ -e /etc/cron.d/nginx-check ] && ok "/etc/cron.d/nginx-check intacto." || no "Borraste /etc/cron.d/nginx-check (legítimo)."
$SUDO grep -q 'admin@empresa' /root/.ssh/authorized_keys && ok "Llave admin@empresa intacta." || no "Borraste la llave legítima admin@empresa."
for s in nginx cron ssh; do systemctl is-enabled -q $s || no "$s ya no está habilitado."; done
systemctl is-enabled -q nginx && systemctl is-enabled -q cron && systemctl is-enabled -q ssh && ok "nginx, cron y ssh siguen habilitados."
grep -q 'alias ls' /home/deploy/.bashrc && ok ".bashrc de deploy conserva su contenido normal." || no "Vaciaste el .bashrc de deploy: quita sólo la línea maliciosa."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Persistencia erradicada sin daños colaterales."; exit 0; } || exit 1
