#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
nets(){ docker inspect "handoff-$1-1" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' \
  | tr ' ' '\n' | grep . | sed 's/^handoff_//' | sort | paste -sd, -; }
port=$(docker port handoff-web-1 8080/tcp | head -1 | sed 's/.*://')
cat > /home/analista/audit/handoff.txt <<EOF
entrypoint_servicio=web
entrypoint_puerto=$port
redes_web=$(nets web)
redes_api=$(nets api)
redes_worker=$(nets worker)
redes_db=$(nets db)
volumen_compartido=reports
volumen_montado_en=api,worker
EOF
chown analista: /home/analista/audit/handoff.txt
