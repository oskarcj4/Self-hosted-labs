# Solución — Cron que no se ejecuta

Deja `sudo journalctl -u cron -f` abierto en otra pestaña. Cron avisa de casi
todo, pero no de todo.

## 1. limpieza-tmp: falta el usuario

```
* * * * * /usr/local/bin/limpieza-tmp.sh
```

En `/etc/cron.d/` y `/etc/crontab` hay **seis** campos: el sexto es el usuario.
Aquí cron toma `/usr/local/bin/limpieza-tmp.sh` como nombre de usuario y no
queda ningún comando. El journal lo dice al arrancar (o al recargar el fichero):

```
Error: bad command; while reading /etc/cron.d/limpieza-tmp
(*system*limpieza-tmp) ERROR (Syntax error, this crontab file will be ignored)
```

```
* * * * * root /usr/local/bin/limpieza-tmp.sh
```

(`crontab -e` de un usuario **no** lleva este campo. Mezclar los dos formatos
es el error más típico.)

## 2. informe.diario: el nombre del fichero

Cron **ignora en silencio** los ficheros de `/etc/cron.d/` cuyo nombre tenga
un punto (y otros caracteres). Lo hace para no ejecutar `.dpkg-old`,
`.bak`, `~`... No hay ningún mensaje en el journal.

```bash
sudo mv /etc/cron.d/informe.diario /etc/cron.d/informe-diario
```

## 3. metricas: el PATH de cron

```
* * * * * root metricas-push
```

Cron ejecuta con `PATH=/usr/bin:/bin`, y el script está en `/usr/local/bin`.
El error va al correo de root, y como aquí no hay MTA, se pierde. El journal
sólo dice `(CRON) info (No MTA installed, discarding output)`.

```
* * * * * root /usr/local/bin/metricas-push
```

(O una línea `PATH=/usr/local/bin:/usr/bin:/bin` al principio del fichero.)

## 4. backup-db: el `%`

En crontab, `%` significa **salto de línea**: lo que va detrás se pasa como
stdin al comando. El journal lo enseña, si te fijas en el final de la línea:

```
CRON[166]: (root) CMD (/usr/local/bin/backup-db.sh > /var/log/backup-db-$(date +)
```

Cron ejecuta `... > /var/log/backup-db-$(date +`, que es un error de sintaxis.

```
* * * * * root /usr/local/bin/backup-db.sh > /var/log/backup-db-$(date +\%F).log 2>&1
```

Una alternativa más limpia: pon la redirección dentro del script.

## 5. sync-catalogo: dos fallos a la vez

```bash
cat -A /etc/cron.d/sync-catalogo     # la última línea no termina en '$'
ls -l /usr/local/bin/sync-catalogo.sh   # -rw-r--r--
```

- Sin salto de línea final, cron ignora **el fichero entero**:
  `(*system*sync-catalogo) ERROR (Missing newline before EOF, this crontab file will be ignored)`.
- Además, el script no es ejecutable: `Permission denied` (otra vez al correo
  perdido).

```bash
echo | sudo tee -a /etc/cron.d/sync-catalogo >/dev/null
sudo chmod 0755 /usr/local/bin/sync-catalogo.sh
```

## Verifica

```bash
watch -n5 'ls -l --time-style=+%T /var/lib/heartbeat/; ls /var/log/backup-db-*'
```

## Lecciones

- "A mano funciona" no significa nada: cron tiene **otro entorno** (PATH,
  HOME, sin tu shell ni tus variables).
- La salida de cron va al correo. Si no hay MTA, se pierde: redirige a un
  log (`>> /var/log/x.log 2>&1`) o usa `MAILTO=` con un MTA que funcione.
- Para tareas nuevas, considera timers de systemd: logs en el journal,
  `systemctl list-timers`, `Persistent=true` y sin estas trampas de formato.
- Cada tarea programada necesita su latido o su alerta de "no ha corrido"
  (como en el lab 58 y el 64).
