#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
H=/home/analista
cat /etc/resolv.conf
dig portal.empresa.lab
dig @10.126.0.53 portal.empresa.lab
dig -x 10.126.0.25 @10.126.0.53 +short
F=$(dig +short portal.empresa.lab)
R=$(dig +short @10.126.0.53 portal.empresa.lab)
N=$(dig +short -x 10.126.0.25 @10.126.0.53 | sed 's/\.$//')
printf 'resolver_actual=10.126.0.99\nportal_falso=%s\nportal_real=%s\nnombre_25=%s\n' "$F" "$R" "$N" > $H/dns.txt
echo 'nameserver 10.126.0.53' > /etc/resolv.conf
dig +dnssec portal.empresa.lab > $H/dnssec.txt
chown analista:analista $H/dns.txt $H/dnssec.txt
