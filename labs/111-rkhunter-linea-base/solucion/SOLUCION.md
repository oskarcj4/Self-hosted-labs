# Solución — Línea base con rkhunter y un ps troyanizado

## Qué pasaba

- `/usr/bin/ps` estaba sustituido por un script que llamaba al `ps` real y
  filtraba `kswapd-upd`, un servicio que imita un hilo del kernel.
- `debsums -c` lo delata: el md5 no coincide con el del paquete `procps`.
- Si creas la base de rkhunter (`--propupd`) con el troyano dentro, rkhunter
  da por bueno el binario falso para siempre.

## Arreglo

```bash
sudo debsums -c
sudo dpkg -i /var/cache/paquetes-oficiales/procps_*.deb
sudo systemctl disable --now kswapd-upd
sudo rm -f /usr/local/sbin/kswapd-upd /usr/lib/x86_64-linux-gnu/libprocps-cache.so.0
sudo debsums -s procps

sudo rkhunter --propupd
sudo rkhunter --check --sk
sudo sh -c 'chkrootkit > /mnt/offsite/chkrootkit.txt 2>&1'
sudo cp /var/lib/rkhunter/db/rkhunter.dat /mnt/offsite/
sudo cp /var/log/rkhunter.log /mnt/offsite/rkhunter-check.log
sudo nano /mnt/offsite/informe.txt   # HALLAZGO REAL: ps... / falso positivo: ...
bash /opt/lab/check.sh
```

## Más allá del lab

- **AIDE / Tripwire / OSSEC** hacen lo mismo con más control; la idea es la
  misma: base limpia, guardada fuera, comparada a diario.
- En un incidente real con root comprometido, **reinstala**: un rootkit de
  kernel no se ve desde dentro.
- Programa `rkhunter --check --cronjob` y envía el informe a otro servidor.
