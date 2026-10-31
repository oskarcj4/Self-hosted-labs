# Solución — Higiene de permisos y umask

## Qué pasaba

- `~/.ssh` y la clave privada de `deploy` legibles por todos.
- `/srv/app/.env` con secretos legible por todos.
- `/usr/local/bin/backup.sh` (lo ejecuta root) escribible por todos.
- `/etc/app/config.yml` escribible por todos.
- `umask 000` en `/etc/profile.d/99-umask-compat.sh` y en `~deploy/.profile`.

## Arreglo

```bash
sudo chmod 700 /home/deploy/.ssh
sudo chmod 600 /home/deploy/.ssh/id_ed25519 /home/deploy/.ssh/authorized_keys
sudo chmod 600 /srv/app/.env
sudo chmod 755 /usr/local/bin/backup.sh
sudo chmod 644 /etc/app/config.yml
sudo find / -xdev -type f -perm -0002 -not -path '/proc/*' -exec chmod o-w {} + 2>/dev/null
sudo rm -f /etc/profile.d/99-umask-compat.sh
sudo sed -i 's/^umask 000.*/umask 027/' /home/deploy/.profile
sudo su - deploy -c umask
bash /opt/lab/check.sh
```

## Más allá del lab

- La clave privada estuvo expuesta: genera una nueva y retira la antigua de
  `authorized_keys` en todos los servidores.
- `UMask=` en unidades systemd controla el umask de servicios, que no leen `.profile`.
