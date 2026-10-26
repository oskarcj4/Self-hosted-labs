# Resolución guiada · Logs centralizados con rsyslog

:::piensa Antes de tocar nada
Dos máquinas: `log-01` (colector, esta terminal) y `web-02` (emisor, por SSH).
El problema de fondo: el emisor manda por **UDP** (`@`), que tira paquetes en
silencio si el colector no está — esos son los 40 minutos perdidos. La solución:
colector escuchando **TCP 514** con un ruleset propio, y emisor por **TCP con
cola en disco y reintentos infinitos**. Valida siempre con `rsyslogd -N1` antes
de reiniciar.
:::

## Paso 1 · Diagnóstico

```bash
ss -ltnup | grep 514                       # nada: log-01 no escucha en red
ssh admin@web-02 cat /etc/rsyslog.d/90-remoto.conf
# *.* @log-01:514    <- "@" = UDP, sin cola
```

## Paso 2 · El colector (log-01)

**Pregúntate:** ¿cómo separo los logs remotos de `/var/log/syslog` y hago un
fichero por máquina/programa?

:::pista `/etc/rsyslog.d/10-colector.conf`
```
module(load="imtcp")
template(name="PorHost" type="string"
         string="/var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log")
ruleset(name="remoto") {
    action(type="omfile" dynaFile="PorHost" createDirs="on")
    stop
}
input(type="imtcp" port="514" ruleset="remoto")
```
```bash
sudo rsyslogd -N1 && sudo systemctl restart rsyslog
ss -ltn | grep 514
```
- El **ruleset** aísla la entrada remota: no pasa por las reglas por defecto
  que escriben `/var/log/syslog`. El `stop` lo blinda.
- `dynaFile` + plantilla = un fichero por máquina y programa, sin reglas a mano.
- Producción: TLS (`gtls`) y restringe emisores (`$AllowedSender`/firewall).
:::

## Paso 3 · El emisor (web-02): TCP + cola en disco + reintentos

**Pregúntate:** ¿qué hace que, si log-01 cae, al volver llegue **todo**?

:::pista `/etc/rsyslog.d/90-remoto.conf` en web-02
```bash
ssh admin@web-02
sudo mkdir -p /var/spool/rsyslog
sudo tee /etc/rsyslog.d/90-remoto.conf <<'EOF'
action(type="omfwd" target="log-01" port="514" protocol="tcp"
       queue.type="LinkedList" queue.filename="fwd_log01"
       queue.maxDiskSpace="200m" queue.saveOnShutdown="on"
       action.resumeRetryCount="-1" action.resumeInterval="5")
EOF
sudo rsyslogd -N1 && sudo systemctl restart rsyslog
logger -t prueba "hola colector"
```
- `protocol="tcp"`: el emisor sabe si el mensaje salió (UDP no).
- `queue.filename`: la cola se vuelca a disco (sin él, sólo memoria);
  `saveOnShutdown` la guarda al apagar.
- `action.resumeRetryCount="-1"`: reintenta **para siempre** (por defecto
  descarta tras pocos fallos).
- Cola **propia** de la acción: si el colector cae, sólo se atasca el reenvío;
  los logs locales de web-02 siguen.
:::

## Paso 4 · Prueba de caída

```bash
sudo systemctl stop syslog.socket rsyslog     # en log-01
sleep 20
sudo systemctl start rsyslog
sudo grep -o 'pedido=[0-9]*' /var/log/remote/web-02/pagos-web.log | tail -30   # sin saltos
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **UDP para logs = pérdidas silenciosas.** TCP + cola en disco + reintentos.
- **Logs remotos por máquina y programa**, separados de los locales (ruleset).
- **Centralizar es seguridad**: quien borra los logs locales (lab 09) no borra
  los ya enviados.
- **Valida antes de reiniciar**: `rsyslogd -N1`.

## Si te atascas

- `ss` no muestra 514 → falta `module(load="imtcp")` o el `input`.
- Los remotos aparecen en `/var/log/syslog` → falta el ruleset/`stop`.
- Hay huecos tras la caída → el emisor sigue en UDP o sin `queue.filename` /
  `resumeRetryCount="-1"`.
