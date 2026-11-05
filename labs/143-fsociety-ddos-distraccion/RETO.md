# fsociety00.dat: el DDoS como distracción

> Mr. Robot · respuesta a incidentes · rate limiting · caza de persistencia · timeline

## Escenario

`allsafe-143` recibe desde las **02:11** una inundación de peticiones a la
raíz (`/`). Soporte sólo ve el DDoS. Pero una inundación ruidosa es el
truco más viejo del manual: mientras todos miran el humo, alguien entra por
detrás. En Allsafe eso significa **persistencia** plantada y un fichero
dejado caer: `fsociety00.dat`.

- Un **DDoS volumétrico** no se "arregla" en el servidor, pero sí se
  contiene: un límite por IP evita que un único origen consuma todo.
- `limit_req_zone` + `limit_req`: peticiones por segundo por clave (la IP).
  Con `burst` toleras ráfagas; `nodelay` las sirve al momento.
- Lo normal al pasarse es **429 Too Many Requests** (`limit_req_status 429`),
  no el 503 por defecto.
- La **persistencia** sobrevive a reinicios: cron, timers, servicios, claves
  SSH. Aquí es un `cron.d` que lanza un beacon.

## Objetivos

1. Identifica la IP del DDoS en `/var/log/nginx/access.log` y limita `/`
   por IP (ráfaga + conexiones simultáneas) respondiendo **429**. `/static/`
   se queda sin límite.
2. Caza la persistencia plantada **durante** la inundación: el cron y el
   binario que ejecuta. Quítalos. Deja `fsociety00.dat` como evidencia.
3. Escribe `~/hallazgos.txt`:

   ```
   ip_ddos=<IP>
   ruta_persistencia=<ruta del cron>
   binario_beacon=<ruta del script>
   fsociety_dat=<ruta del fichero>
   sha256_dat=<sha256 del fichero>
   ```

4. Arma `~/timeline.txt` con la hora de inicio del DDoS y la hora en que se
   plantó la persistencia (demuestra que fue durante la distracción).

## Comandos que te pueden servir

```bash
sudo awk '$7=="/"{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head
sudo head -1 /var/log/nginx/access.log; sudo grep -m1 '10.143.0.66' /var/log/nginx/access.log   # inicio del flood
sudo find / -xdev -newermt "$(date +%F) 02:10" ! -newermt "$(date +%F) 02:20" -type f 2>/dev/null | grep -v /proc
ls -la --time-style=full-iso /etc/cron.d/; cat /etc/cron.d/fsociety; stat /opt/allsafe/.fsociety/fsociety00.dat
sudo nano /etc/nginx/conf.d/limites.conf          # zonas: contexto http
sudo nano /etc/nginx/sites-available/allsafe      # limit_req / limit_conn dentro de location /
sudo nginx -t && sudo systemctl reload nginx
sha256sum /opt/allsafe/.fsociety/fsociety00.dat
sudo rm /etc/cron.d/fsociety /usr/local/bin/fsociety-beacon && sudo systemctl restart cron
```

> Un límite por IP no para una botnet real con miles de IP: ahí entran CDN,
> anycast y scrubbing. El valor del lab está en **no quedarte en el DDoS**:
> busca qué tapaba.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
