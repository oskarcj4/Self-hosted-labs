# Resolución guiada · Lab 06

:::piensa Antes de tocar nada
Cron no es el único reloj de Linux. Con systemd, un `.timer` dispara un `.service` cada cierto tiempo, y parece tan "del sistema" como cualquier otro. Tu pregunta guía: **¿qué unidades puso alguien a mano?**
:::

## Paso 1 · ¿Qué se ejecuta periódicamente?

**Pregúntate:** ¿cómo listo todos los timers, activos o no?

**Por qué importa:** es el equivalente moderno de revisar el crontab.

:::pista Cómo comprobarlo
```bash
systemctl list-timers --all
```
Los timers del sistema tienen nombres conocidos (`apt-daily`, `logrotate`, `fstrim`…). ¿Cuál no te suena y se dispara muy a menudo?
:::

## Paso 2 · ¿Qué lanza y desde dónde?

**Pregúntate:** un timer sólo dice *cuándo*. ¿Qué *servicio* activa y qué ejecuta ese servicio?

**Por qué importa:** el `ExecStart` del servicio es el payload. Y la ruta del fichero de unidad te dice si lo puso un paquete o una persona.

:::pista Cómo comprobarlo
```bash
systemctl cat <nombre>.timer
systemctl cat <nombre>.service
```
La primera línea de `systemctl cat` es la ruta del fichero. `/lib/systemd/system` = paquete; `/etc/systemd/system` = alguien lo creó. Mira el `ExecStart` y lee el script que lanza.
:::

## Paso 3 · Para y deshabilita

**Pregúntate:** ¿qué diferencia hay entre `stop` y `disable`? Uno para ahora; el otro evita que arranque al boot. Quieres los dos.

:::pista Cómo hacerlo
```bash
sudo systemctl disable --now <nombre>.timer <nombre>.service
```
Para primero el **timer** (el que relanza) y después el servicio.
:::

## Paso 4 · Borra y recarga

**Pregúntate:** si borro los ficheros, ¿systemd se entera solo? No: tiene la configuración en memoria hasta que recargas.

:::pista Cómo hacerlo
```bash
sudo rm -f /etc/systemd/system/<nombre>.service /etc/systemd/system/<nombre>.timer
sudo systemctl daemon-reload
systemctl list-timers --all | grep <nombre> || echo "sin rastro"
bash /opt/lab/check.sh
```
:::

## Cómo actuar en una situación así

- Persistencia moderna = **cron + systemd**. Revisa los dos siempre.
- `systemctl list-unit-files --state=enabled` y `ls -la /etc/systemd/system/` revelan lo añadido a mano.
- Orden: **timer → servicio → ficheros → daemon-reload**.
- Revisa también el script que ejecutaba: puede haber dejado otras cosas.

## Si te atascas

- No ves nada raro en `list-timers`: añade `--all` (incluye los inactivos).
- Tras borrar sigue saliendo: te falta `daemon-reload`.
