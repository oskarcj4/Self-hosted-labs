# Día 08 — Usuario dedicado para un servicio

> 30 días de DevSecOps · Linux · Permisos e identidad de servicios

## Escenario

`reportd` genera informes de ventas cada pocos segundos y corre **como
root**. Si alguien explota un fallo en él, tendrá la máquina entera. Hay que
moverlo a su propia identidad sin privilegios… y sin que deje de funcionar.

Cuidado: todo lo que `reportd` usa hoy (datos, log y configuración) es de
root. Si sólo añades `User=` a la unidad, el servicio se cae.

## Objetivos

1. Crea un usuario **de sistema** `reportd` (uid < 1000), **sin shell de
   login** y fuera de grupos privilegiados.
2. Haz que `reportd.service` corra como ese usuario (`User=reportd`).
3. Ajusta lo que necesite para seguir funcionando:
   - escribir en `/var/lib/reportd/reports/` y en `/var/log/reportd/`,
   - leer `/etc/reportd/reportd.conf` (que no debe hacerse pública).
4. El servicio debe quedar activo, habilitado y sano:
   `curl http://127.0.0.1:8400/health` → `reportd ok user=reportd`.

## Comandos que te pueden servir

```bash
systemctl cat reportd ; ps -o user,pid,cmd -C reportd
sudo useradd --system --no-create-home --shell /usr/sbin/nologin reportd
sudo systemctl edit reportd            # crea un drop-in con [Service] User=...
sudo chown -R <usuario>:<grupo> <ruta>
sudo systemctl daemon-reload && sudo systemctl restart reportd
journalctl -u reportd -n 20 --no-pager # si no arranca, el motivo está aquí
curl -s http://127.0.0.1:8400/health
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
