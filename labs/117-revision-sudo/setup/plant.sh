#!/usr/bin/env bash
# Lab 117: un sudo de madrugada que nadie reconoce y una regla NOPASSWD nueva.
# El origen: la regla de deploy permite "tee /etc/app/*" y el comodín de
# sudoers también casa con "/etc/app/../sudoers.d/...".
set -e
for u in deploy soporte monitor; do id $u >/dev/null 2>&1 || useradd -m -s /bin/bash $u; done
echo 'soporte:Soporte2024' | chpasswd
mkdir -p /etc/app && echo 'workers=4' > /etc/app/app.conf
cat > /etc/sudoers.d/10-deploy <<'S'
# Despliegues: reiniciar la app y escribir su configuración.
deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart app, /usr/bin/tee /etc/app/*
S
cat > /etc/sudoers.d/99-mantenimiento <<'S'
soporte ALL=(ALL) NOPASSWD: ALL
S
chmod 0440 /etc/sudoers.d/10-deploy /etc/sudoers.d/99-mantenimiento
touch -d '2024-03-02 10:00' /etc/sudoers.d/99-mantenimiento
visudo -c >/dev/null

D=$(date -d yesterday '+%b %e')
cat > /var/log/auth.log <<LOG
$D 09:14:02 app-117 sudo:   deploy : TTY=pts/0 ; PWD=/home/deploy ; USER=root ; COMMAND=/usr/bin/systemctl restart app
$D 09:14:02 app-117 sudo: pam_unix(sudo:session): session opened for user root(uid=0) by deploy(uid=1001)
$D 09:14:03 app-117 sudo: pam_unix(sudo:session): session closed for user root
$D 11:40:51 app-117 sudo:   deploy : TTY=pts/0 ; PWD=/home/deploy ; USER=root ; COMMAND=/usr/bin/tee /etc/app/app.conf
$D 11:40:52 app-117 sudo:   deploy : TTY=pts/0 ; PWD=/home/deploy ; USER=root ; COMMAND=/usr/bin/systemctl restart app
$D 16:02:13 app-117 sudo:  monitor : command not allowed ; TTY=pts/2 ; PWD=/home/monitor ; USER=root ; COMMAND=/usr/bin/journalctl -u app
$D 03:05:44 app-117 sshd[8121]: Accepted password for deploy from 198.51.100.23 port 50122 ssh2
$D 03:09:17 app-117 sudo:   deploy : TTY=pts/1 ; PWD=/home/deploy ; USER=root ; COMMAND=/usr/bin/tee /etc/app/../sudoers.d/99-mantenimiento
$D 03:11:02 app-117 sshd[8160]: Accepted password for soporte from 198.51.100.23 port 50140 ssh2
$D 03:12:40 app-117 sudo:  soporte : TTY=pts/2 ; PWD=/home/soporte ; USER=root ; COMMAND=/usr/bin/bash
$D 03:12:40 app-117 sudo: pam_unix(sudo:session): session opened for user root(uid=0) by soporte(uid=1002)
$D 03:31:09 app-117 sudo: pam_unix(sudo:session): session closed for user root
LOG
sort -k3,3 -s /var/log/auth.log -o /var/log/auth.log
chown root:adm /var/log/auth.log; chmod 0640 /var/log/auth.log
usermod -aG adm analista
systemctl enable --now rsyslog

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/INC-117.txt <<'TXT'
INC-117 · app-117
El SIEM marca un "sudo" de madrugada que nadie del equipo reconoce y una regla
NOPASSWD que no está en el repositorio de configuración. Averigua quién, qué
y CÓMO consiguió el permiso, cierra el agujero sin romper los despliegues de
deploy (reiniciar la app y editar /etc/app/app.conf) y documenta en ~/informe-sudo.txt.
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 117 plantado."
