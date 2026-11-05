# Solución — Rollback en menos de 2 minutos

## Qué pasaba

- green (1.5.0) responde 200 en `/` pero 500 en `/api/checkout` y 503 en
  `/health`: espera el esquema v14 y la base sigue en v13.
- El health check (`option httpchk GET /`) miraba la portada, así que
  HAProxy veía green "UP" y le mandaba todo.
- El socket de la runtime API era `level user`: no aceptaba `set server`.

## Arreglo

```bash
printf 'version_mala=1.5.0\nversion_buena=1.4.0\n' > ~/incidente.txt

sudo nano /etc/haproxy/haproxy.cfg
#   stats socket /run/haproxy/admin.sock mode 660 level admin
#   backend shop
#       option httpchk GET /health
#       http-check expect status 200
sudo haproxy -c -f /etc/haproxy/haproxy.cfg && sudo systemctl reload haproxy

cat > ~/rollback.sh <<'R'
#!/usr/bin/env bash
# Rollback blue/green por la runtime API de HAProxy: sin reload ni restart.
set -euo pipefail
SOCK=/run/haproxy/admin.sock
api(){ echo "$1" | sudo socat stdio "$SOCK"; }
t0=$(date +%s)
api "set server shop/blue state ready"
api "set server shop/green state maint"
for _ in $(seq 1 30); do
  v=$(curl -s -o /dev/null -D - --max-time 2 http://127.0.0.1/api/checkout | tr -d '\r' | awk -F': ' 'tolower($1)=="x-app-version"{print $2}')
  [ "$v" = 1.4.0 ] && { echo "Rollback OK a $v en $(( $(date +%s) - t0 ))s"; exit 0; }
  sleep 1
done
echo "Rollback NO confirmado" >&2; exit 1
R
chmod +x ~/rollback.sh
~/rollback.sh
bash /opt/lab/check.sh
```

## Más allá del lab

- En producción, `rollback.sh` lo ejecuta el pipeline (botón "rollback") y
  avisa en el canal del incidente.
- Con `agent-check` la app puede pedir "drenarme" antes de un despliegue.
- `option redispatch` + `retries` reintentan en otro servidor si uno cae a mitad.
