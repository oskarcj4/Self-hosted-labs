# Solución — Día 15: Endurecer una tarea cron de root

## 1. Diagnóstico

```bash
cat /etc/cron.d/cache-cleanup
# */5 * * * * root /var/tmp/jobs/cleanup-cache.sh ...
namei -l /var/tmp/jobs/cleanup-cache.sh
# drwxrwxrwt root root tmp     <- sticky, pero...
# drwxrwxrwx root root jobs    <- cualquiera puede sustituir el script
# -rwxrwxrwx root root cleanup-cache.sh   <- ...o editarlo directamente
```

Ataque trivial (no lo hagas en producción):
`echo 'cp /bin/bash /tmp/rb; chmod u+s /tmp/rb' >> /var/tmp/jobs/cleanup-cache.sh`
y en ≤ 5 minutos hay una shell SUID de root.

## 2. Revisar el contenido

El script estuvo escribible por todos: **léelo entero** antes de confiar en él
(en un caso real, compáralo con el control de versiones).

```bash
cat /var/tmp/jobs/cleanup-cache.sh
```

## 3. Moverlo a una ruta de root

```bash
sudo install -m 0755 -o root -g root /var/tmp/jobs/cleanup-cache.sh /usr/local/sbin/cleanup-cache
namei -l /usr/local/sbin/cleanup-cache     # todo root, sin escritura g/o
```

## 4. Apuntar cron al nuevo script y limpiar lo viejo

```bash
sudo sed -i 's#/var/tmp/jobs/cleanup-cache.sh#/usr/local/sbin/cleanup-cache#' /etc/cron.d/cache-cleanup
sudo chown root:root /etc/cron.d/cache-cleanup && sudo chmod 0644 /etc/cron.d/cache-cleanup
sudo rm -rf /var/tmp/jobs
```

## 5. Verificar

```bash
sudo /usr/local/sbin/cleanup-cache     # ... borrados N temporales
ls /var/cache/app                      # index.dat sigue ahí
systemctl is-active cron
```

## Lecciones

- Lo que root ejecuta automáticamente debe ser tan inmutable como root:
  **fichero y toda la cadena de carpetas** de root, sin escritura g/o.
- `/tmp` y `/var/tmp` son de todos (el sticky bit sólo impide borrar ficheros ajenos;
  no protege una subcarpeta `0777`).
- Revisa también `crontab -l -u root`, `/etc/cron.*` y los timers de systemd.
- Un script que estuvo escribible por todos es **sospechoso**: revísalo antes de "promoverlo".
