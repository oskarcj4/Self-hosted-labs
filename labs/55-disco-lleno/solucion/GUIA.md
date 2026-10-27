# Resolución guiada · Disco lleno (y no sólo de bytes)

:::piensa Antes de tocar nada
"Disco lleno" tiene dos caras: **bytes** y **inodos**. Un disco con 100 % de
inodos da "No space left on device" aunque esté casi vacío de datos. Aquí
fallan los dos, en montajes distintos. No lances `rm -rf`: borrarías las
sesiones vivas. Mide primero, borra después.
:::

## Paso 1 · ¿Qué está lleno: bytes o inodos?

**Pregúntate:** `df -h` mide bytes; `df -i` mide inodos. ¿Cuál está al 100 %?

:::pista Cómo comprobarlo
```bash
df -h /var/log/app /srv/sessions     # bytes
df -i /var/log/app /srv/sessions     # inodos (IUse%)
```
`/var/log/app` → 100 % de bytes. `/srv/sessions` → 100 % de inodos con el
disco casi vacío: cada fichero gasta un inodo aunque pese 0.
:::

## Paso 2 · Bytes que se ven con `du`

**Pregúntate:** ¿qué ficheros pesan en `/var/log/app`?

```bash
sudo du -xah /var/log/app | sort -h | tail -5
```

`orders.log.1` (un rotado sin comprimir) pesa ~58 MB. Es historia:

```bash
sudo rm /var/log/app/orders.log.1
df -h /var/log/app      # baja... pero sigue alto. Falta algo.
```

## Paso 3 · Bytes que NO se ven con `du`

**Pregúntate:** `df` dice lleno y `du` no lo suma. ¿Dónde están esos bloques?
En un fichero **borrado pero aún abierto** por un proceso: ya no tiene nombre
(no sale en `du`), pero sus bloques siguen ocupados hasta que se cierre el fd.

:::pista Cómo encontrarlo
```bash
sudo lsof -nP +L1     # +L1 = ficheros con 0 enlaces (borrados) todavía abiertos
# trace-col PID ... 3w REG ... 41943040 ... /var/log/app/debug-trace.log (deleted)
```
Libéralo **sin matar el servicio**:
```bash
sudo systemctl restart trace-collector     # cierra el fd y abre uno nuevo
# o, sin reiniciar, vacía por el fd:
sudo truncate -s 0 /proc/PID/fd/3
```
:::

## Paso 4 · Inodos: borrar sólo lo caducado

**Pregúntate:** ¿cómo borro las sesiones viejas sin tocar las vivas
(`sess-live-*`)? Por antigüedad, no por comodín.

:::pista Cómo hacerlo
```bash
find /srv/sessions -type f -name 'sess-*' -mtime +1 | wc -l    # ~980 caducadas
sudo find /srv/sessions -type f -name 'sess-*' -mtime +1 -delete
df -i /srv/sessions
ls /srv/sessions | grep -c sess-live     # las vivas siguen (15)
```
`find -delete` evita el "Argument list too long" que da `rm sess-old-*` con
miles de ficheros.
:::

## Paso 5 · Que no se repita: logrotate

**Pregúntate:** ¿cómo evito volver a llenar `/var/log/app`? Rotando y
comprimiendo, y haciendo que el demonio suelte el fichero viejo.

:::pista Cómo hacerlo
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
sudo logrotate -d /etc/logrotate.d/app     # ensayo en seco, no toca nada
```
`copytruncate` copia y vacía el original, así el proceso sigue escribiendo en
el mismo fd. Si el servicio sabe reabrir sus logs (`SIGHUP`/`reload`), un
`postrotate` es mejor: con `copytruncate` se pueden perder las líneas escritas
entre la copia y el vaciado.
:::

## Paso 6 · Verifica

```bash
df -h /var/log/app ; df -i /srv/sessions          # ambos < 50 %
sudo lsof -nP +L1 | grep /var/log/app || echo "sin borrados-abiertos"
curl -i http://127.0.0.1:8080/health              # 200
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Siempre `df -h` y `df -i`.** Lo "lleno" puede ser de inodos.
- **Si `df` y `du` no cuadran**, mira `lsof +L1`: borrar un log abierto no
  libera nada.
- **Para vaciar un log en uso**: `truncate -s 0` o `: > fichero`, nunca `rm`.
- **Logs sin rotación = incidente programado.** Y añade limpieza de sesiones
  (`systemd-tmpfiles`, p.ej. `d /srv/sessions 0755 orders orders 1d`).

## Si te atascas

- `df` sigue alto tras borrar: hay un borrado-abierto; `lsof +L1`.
- "Argument list too long": usa `find ... -delete`, no `rm comodín`.
- Borraste una sesión viva: filtra por `-mtime +1` y excluye `sess-live-*`.
