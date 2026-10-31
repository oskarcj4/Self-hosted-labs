# Solución — Respaldo y recuperación tras un cifrado

## Qué pasaba

`datos-indexer.service` cifraba los ficheros de `/srv/datos` (renombrados a
`.lock`) y dejaba `LEEME-RESCATE.txt`. Seguía activo. Existía un respaldo
offline en `/var/backups/respaldo-offline.img` con su `SHA256SUMS`.

## Arreglo

```bash
echo "alterados=$(find /srv/datos -type f -name '*.lock' | wc -l)" > ~/incidente.txt
sudo systemctl disable --now datos-indexer
sudo mkdir -p /root/evidencia
sudo cp /usr/local/sbin/datos-indexer /etc/systemd/system/datos-indexer.service /root/evidencia/
sudo rm -f /usr/local/sbin/datos-indexer /etc/systemd/system/datos-indexer.service
sudo systemctl daemon-reload

sudo mkdir -p /mnt/respaldo
sudo mount -o ro,loop /var/backups/respaldo-offline.img /mnt/respaldo
(cd /mnt/respaldo/datos && sudo sha256sum -c --quiet ../SHA256SUMS)
sudo rsync -a --delete /mnt/respaldo/datos/ /srv/datos/
(cd /srv/datos && sudo sha256sum -c --quiet /mnt/respaldo/SHA256SUMS) && echo "Restauración verificada"
sudo umount /mnt/respaldo
bash /opt/lab/check.sh
```

## Más allá del lab

- Respaldos inmutables (object lock en S3, WORM) o en una cuenta separada.
- Mide tu RPO/RTO: cuántos datos pierdes y cuánto tardas en restaurar.
- Investiga el acceso inicial antes de volver a conectar el servidor.
