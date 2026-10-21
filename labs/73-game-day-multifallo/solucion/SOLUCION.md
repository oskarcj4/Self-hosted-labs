# Solución — Game day: varias averías a la vez

El orden en que aparecen depende de qué comprueba la app primero. Lo
importante es el método: síntoma, log, un arreglo, verificar, repetir.

## Avería 1: el volumen de subidas, lleno

```bash
sudo journalctl -u tienda -n 5 --no-pager
# ERROR /health: [Errno 28] No space left on device
df -h /srv/app/uploads                   # 100%
sudo du -sh /srv/app/uploads/* | sort -h | tail -3
# 20M  core.tienda.4127
ls -l /srv/app/uploads/                 # core.tienda.<PID>: el core dump del crash de anoche
```

Un core dump **no** es una subida de un cliente. Si alguien lo necesita para
depurar el crash, muévelo antes de borrarlo:

```bash
sudo mkdir -p /var/crash && sudo mv /srv/app/uploads/core.tienda.4127 /var/crash/
# o, si no hay sitio en ningún otro lado:  sudo rm /srv/app/uploads/core.tienda.4127
ls /srv/app/uploads/pedido-*.pdf | wc -l    # 10: intactas
```

Acción para el postmortem: los core dumps no deben caer en el directorio de
trabajo de la app (`systemd-coredump`, o `kernel.core_pattern` a
`/var/crash`, o `LimitCORE=0`).

## Avería 2: PostgreSQL no arranca

```bash
sudo journalctl -u tienda -n 3 --no-pager
# PostgreSQL: psql: error: could not translate host name "db.interno" ...    (o "connection refused")
systemctl status postgresql
#   Active: active (exited)       <- ¡engaña! es sólo un envoltorio
systemctl status postgresql@15-main
#   Active: failed
sudo tail -n 5 /var/log/postgresql/postgresql-15-main.log
# LOG:  invalid value for parameter "shared_buffers": "256MBB"
# HINT:  Valid units for this parameter are "B", "kB", "MB", "GB", and "TB".
# FATAL: configuration file "/etc/postgresql/15/main/conf.d/50-tuning.conf" contains errors
```

Corrige la errata, **sin** quitar el cambio:

```bash
sudo sed -i 's/^shared_buffers = 256MBB/shared_buffers = 256MB/' /etc/postgresql/15/main/conf.d/50-tuning.conf
sudo systemctl restart postgresql@15-main
sudo -u postgres psql -XAtc 'SHOW shared_buffers'      # 256MB
```

Acción: validar la config **antes** de reiniciar en producción. Con
PostgreSQL, en un entorno de pruebas
(`postgres -C shared_buffers -c config_file=...`), o aplicando el cambio con
`ALTER SYSTEM` + `SELECT pg_reload_conf()` y revisando
`pg_settings.pending_restart` y `pg_file_settings.error`.

## Avería 3: db.interno no resuelve

```bash
sudo journalctl -u tienda -n 3 --no-pager
# could not translate host name "db.interno" to address: Name or service not known
getent hosts db.interno                  # (nada)
echo '127.0.0.1 db.interno' | sudo tee -a /etc/hosts
curl -s http://127.0.0.1:8080/health     # tienda ok (240 productos)
```

Aquí sí es correcto usar `/etc/hosts`: es un alias **local** que mantiene el
aprovisionamiento. La acción del postmortem es que el aprovisionamiento lo
vuelva a gestionar (que no se pierda al regenerar el fichero).

## El postmortem

```markdown
# Postmortem — Game day app-05 (2026-10-20)

## Resumen
La tienda devolvió 503 durante ~25 min por tres fallos independientes:
volumen de subidas lleno por un core dump, PostgreSQL caído por una errata en
CHG-7301 y el alias db.interno ausente de /etc/hosts.

## Cronología
- 10:02 Alerta: /health 503.
- 10:05 journal de tienda: "No space left on device" en /srv/app/uploads.
- 10:08 core.tienda.4127 (20 MB) movido a /var/crash. Siguiente error: BD.
- 10:12 postgresql@15-main failed: shared_buffers = '256MBB'. Corregido a 256MB, reiniciado.
- 10:20 "could not translate host name db.interno". Alias restaurado en /etc/hosts.
- 10:22 /health 200. Fin del impacto.

## Impacto
~20 min sin tienda (todas las peticiones 503). Ningún dato perdido: las 10
subidas de clientes intactas.

## Causa raíz
1. Core dump escrito en el directorio de trabajo de la app (sin límite).
2. Cambio de configuración aplicado sin validar (errata de unidad).
3. Regeneración de /etc/hosts fuera del aprovisionamiento.
Detección tardía: la app sólo dice "error interno" y no hay alertas de disco.

## Acciones
- [ ] core_pattern / systemd-coredump fuera de /srv (resp.: plataforma).
- [ ] Validar config de PostgreSQL en CI antes de aplicar (resp.: BD).
- [ ] /etc/hosts gestionado por el aprovisionamiento (resp.: plataforma).
- [ ] Alertas de disco al 80% y de servicios en estado failed (resp.: SRE).
```

## Lecciones

- Varias averías a la vez son normales: un fallo esconde el siguiente. No
  declares el incidente resuelto hasta que el síntoma original desaparezca.
- `postgresql.service` en Debian/Ubuntu es un envoltorio: el servicio real es
  `postgresql@<versión>-<cluster>`.
- Corregir no es borrar: el cambio CHG-7301 tenía un objetivo.
- Postmortem **sin culpables**: causas en los sistemas y en los procesos, y
  acciones con responsable.
