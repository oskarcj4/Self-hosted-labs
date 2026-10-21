# Solución — Logs centralizados con rsyslog

## 1. Diagnóstico

```bash
ss -ltnup | grep 514                  # nada: log-01 no escucha en la red
ssh admin@web-02 cat /etc/rsyslog.d/90-remoto.conf
# *.* @log-01:514                      <- "@" = UDP, sin cola
```

Con UDP, si el colector no está, los paquetes se tiran y nadie se entera. Eso
explica los 40 minutos perdidos. Y aunque log-01 escuchara UDP, una caída del
colector seguiría perdiendo mensajes.

## 2. El colector (log-01)

`/etc/rsyslog.d/10-colector.conf`:

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

Claves:

- El **ruleset** separa la entrada remota: los mensajes de `imtcp` sólo pasan
  por `remoto`, nunca por las reglas por defecto que escriben
  `/var/log/syslog`. El `stop` es por si alguien añade más acciones luego.
- `dynaFile` + plantilla = un fichero por máquina y programa, sin reglas a
  mano por cada servidor nuevo.
- En producción: TLS (`gtls`), y restringe quién puede enviar
  (`$AllowedSender` o firewall). Un colector abierto deja que cualquiera
  meta logs falsos.

## 3. El emisor (web-02)

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

- `protocol="tcp"`: el emisor sabe si el mensaje salió.
- `queue.type="LinkedList"` + `queue.filename`: cola en memoria que se vuelca
  a disco (`/var/spool/rsyslog`) cuando crece o al apagar
  (`saveOnShutdown`). Sin `queue.filename` sería sólo memoria.
- `action.resumeRetryCount="-1"`: reintenta para siempre. Por defecto
  rsyslog descarta la acción tras pocos fallos.
- Una cola **propia** de la acción: si el colector cae, sólo se atasca el
  reenvío; los logs locales de web-02 siguen escribiéndose.

## 4. Prueba de caída

```bash
sudo systemctl stop syslog.socket rsyslog       # en log-01
sleep 20
sudo systemctl start rsyslog
sudo grep -o 'pedido=[0-9]*' /var/log/remote/web-02/pagos-web.log | tail -30
# números seguidos, sin saltos
```

## Lecciones

- UDP para logs = pérdidas silenciosas. TCP + cola en disco + reintentos.
- Logs remotos por máquina y programa, separados de los locales.
- Centralizar logs es seguridad: un atacante que borra los locales (lab 09)
  no puede borrar los que ya salieron.
- Valida antes de reiniciar: `rsyslogd -N1`.
