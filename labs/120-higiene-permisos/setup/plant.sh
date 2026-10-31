#!/usr/bin/env bash
# Lab 120: permisos descuidados por todas partes. Llaves SSH legibles, .env
# legible por cualquiera, un script que corre como root y que cualquiera
# puede editar, y un umask 000 que fabrica más ficheros abiertos cada día.
set -e
id deploy >/dev/null 2>&1 || useradd -m -s /bin/bash deploy
id app >/dev/null 2>&1 || useradd -r -m -d /srv/app -s /usr/sbin/nologin app

# Llaves SSH de deploy.
install -d -o deploy -g deploy /home/deploy/.ssh
su - deploy -c 'ssh-keygen -q -t ed25519 -N "" -f ~/.ssh/id_ed25519 -C deploy@app-120'
cp /home/deploy/.ssh/id_ed25519.pub /home/deploy/.ssh/authorized_keys
chown deploy:deploy /home/deploy/.ssh/authorized_keys
chmod 0777 /home/deploy/.ssh
chmod 0644 /home/deploy/.ssh/id_ed25519
chmod 0666 /home/deploy/.ssh/authorized_keys

# Secretos de la app.
mkdir -p /srv/app
printf 'DB_PASSWORD=Tienda#Prod2024\nSTRIPE_KEY=sk_live_labtc0perm120\n' > /srv/app/.env
chown app:app /srv/app/.env; chmod 0644 /srv/app/.env
mkdir -p /etc/app && printf 'listen: 127.0.0.1:8000\nworkers: 4\n' > /etc/app/config.yml
chmod 0666 /etc/app/config.yml

# Script que cron ejecuta como root... y que cualquiera puede editar.
cat > /usr/local/bin/backup.sh <<'X'
#!/bin/bash
tar -czf /var/backups/app-$(date +%F).tgz /srv/app /etc/app 2>/dev/null
X
chmod 0777 /usr/local/bin/backup.sh
echo '30 2 * * * root /usr/local/bin/backup.sh' > /etc/cron.d/backup
mkdir -p /var/www/html/uploads && chmod 1777 /var/www/html/uploads   # dir con sticky: aceptable

# El umask que lo empeora todo.
echo 'umask 000' > /etc/profile.d/99-umask-compat.sh
echo 'umask 000   # "para que el equipo pueda editar"' >> /home/deploy/.profile
su - deploy -c 'echo "notas de despliegue" > ~/notas.txt'   # nace 666 por el umask

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/AUDIT-120.txt <<'TXT'
AUDIT-120 · app-120 · higiene de permisos
- Llaves SSH de deploy: privada y authorized_keys como deben estar.
- Ningún fichero escribible por cualquiera (world-writable) en el sistema.
- /srv/app/.env sólo para app.
- Corrige el umask para que no vuelva a pasar (deploy y global).
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 120 plantado."
