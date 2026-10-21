# Disco lleno (y no sólo de bytes)

> Operaciones · df · du · lsof · inodos · logrotate

## Escenario

`stor-01` está dando errores: el `/health` del servicio `orders` devuelve 500
y los usuarios no pueden iniciar sesión. Lee `~/ticket/INC-3107.txt`.

Hay dos discos implicados:

| Punto de montaje | Qué guarda |
|---|---|
| `/var/log/app` | logs de `orders` y `trace-collector` |
| `/srv/sessions` | un fichero por sesión de usuario |

## Objetivos

1. `/var/log/app` por debajo del **50 %** de uso.
2. Ningún fichero **borrado pero abierto** ocupando espacio en `/var/log/app`.
3. `/srv/sessions` por debajo del **50 %** de inodos usados, **sin borrar las
   sesiones activas** (`sess-live-*`). Las sesiones de más de 1 día ya no sirven.
4. `orders` y `trace-collector` siguen en marcha, y `orders /health` responde 200.
5. Que no vuelva a pasar: una config de **logrotate** en `/etc/logrotate.d/`
   para `/var/log/app/*.log` con `rotate`, `compress` y una forma de que el
   demonio suelte el fichero viejo (`copytruncate` o `postrotate`).

## Comandos que te pueden servir

```bash
df -h /var/log/app /srv/sessions
df -i /var/log/app /srv/sessions        # inodos
sudo du -xah /var/log/app | sort -h | tail
sudo lsof -nP +L1                       # borrados pero abiertos
ls -l /proc/PID/fd/
find /srv/sessions -type f -mtime +1 | wc -l
curl -i http://127.0.0.1:8080/health
sudo logrotate -d /etc/logrotate.d/app  # ensayo en seco
```

> Cuidado con `rm -rf /srv/sessions/*`: borrarías también las sesiones activas.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
