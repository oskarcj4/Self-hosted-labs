# Resolución guiada · Cron que no se ejecuta

:::piensa Antes de tocar nada
"A mano funciona" no dice nada: cron corre con **otro entorno** (PATH mínimo,
sin tu shell ni tus variables) y la salida se va al correo, que aquí se pierde.
Hay cinco tareas y cada una falla por un motivo **distinto**. Deja abierto en
otra pestaña `sudo journalctl -u cron -f`: cron avisa de casi todo, pero no de
todo.
:::

## Paso 1 · limpieza-tmp — falta el campo usuario

**Pregúntate:** en `/etc/cron.d/`, ¿cuántos campos lleva la línea?

:::pista El fallo y el arreglo
Seis: el sexto es el **usuario**. Sin él, cron toma el script como usuario y se
queda sin comando.
```
# journal: ERROR (Syntax error, this crontab file will be ignored)
* * * * * root /usr/local/bin/limpieza-tmp.sh
```
(En `crontab -e` de un usuario **no** va ese campo. Mezclar los dos formatos es
el error típico.)
:::

## Paso 2 · informe.diario — el nombre del fichero

**Pregúntate:** ¿por qué este fichero no sale ni en el journal?

:::pista El fallo
cron **ignora en silencio** los ficheros de `/etc/cron.d/` cuyo nombre tenga un
punto (evita `.bak`, `.dpkg-old`, `~`...). Sin mensaje.
```bash
sudo mv /etc/cron.d/informe.diario /etc/cron.d/informe-diario
```
:::

## Paso 3 · metricas — el PATH de cron

**Pregúntate:** el comando a secas, ¿está en `/usr/bin:/bin`?

:::pista El fallo
cron usa `PATH=/usr/bin:/bin`; el script vive en `/usr/local/bin`. El error va
al correo perdido; el journal sólo dice `No MTA installed, discarding output`.
```
* * * * * root /usr/local/bin/metricas-push
```
(O una línea `PATH=/usr/local/bin:/usr/bin:/bin` al inicio del fichero.)
:::

## Paso 4 · backup-db — el `%`

**Pregúntate:** ¿qué significa `%` en crontab?

:::pista El fallo
`%` = **salto de línea** (lo que sigue se pasa como stdin). Rompe el `$(date +%F)`.
```
* * * * * root /usr/local/bin/backup-db.sh > /var/log/backup-db-$(date +\%F).log 2>&1
```
Escapa el `%` como `\%` (o mete la redirección dentro del script).
:::

## Paso 5 · sync-catalogo — dos fallos a la vez

**Pregúntate:** ¿termina el fichero en salto de línea? ¿el script es ejecutable?

:::pista El fallo
```bash
cat -A /etc/cron.d/sync-catalogo        # última línea sin '$' al final
ls -l /usr/local/bin/sync-catalogo.sh   # -rw-r--r-- (no ejecutable)
```
- Sin newline final, cron ignora **el fichero entero**
  (`Missing newline before EOF ...`).
- Y el script no es ejecutable (`Permission denied`, al correo perdido).
```bash
echo | sudo tee -a /etc/cron.d/sync-catalogo >/dev/null
sudo chmod 0755 /usr/local/bin/sync-catalogo.sh
```
:::

## Verifica

```bash
watch -n5 'ls -l --time-style=+%T /var/lib/heartbeat/; ls /var/log/backup-db-*'
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **"A mano funciona" no cuenta**: cron tiene otro PATH, HOME y shell.
- **La salida de cron va al correo**: sin MTA se pierde; redirige a un log
  (`>> /var/log/x.log 2>&1`) o usa `MAILTO=`.
- **`/etc/cron.d/` tiene 6 campos** (usuario); el `crontab -e` de usuario, 5.
- **Nombre sin puntos, newline final, script ejecutable, `%` escapado.**
- Para tareas nuevas, valora **timers de systemd**: logs al journal,
  `list-timers`, `Persistent=true`, sin estas trampas.

## Si te atascas

- Un fichero no corre y no sale en el journal → nombre con punto/caracter raro.
- Corre pero no deja nada → PATH (comando sin ruta absoluta) o falta `+x`.
- `backup-db-*.log` no aparece → `%` sin escapar.
