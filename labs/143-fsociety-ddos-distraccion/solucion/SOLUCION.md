# Solución — El DDoS como distracción

## Qué pasaba

Un origen (`10.143.0.66`, etiqueta `fsociety/1.0`) inunda `/` desde las 02:11.
Es ruido. A las 02:14, **durante** esa inundación, se plantó persistencia:
`/etc/cron.d/fsociety` lanza `/usr/local/bin/fsociety-beacon` cada minuto, y
se dejó caer `/opt/allsafe/.fsociety/fsociety00.dat`.

## Arreglo

```bash
# 1) ¿Quién inunda?
sudo awk '$7=="/"{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head -3

# 2) Limita la raíz por IP, 429 al pasarse
sudo tee /etc/nginx/conf.d/limites.conf <<'N'
limit_req_zone  $binary_remote_addr zone=raiz:10m rate=5r/s;
limit_conn_zone $binary_remote_addr zone=conx:10m;
limit_req_status  429;
limit_conn_status 429;
N
sudo nano /etc/nginx/sites-available/allsafe
#   location / {
#       limit_req zone=raiz burst=10 nodelay;
#       limit_conn conx 10;
#       try_files $uri $uri/ =404;
#   }
sudo nginx -t && sudo systemctl reload nginx
sudo tail -f /var/log/nginx/access.log | grep ' 429 '   # el bot ya recibe 429

# 3) Caza la persistencia plantada entre las 02:10 y las 02:20
sudo find / -xdev -newermt "$(date +%F) 02:10" ! -newermt "$(date +%F) 02:20" -type f 2>/dev/null | grep -v -e /proc -e /sys
cat /etc/cron.d/fsociety                      # -> /usr/local/bin/fsociety-beacon
stat /opt/allsafe/.fsociety/fsociety00.dat    # modificado 02:14

# 4) Documenta
DAT=/opt/allsafe/.fsociety/fsociety00.dat
cat > ~/hallazgos.txt <<H
ip_ddos=10.143.0.66
ruta_persistencia=/etc/cron.d/fsociety
binario_beacon=/usr/local/bin/fsociety-beacon
fsociety_dat=$DAT
sha256_dat=$(sha256sum $DAT | cut -d' ' -f1)
H

cat > ~/timeline.txt <<T
02:11  inicio del DDoS a / desde 10.143.0.66 (access.log)
02:14  se planta la persistencia (cron.d/fsociety + beacon) y cae fsociety00.dat
Conclusión: la persistencia se plantó durante la inundación; el DDoS era la distracción.
T

# 5) Erradica la persistencia (conserva el .dat como evidencia)
sudo rm -f /etc/cron.d/fsociety /usr/local/bin/fsociety-beacon
sudo systemctl restart cron
sudo pkill -f fsociety-beacon 2>/dev/null || true

bash /opt/lab/check.sh
```

## Más allá del lab

- Correlaciona SIEMPRE un pico de tráfico con cambios en disco y cuentas en
  esa ventana. El `find -newermt ... ! -newermt ...` es tu mejor amigo.
- Contra DDoS real: CDN/anycast, scrubbing, `real_ip` tras el proxy y
  fail2ban leyendo los 429.
- `fsociety00.dat` se conserva: es evidencia para el análisis posterior
  (hash, cadena de custodia), no se borra en caliente.
