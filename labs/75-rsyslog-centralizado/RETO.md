# Logs centralizados con rsyslog

> Operaciones · rsyslog · TCP · colas en disco · dos máquinas

## Escenario

Estás en `log-01`, el colector central de logs. La auditoría de pagos dice
que aquí no hay **nada** de `web-02`, y que en la última caída del colector
se perdieron 40 minutos de logs. Lee `~/ticket/PROB-7515.txt`.

| Máquina  | IP          | Acceso                                  |
|----------|-------------|-----------------------------------------|
| `log-01` | 10.76.75.10 | esta terminal                           |
| `web-02` | 10.76.75.20 | `ssh admin@web-02` (contraseña `Web02-2026`, tiene sudo) |

## Objetivos

1. `log-01` recibe syslog por **TCP 514**.
2. Un fichero por máquina y programa: `/var/log/remote/<máquina>/<programa>.log`.
3. Los logs remotos **no** se mezclan con `/var/log/syslog` de `log-01`.
4. `web-02` envía por TCP con **cola en disco y reintentos infinitos**: si
   `log-01` cae, al volver llega todo. El validador lo tira 15 segundos y
   cuenta los `pedido=N` de `pagos-web` para ver si hay huecos.

## Comandos que te pueden servir

```bash
ls /etc/rsyslog.d/ ; cat /etc/rsyslog.conf
sudo rsyslogd -N1                      # valida la config sin aplicarla
sudo systemctl restart rsyslog
ss -ltnup | grep 514
sudo tail -f /var/log/remote/web-02/pagos-web.log
ssh admin@web-02
#   cat /etc/rsyslog.d/90-remoto.conf
#   logger -t prueba "hola colector"
```

Pistas: `module(load="imtcp")`, `input(... ruleset=...)`, `template(...)`
con `%HOSTNAME%` y `%PROGRAMNAME%`, `action(type="omfile" dynaFile=...)`;
en el emisor, `action(type="omfwd" ... queue.* action.resumeRetryCount=...)`.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
