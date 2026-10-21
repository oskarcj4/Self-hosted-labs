# Resolución guiada · Lab 02

:::piensa Antes de tocar nada
El enunciado te avisa: si matas el proceso, **vuelve**. Eso significa que hay algo que lo relanza. Antes de disparar, pregúntate: ¿quién lo arranca? Matar un proceso con persistencia activa es achicar agua sin tapar el agujero.
:::

Orden mental: **ver → identificar → desarmar la persistencia → matar → borrar → esperar y confirmar**.

## Paso 1 · ¿Qué está escuchando en el 4444?

**Pregúntate:** el panel de monitoreo dice "nadie conectado". ¿En qué fuente confías más, en el panel o en el kernel?

**Por qué importa:** `ss` pregunta directamente al kernel qué sockets existen y qué proceso es su dueño. Es mucho más difícil de falsificar que un panel.

:::pista Cómo comprobarlo
```bash
sudo ss -tulpn | grep 4444
```
La columna `users:((...))` te da el **nombre** y el **PID**. Apunta el PID.
:::

## Paso 2 · ¿Es lo que dice ser?

**Pregúntate:** el nombre del proceso suena oficial. ¿Puede un atacante ponerle a su programa el nombre que quiera? (Sí.) Entonces, ¿qué dato no puede falsificar tan fácilmente?

**Por qué importa:** la **ruta real del ejecutable** delata al impostor. Ningún servicio del sistema se ejecuta desde `/tmp`.

:::pista Cómo comprobarlo
```bash
ls -la /proc/<PID>/exe
cat /proc/<PID>/cmdline | tr '\0' ' '; echo
```
`/proc/<PID>/exe` es un enlace al binario que se está ejecutando. Si apunta a `/tmp/...`, tienes al impostor.
:::

## Paso 3 · ¿Quién lo resucita?

**Pregúntate:** ¿qué mecanismos de Linux ejecutan cosas periódicamente sin que nadie las lance? Piensa en cron (varios sitios) y en timers de systemd.

**Por qué importa:** este es **el paso clave**. Si no desarmas esto primero, todo lo demás se deshace en menos de un minuto.

:::pista Dónde buscar
```bash
ls -la /etc/cron.d/ /etc/cron.*/ 2>/dev/null
cat /etc/cron.d/*
cat /etc/crontab
sudo crontab -l
```
Busca una entrada con `* * * * *` (cada minuto) y un nombre "de mantenimiento" que ejecute un script raro. Lee el script que lanza: ¿qué hace?

Cuando lo tengas claro, borra esa entrada de cron.
:::

## Paso 4 · Ahora sí: proceso y binario

**Pregúntate:** ya no hay nada que lo relance. ¿Qué quedaba vivo y qué quedaba en disco?

:::pista Cómo hacerlo
```bash
sudo kill -9 <PID>
sudo rm -f <ruta-del-binario-en-/tmp>
```
:::

## Paso 5 · Espera y confirma

**Pregúntate:** ¿cómo sabes que no vuelve? Sólo hay una forma: esperar más que el intervalo de la persistencia y volver a mirar.

:::pista Cómo comprobarlo
```bash
sleep 65
sudo ss -tulpn | grep 4444 || echo "puerto cerrado"
pgrep -af system-update || echo "no ha vuelto"
bash /opt/lab/check.sh
```
:::

## Cómo actuar en una situación así

- **Persistencia → proceso → binario.** Si lo haces al revés, juegas al topo.
- **El nombre del proceso no es identidad.** Mira `/proc/PID/exe`, el `cmdline` y quién es su padre (`ps -o ppid= -p PID`).
- **Revisa todos los sitios de cron**: `/etc/crontab`, `/etc/cron.d/`, `/etc/cron.{hourly,daily}`, `crontab -l` de cada usuario, y `systemctl list-timers`.
- En un caso real, además **bloquea el destino** en el firewall y busca la IP remota en otros servidores.

## Si te atascas

- El proceso vuelve: aún queda persistencia. Repite el paso 3 y busca también en `crontab -l -u root`.
- `ss` no muestra el proceso: te falta `sudo`.
