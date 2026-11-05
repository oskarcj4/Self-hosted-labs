# Solución — Defacement de fsociety

## Qué pasaba

`index.html` fue reemplazado por una página de fsociety (madrugada, ~03:07).
El respaldo bueno estaba en `/opt/backups/index.html.orig`. Faltaba integridad
de ficheros: nadie se habría enterado del cambio hasta verlo.

## Arreglo

```bash
# 1) Confirmar y restaurar
diff /opt/backups/index.html.orig /var/www/html/index.html
sudo cp /opt/backups/index.html.orig /var/www/html/index.html
sudo systemctl reload nginx

# 2) Línea base de AIDE SOBRE EL ESTADO BUENO
sudo aide --init -c /etc/aide/aide-www.conf
sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
sudo aide --check -c /etc/aide/aide-www.conf      # limpio

# 3) Vigilancia en tiempo real (inotify)
sudo tee /etc/systemd/system/fim-www.service >/dev/null <<'U'
[Unit]
Description=FIM del webroot (inotify)
After=multi-user.target
[Service]
ExecStart=/usr/bin/inotifywait -m -r -e modify,create,delete,move -o /var/log/fim.log /var/www/html
Restart=always
[Install]
WantedBy=multi-user.target
U
sudo systemctl daemon-reload && sudo systemctl enable --now fim-www.service
sudo tail -f /var/log/fim.log      # toca un fichero del webroot y velo aparecer

# 4) Hallazgos
cat > ~/hallazgos.txt <<'HAL'
pagina_afectada=/var/www/html/index.html
firma_defacement=fsociety
HAL
bash /opt/lab/check.sh
```

## Más allá del lab

- **Restaura antes de tomar la línea base**, o grabarás el defacement como
  "estado bueno".
- AIDE audita a fondo pero por tandas (cron); inotify reacciona al instante
  pero no sobrevive si el atacante para el servicio. Úsalos juntos.
- En producción, el webroot suele ser inmutable (imagen/solo-lectura) y se
  despliega, no se edita en caliente: un cambio in situ ya es una alerta.
