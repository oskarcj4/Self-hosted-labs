#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
printf '# deploy: sólo rotar logs de la app (pipeline, sin contraseña)\ndeploy ALL=(root) NOPASSWD: /usr/local/sbin/rotate-app-logs ""\n' \
  > /etc/sudoers.d/40-deploy.tmp
visudo -cf /etc/sudoers.d/40-deploy.tmp
install -m 0440 /etc/sudoers.d/40-deploy.tmp /etc/sudoers.d/40-deploy
rm -f /etc/sudoers.d/40-deploy.tmp /etc/sudoers.d/40-deploy-temp
gpasswd -d deploy sudo
chown root:root /usr/local/sbin/rotate-app-logs
chmod 0755 /usr/local/sbin/rotate-app-logs
visudo -c
