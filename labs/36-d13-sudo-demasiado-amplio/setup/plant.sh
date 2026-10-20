#!/usr/bin/env bash
# Lab 36 (Día 13): el usuario "deploy" sólo necesita rotar logs, pero tiene
# sudo total (regla "temporal" + grupo sudo) y además puede reescribir el
# script que ejecuta como root.
set -e
id deploy >/dev/null 2>&1 || useradd -m -s /bin/bash deploy
usermod -aG sudo deploy
passwd -l deploy >/dev/null

install -d -m 0755 /var/log/app
for f in web api worker; do
  for i in $(seq 1 30); do echo "$(date -d "-$i min" '+%F %T') $f INFO request $i"; done > /var/log/app/$f.log
done

cat > /usr/local/sbin/rotate-app-logs <<'EOF'
#!/bin/bash
# Rota los logs de la app. Lo lanza el pipeline de despliegue como:
#   sudo /usr/local/sbin/rotate-app-logs
set -e
D=/var/log/app
n=0
for f in "$D"/*.log; do
  [ -s "$f" ] || continue
  cp -p "$f" "$f.$(date +%Y%m%d%H%M%S)"
  : > "$f"
  n=$((n+1))
done
find "$D" -name '*.log.*' -mtime +7 -delete
echo "rotados: $n"
EOF
chown deploy:deploy /usr/local/sbin/rotate-app-logs
chmod 0775 /usr/local/sbin/rotate-app-logs

cat > /etc/sudoers.d/40-deploy-temp <<'EOF'
# TEMPORAL (incidente INC-2291): el pipeline fallaba al rotar logs.
# Quitar cuando se arregle.  -- ops, hace 14 meses
deploy ALL=(ALL) NOPASSWD: ALL
EOF
chmod 0440 /etc/sudoers.d/40-deploy-temp
visudo -c >/dev/null
echo "Lab 36 plantado."
