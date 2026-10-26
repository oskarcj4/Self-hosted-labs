# Resolución guiada · Game day: varias averías a la vez

:::piensa Antes de tocar nada
Simulacro SEV1. Nadie te dice qué ni cuántas cosas están rotas; al cliente sólo
le llega "error interno". El **método** es todo: síntoma → log del servicio →
arregla **una** cosa → verifica → vuelve al síntoma. Un fallo esconde al
siguiente, así que no declares resuelto hasta que el 503 original desaparezca.
Apunta la hora de cada hallazgo: de ahí sale la cronología del postmortem. Y
corregir **no** es borrar: un cambio mal escrito se arregla, no se deshace.
:::

## Paso 1 · Avería 1 — volumen de subidas lleno

**Pregúntate:** ¿qué dice el primer error del log de `tienda`?

:::pista Cómo verlo y arreglarlo
```bash
sudo journalctl -u tienda -n 5 --no-pager      # [Errno 28] No space left on device
df -h /srv/app/uploads                          # 100%
sudo du -sh /srv/app/uploads/* | sort -h | tail
# 20M core.tienda.4127  <- un core dump, NO una subida de cliente
sudo mkdir -p /var/crash && sudo mv /srv/app/uploads/core.tienda.4127 /var/crash/
ls /srv/app/uploads/pedido-*.pdf | wc -l        # 10 intactas
```
Postmortem: los core dumps no deben caer en el dir de trabajo
(`systemd-coredump`, `kernel.core_pattern`, o `LimitCORE=0`).
:::

## Paso 2 · Avería 2 — PostgreSQL no arranca

**Pregúntate:** el siguiente error apunta a la BD. ¿Qué cluster falla de verdad?

:::pista Cómo verlo y arreglarlo
```bash
systemctl status postgresql           # active (exited): es sólo un envoltorio, ¡engaña!
systemctl status postgresql@15-main   # failed
sudo tail -n 5 /var/log/postgresql/postgresql-15-main.log
# invalid value for parameter "shared_buffers": "256MBB"
```
Corrige la errata **sin** quitar el cambio (CHG-7301 tenía un objetivo):
```bash
sudo sed -i 's/^shared_buffers = 256MBB/shared_buffers = 256MB/' \
  /etc/postgresql/15/main/conf.d/50-tuning.conf
sudo systemctl restart postgresql@15-main
sudo -u postgres psql -XAtc 'SHOW shared_buffers'    # 256MB
```
Postmortem: validar config antes de reiniciar en producción.
:::

## Paso 3 · Avería 3 — db.interno no resuelve

**Pregúntate:** ¿resuelve el nombre que usa la app?

:::pista Cómo verlo y arreglarlo
```bash
getent hosts db.interno                 # (nada)
echo '127.0.0.1 db.interno' | sudo tee -a /etc/hosts
curl -s http://127.0.0.1:8080/health    # tienda ok (240 productos)
```
Aquí `/etc/hosts` **sí** es correcto: alias local que mantiene el
aprovisionamiento. Postmortem: que no se pierda al regenerar el fichero.
:::

## Paso 4 · El postmortem (`~/postmortem.md`)

Secciones obligatorias: `## Resumen`, `## Cronología`, `## Impacto`,
`## Causa raíz`, `## Acciones`. Menciona **todas** las causas. Ejemplo de
cronología (con tus horas reales):
```markdown
## Cronología
- 10:05 journal de tienda: "No space left on device" en /srv/app/uploads.
- 10:08 core.tienda.4127 (20 MB) movido a /var/crash.
- 10:12 postgresql@15-main failed: shared_buffers='256MBB'. Corregido, reiniciado.
- 10:20 "could not translate host name db.interno". Alias restaurado.
- 10:22 /health 200.
## Causa raíz
1. Core dump en el dir de trabajo (sin límite).
2. Config aplicada sin validar (errata de unidad).
3. /etc/hosts regenerado fuera del aprovisionamiento.
## Acciones
- [ ] core_pattern fuera de /srv. [ ] Validar config PG en CI.
- [ ] /etc/hosts gestionado. [ ] Alertas de disco 80% y de servicios failed.
```

## Verifica

```bash
curl -s http://127.0.0.1:8080/health     # tienda ok (240 productos)
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Varias averías a la vez son normales**: no cierres hasta que el síntoma
  original desaparezca.
- **`postgresql.service` es un envoltorio** en Debian/Ubuntu; el real es
  `postgresql@<versión>-<cluster>`.
- **Corregir no es borrar**: respeta el objetivo del cambio.
- **Postmortem sin culpables**: causas en sistemas y procesos, acciones con
  responsable.

## Si te atascas

- `check.sh` falla por el postmortem → te falta una sección o una causa.
- `systemctl status postgresql` dice "active" y la app no conecta → mira
  `postgresql@15-main`.
