# Solución — fstab roto

## Qué pasaba

- `/datos` no existía (mount no lo crea).
- `ext44` no es un tipo de sistema de ficheros.
- El UUID de `/backup` no existe y la línea no llevaba `nofail`.

## Arreglo

```bash
sudo mkdir -p /datos
sudo sed -i 's/ ext44 / ext4 /' /etc/fstab
sudo sed -i '/\/backup/ s/defaults/defaults,nofail/' /etc/fstab
sudo findmnt --verify
sudo mount -a
bash /opt/lab/check.sh
```

## Más allá del lab

- `x-systemd.automount` monta bajo demanda; `x-systemd.device-timeout=` limita la espera.
- `systemd-analyze verify` y `systemctl --failed` tras `daemon-reload` completan la comprobación.
