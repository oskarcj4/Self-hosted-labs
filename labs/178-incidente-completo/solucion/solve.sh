#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
L=/var/log/pedidos
I=~/incidente
INI=$(date +%H:%M)
echo "$INI Investigando: la tienda devuelve errores 5xx al cargar los pedidos. Próxima actualización en 15 min." > $I/comunicado.txt

# 1. Diagnóstico: 502 en nginx, la app no puede escribir: volumen de logs lleno.
curl -s -o /dev/null -w 'antes: %{http_code}\n' http://127.0.0.1:8080/pedidos || true
df -h $L
sudo ls -la $L
sudo journalctl -u pedidos --no-pager | grep -m3 'No space left' || true

# 2. Liberar espacio sin borrar el fichero abierto: vaciarlo y comprimir lo antiguo.
sudo truncate -s 0 $L/app.log
sudo gzip -f $L/app.log.1 $L/app.log.2 $L/app.log.3
df -h $L

# 3. Quitar la causa: fuera DEBUG.
sudo sed -i 's/^Environment=LOG_LEVEL=DEBUG/Environment=LOG_LEVEL=INFO/' /etc/systemd/system/pedidos.service
sudo systemctl daemon-reload
sudo systemctl restart pedidos
sleep 2
curl -s -o /dev/null -w 'después: %{http_code}\n' http://127.0.0.1:8080/pedidos

# 4. Que no vuelva a pasar.
sudo tee /etc/logrotate.d/pedidos >/dev/null <<'LR'
/var/log/pedidos/*.log {
    size 5M
    rotate 5
    compress
    missingok
    notifempty
    copytruncate
}
LR
sudo logrotate -d /etc/logrotate.d/pedidos 2>&1 | tail -3
# logrotate de Debian corre a diario (cron/timer). Con 5 MB de "size" conviene cada hora.
echo '17 * * * * root /usr/sbin/logrotate /etc/logrotate.d/pedidos' | sudo tee /etc/cron.d/logrotate-pedidos >/dev/null

FIN=$(date +%H:%M)
echo "$FIN Resuelto: el servicio funciona con normalidad. El volumen de logs se había llenado; publicaremos el análisis." >> $I/comunicado.txt

# 5. Postmortem con las horas reales.
DEP=$(tail -1 /var/log/despliegues.log | awk '{print substr($2,1,5)}')
FE=$(sudo journalctl -u pedidos --no-pager -o short-iso | grep -m1 -E 'No space left|OSError' | awk '{print $1}' | cut -c12-16)
AL=$(sed -n '1s/^\[[0-9-]* \([0-9]*:[0-9]*\).*/\1/p' $I/alerta.txt)
cat > $I/postmortem.md <<MD
# Postmortem: la tienda no cargaba los pedidos (volumen de logs lleno)

## Resumen
Un despliegue activó el registro en DEBUG en la API de pedidos. Cada petición
escribía unos 8 KB de log y no había rotación: el volumen de logs (32 MB) se
llenó, la API dejó de poder escribir y nginx devolvió 502.

## Impacto
Entre las $FE y las $FIN la mayoría de peticiones a /pedidos fallaron (5xx).
Los clientes no podían ver sus pedidos; soporte recibió 3 tickets. No hubo
pérdida de datos.

## Línea de tiempo
- $DEP Despliegue de pedidos v3.4.1 con LOG_LEVEL=DEBUG.
- $FE Primer error "No space left on device" en la API.
- $AL Salta la alerta de 5xx > 50 %.
- $INI Guardia investigando; primer comunicado.
- $FIN Espacio liberado, DEBUG desactivado, rotación configurada. Servicio normal.

## Causa raíz
El volumen de logs no tenía rotación ni alerta de espacio, y el nivel DEBUG
podía llegar a producción sin límite de tiempo ni de volumen. Un cambio
razonable para depurar un bug bastó para llenar el disco en minutos.

## Qué funcionó y qué no
- Funcionó: la alerta de 5xx y el diagnóstico rápido (df y journalctl).
- No funcionó: no había alerta de disco antes de llegar al 100 %; el despliegue
  no mostraba que cambiaba el nivel de log.

## Acciones
- [ ] logrotate por tamaño para /var/log/pedidos (hecho) · equipo plataforma · 2026-11-06
- [ ] Alerta de disco al 80 % en los volúmenes de logs · equipo SRE · 2026-11-13
- [ ] DEBUG en producción sólo temporal (caduca solo) y con muestreo · equipo pedidos · 2026-11-20
- [ ] Revisar en el pipeline los cambios de nivel de log · equipo plataforma · 2026-11-20
MD
cat $I/comunicado.txt
echo "solve.sh completado."
