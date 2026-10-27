#!/usr/bin/env bash
# Corre como 'app'. Arranca app.py y lo reinicia cuando alguien toca
# /srv/app/reload (lo hace el comando app-reload).
cd /srv/app
run() { python3 /srv/app/app.py >/tmp/app.log 2>&1 & echo $! >/tmp/app.pid; chmod 644 /tmp/app.log; }
run
last=$(stat -c %Y reload 2>/dev/null || echo 0)
while sleep 1; do
  now=$(stat -c %Y reload 2>/dev/null || echo 0)
  if [ "$now" != "$last" ]; then
    last=$now
    kill "$(cat /tmp/app.pid 2>/dev/null)" 2>/dev/null
    sleep 1
    run
  fi
done
