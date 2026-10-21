# Solución — Disco lleno

## 1. ¿Qué está lleno, bytes o inodos?

```bash
df -h /var/log/app /srv/sessions
df -i /var/log/app /srv/sessions
```

- `/var/log/app`: **100 %** de bytes.
- `/srv/sessions`: casi sin bytes usados, pero **100 % de inodos** (`IUse%`).
  Cada fichero gasta un inodo aunque pese 0 bytes. Por eso sale "No space left
  on device" con el disco vacío.

## 2. Bytes: lo que se ve con `du`

```bash
sudo du -xah /var/log/app | sort -h | tail -5
```

`orders.log.1` (un rotado sin comprimir) pesa ~58 MB. Es historia: se puede
borrar o comprimir.

```bash
sudo rm /var/log/app/orders.log.1
df -h /var/log/app     # baja... pero sigue alrededor del 40-45 %
```

## 3. Bytes: lo que NO se ve con `du`

`df` y `du` no cuadran: `du` suma los ficheros que tienen nombre y `df`
cuenta los bloques ocupados. Un fichero borrado que un proceso mantiene
abierto ya no tiene nombre, pero sus bloques siguen ocupados hasta que se cierra.

```bash
sudo lsof -nP +L1
# trace-col  PID orders 3w REG ... 41943040 0 ... /var/log/app/debug-trace.log (deleted)
```

Dos opciones, sin matar el servicio a lo bruto:

```bash
sudo systemctl restart trace-collector          # cierra el fd y abre uno nuevo
# o, si no puedes reiniciar, vacía el fichero a través del fd:
sudo truncate -s 0 /proc/PID/fd/3
```

## 4. Inodos: borrar sólo lo caducado

```bash
find /srv/sessions -type f -name 'sess-*' -mtime +1 | wc -l      # ~980
sudo find /srv/sessions -type f -name 'sess-*' -mtime +1 -delete
df -i /srv/sessions
ls /srv/sessions | grep -c sess-live   # 15
```

Con muchos ficheros, `rm sess-old-*` puede fallar con "Argument list too long".
`find -delete` no tiene ese problema.

## 5. Que no se repita: logrotate

```bash
sudo tee /etc/logrotate.d/app >/dev/null <<'EOF'
/var/log/app/*.log {
    daily
    rotate 7
    maxsize 20M
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF
sudo logrotate -d /etc/logrotate.d/app     # ensayo, sin tocar nada
```

`copytruncate` copia y luego vacía el fichero original, así el demonio sigue
escribiendo en el mismo fd. Si el servicio sabe reabrir sus logs (con
`SIGHUP` o `systemctl reload`), es mejor un `postrotate` que se lo pida: con
`copytruncate` se pueden perder las líneas escritas entre la copia y el vaciado.

En un servidor real, añade también limpieza automática de sesiones (por
ejemplo, un `systemd-tmpfiles` con `d /srv/sessions 0755 orders orders 1d`).

## Lecciones

- `df -h` **y** `df -i`. Disco "lleno" puede ser de bytes o de inodos.
- Si `df` y `du` no cuadran, mira `lsof +L1`: borrar un log abierto no libera nada.
- Para vaciar un log que algo tiene abierto: `truncate -s 0` o `: > fichero`,
  nunca `rm`.
- Logs sin rotación son un incidente programado.
