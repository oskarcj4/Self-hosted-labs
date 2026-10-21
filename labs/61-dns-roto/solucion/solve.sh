#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
printf 'nameserver 10.76.61.53\nsearch interno\noptions timeout:2 attempts:2\n' > /etc/resolv.conf
sed -i 's/^hosts:.*/hosts:          files dns/' /etc/nsswitch.conf
getent hosts pagos
