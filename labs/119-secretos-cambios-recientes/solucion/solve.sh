#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
cd /srv/app
grep -rnEi "password|api_key|secret|passw|token|AKIA" . > /home/analista/secretos.txt || true
grep -rn 'Verano2024' . >> /home/analista/secretos.txt || true
find . -type f -mtime -1 > /home/analista/recientes.txt
grep -v nologin /etc/passwd | grep -v ':/bin/false$'
chown analista:analista /home/analista/secretos.txt /home/analista/recientes.txt

usermod -L -s /usr/sbin/nologin soporte2
cat > .env <<'E'
DB_PASSWORD=Tienda#Prod2024
API_KEY=sk_live_LAB-119-clave-de-pruebas
AWS_ACCESS_KEY_ID=AKIA-LAB-119-FALSA
AWS_SECRET_ACCESS_KEY=Wq8tLab/Tc0r+DeployK3y9mZpQ1vXc5bN7hJ2fRs
E
chown app:app .env; chmod 600 .env
sed -i 's|password: "Tienda#Prod2024"|password: <%= ENV["DB_PASSWORD"] %>|' config/database.yml
sed -i 's|^API_KEY = .*|import os\nAPI_KEY = os.environ["API_KEY"]|' src/payments.py
sed -i '/^export AWS_/d; /203.0.113.80/d' scripts/deploy.sh
rm -f .cache/notas.txt
