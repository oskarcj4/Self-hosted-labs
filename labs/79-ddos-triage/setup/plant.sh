#!/usr/bin/env bash
# Planta el escenario del Lab 79: un access.log con tráfico mezclado.
#   - usuarios legítimos variados (192.0.2.0/24)
#   - health check interno de alto volumen pero SANO (10.0.0.50)
#   - crawler legítimo (66.249.66.1, Googlebot)
#   - flood distribuido malicioso (203.0.113.0/24 y 198.51.100.0/24)
# El reto es distinguir, NO bloquear a ciegas.
set -e
LOG=/var/log/apache2/access.log
mkdir -p /var/log/apache2 /etc/ddos
: > "$LOG"

ts() { date -d "-$1 min" '+%d/%b/%Y:%H:%M:%S +0000' 2>/dev/null || date '+%d/%b/%Y:%H:%M:%S +0000'; }
UA_BROWSER='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36'
UA_BOT='python-requests/2.31.0'
UA_GOOG='Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)'
UA_HC='HealthCheck/1.0'

# --- Usuarios legítimos: pocas peticiones cada uno, rutas variadas, con Referer
PATHS=(/ /index.html /productos /blog/post-1 /contacto /static/app.css /favicon.ico)
for h in 7 12 23 31 44 58 66 71 83 90 101 118 133 149 160 177 188 199 210 231; do
  ip="192.0.2.$h"
  n=$(( (h % 4) + 1 ))
  for i in $(seq 1 "$n"); do
    p="${PATHS[$(( (h+i) % ${#PATHS[@]} ))]}"
    echo "$ip - - [$(ts $((h%30+1)))] \"GET $p HTTP/1.1\" 200 2048 \"https://web-79/\" \"$UA_BROWSER\"" >> "$LOG"
  done
done

# --- Health check interno: MUCHO volumen, pero legítimo (ruta /health, 200, UA propio)
for i in $(seq 1 400); do
  echo "10.0.0.50 - - [$(ts $((i%20+1)))] \"GET /health HTTP/1.1\" 200 15 \"-\" \"$UA_HC\"" >> "$LOG"
done

# --- Crawler legítimo: volumen moderado, respeta rutas reales
for i in $(seq 1 40); do
  p="${PATHS[$(( i % ${#PATHS[@]} ))]}"
  echo "66.249.66.1 - - [$(ts $((i%25+1)))] \"GET $p HTTP/1.1\" 200 2048 \"-\" \"$UA_GOOG\"" >> "$LOG"
done

# --- Flood distribuido: muchas IPs de 2 redes, misma ruta cara, sin Referer, UA de script
for net in 203.0.113 198.51.100; do
  for host in $(seq 1 60); do
    reps=$(( (host % 5) + 8 ))
    for r in $(seq 1 "$reps"); do
      code=200; [ $((r % 3)) -eq 0 ] && code=503
      echo "$net.$host - - [$(ts $((r%3)))] \"GET /buscar?q=%25%25%25&sort=precio HTTP/1.1\" $code 540 \"-\" \"$UA_BOT\"" >> "$LOG"
    done
  done
done

# Mezcla cronológica aproximada
sort -R "$LOG" -o "$LOG" 2>/dev/null || true

# Blocklist vacía con cabecera (la rellena el analista)
cat > /etc/ddos/blocklist.txt <<'EOF'
# Blocklist anti-DDoS — una red CIDR por línea.
# Añade SÓLO los rangos atacantes confirmados. No bloquees monitorización ni crawlers.
EOF
chown analista:analista /home/analista 2>/dev/null || true
chmod 666 /etc/ddos/blocklist.txt

echo "Lab 79 plantado. Entra como analista y lee /RETO.md"
