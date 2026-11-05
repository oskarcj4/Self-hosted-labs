#!/usr/bin/env bash
# Lab 143 (Mr. Robot M1): el DDoS como distracción.
# Mientras una inundación HTTP golpea la raíz, "alguien" plantó persistencia
# (cron.d + beacon) y dejó caer fsociety00.dat. El alumno frena la inundación,
# caza la persistencia y arma la línea de tiempo que delata la maniobra.
set -e
export HOME=/root
H=/home/analista
WEB=/var/www/allsafe
DIA=$(date +%d/%b/%Y)
HOY=$(date +%Y-%m-%d)

# --- sitio web de Allsafe (sin límite: lo pone el alumno) ---------------------
mkdir -p $WEB/static
cat > $WEB/index.html <<'HTML'
<!doctype html>
<title>Allsafe Cybersecurity</title>
<h1>Allsafe Cybersecurity</h1>
<p>Portal interno. Acceso restringido.</p>
HTML
echo 'console.log("allsafe");' > $WEB/static/app.js

cat > /etc/nginx/sites-available/allsafe <<'N'
server {
    listen 80 default_server;
    root /var/www/allsafe;
    index index.html;

    # location / {              # <-- aquí irá tu limit_req / limit_conn
    #     try_files $uri $uri/ =404;
    # }
    location / {
        try_files $uri $uri/ =404;
    }

    location /static/ {
    }
}
N
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/allsafe /etc/nginx/sites-enabled/allsafe
systemctl enable --now nginx

# --- registro histórico de la inundación (empezó a las 02:11) -----------------
# El bot en vivo seguirá añadiendo líneas; estas fijan el inicio para la timeline.
{
  for s in $(seq 11 19); do
    for i in $(seq 1 25); do
      printf '10.143.0.66 - - [%s:02:%02d:%02d +0000] "GET / HTTP/1.1" 200 64 "-" "fsociety/1.0"\n' "$DIA" "$s" "$((i % 60))"
    done
  done
} >> /var/log/nginx/access.log
# Un puñado de peticiones legítimas de oficina, para que no todo sea el bot.
for ip in 10.143.0.21 10.143.0.22; do
  printf '%s - - [%s:09:03:12 +0000] "GET / HTTP/1.1" 200 64 "-" "Mozilla/5.0"\n' "$ip" "$DIA" >> /var/log/nginx/access.log
done

# --- persistencia plantada DURANTE la inundación (02:14) ----------------------
install -d -m 0755 /opt/allsafe/.fsociety
# fsociety00.dat: contenido fijo (sha256 determinista) como "carga" dejada atrás.
python3 - <<'PY' > /opt/allsafe/.fsociety/fsociety00.dat
import sys
sys.stdout.write(("fsociety\x00" * 64)[:512])
PY

cat > /usr/local/bin/fsociety-beacon <<'SH'
#!/usr/bin/env bash
# Beacon de persistencia (inofensivo en el lab): sólo deja rastro en un log.
echo "$(date '+%F %T') beacon vivo pid=$$" >> /var/log/fsociety.log
SH
chmod 0755 /usr/local/bin/fsociety-beacon

cat > /etc/cron.d/fsociety <<'CR'
# Persistencia: ejecuta el beacon cada minuto como root.
* * * * * root /usr/local/bin/fsociety-beacon
CR
chmod 0644 /etc/cron.d/fsociety
: > /var/log/fsociety.log
/usr/local/bin/fsociety-beacon
systemctl enable --now cron

# Marcas de tiempo: la persistencia se plantó a las 02:14, dentro del flood.
touch -d "$HOY 02:14:00" /opt/allsafe/.fsociety /opt/allsafe/.fsociety/fsociety00.dat \
  /usr/local/bin/fsociety-beacon /etc/cron.d/fsociety /var/log/fsociety.log

# --- ticket -------------------------------------------------------------------
mkdir -p $H/ticket
cat > $H/ticket/IR-143.txt <<'TXT'
IR-143 · allsafe-143 · "la web se cae"
Desde las 02:11 la web recibe una inundación de peticiones a la raíz (/).
Soporte sólo ve el ruido. Pero el ruido suele tapar algo.

1. Frena la inundación: identifica la IP y limita / por IP (ráfaga + conexiones),
   respondiendo 429. /static/ no se toca. Mide con hey si quieres.
2. Mientras todos miraban el DDoS, se plantó persistencia. Encuéntrala
   (cron + binario) y el fichero que dejaron caer. Quita la persistencia;
   deja el fichero como evidencia.
3. Escribe ~/hallazgos.txt:
     ip_ddos=<IP>
     ruta_persistencia=<ruta del cron>
     binario_beacon=<ruta del script>
     fsociety_dat=<ruta del fichero dejado caer>
     sha256_dat=<sha256 de ese fichero>
4. Línea de tiempo en ~/timeline.txt: la hora en que empezó el DDoS y la hora
   en que se plantó la persistencia (demuestra que fue durante la distracción).
TXT
chown -R analista:analista $H/ticket
echo "Lab 143 plantado."
