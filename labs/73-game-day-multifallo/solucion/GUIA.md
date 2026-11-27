# Resolución guiada · Game day: varias averías a la vez

:::piensa El método es todo
Nadie te dice qué ni cuántas cosas están rotas; al cliente sólo le llega
"error interno". Cuando hay varias averías, cada una esconde a la siguiente:
arreglas una y aparece otra. El método es un bucle: **síntoma → log del
servicio → primer error concreto → arregla una cosa → verifica → vuelve al
síntoma**. No cierres hasta que el síntoma original desaparezca. Apunta la
hora de cada hallazgo (`date '+%H:%M'`): de ahí sale la cronología del
postmortem. Y corregir no es borrar: un cambio mal escrito se arregla, no se
deshace.
:::

**El plan:** repetir el bucle hasta que `/health` responda bien, y después
escribir el postmortem.

## Paso 1 · El síntoma y el primer error

**Objetivo:** pasar de "error interno" a un mensaje concreto.

:::pista Cómo hacerlo
```bash
curl -s http://127.0.0.1:8080/health
sudo journalctl -u tienda -n 20 --no-pager
```
`journalctl -u tienda` muestra los logs de ese servicio; `-n 20` las últimas
20 líneas y `--no-pager` las imprime sin abrir `less`.

**Qué deberías ver:** `503 error interno` y, en el log,
`[Errno 28] No space left on device` al escribir en `/srv/app/uploads`.
:::

## Paso 2 · ¿Qué llena el disco?

**Objetivo:** liberar espacio **sin** perder subidas de clientes.

**Pregúntate:** ¿qué hay ahí que no sea una subida de cliente?

:::pista Cómo hacerlo
```bash
df -h /srv/app/uploads
sudo du -sh /srv/app/uploads/* | sort -h | tail
```
`df` dice cuánto ocupa el sistema de ficheros (100 %); `du -sh` el tamaño de
cada cosa, y `sort -h` las ordena por tamaño.

**Qué deberías ver:** junto a los `pedido-*.pdf`, un `core.tienda.4127` de
20 MB. Un **core dump** es la copia de la memoria de un proceso que se
estrelló: útil para depurar, pero no pinta nada ahí. No lo borres (puede
hacer falta para investigar la caída): muévelo.
```bash
sudo mkdir -p /var/crash
sudo mv /srv/app/uploads/core.tienda.4127 /var/crash/
df -h /srv/app/uploads
ls /srv/app/uploads/pedido-*.pdf | wc -l
```
**Qué deberías ver:** espacio libre y las 10 subidas intactas. Vuelve al
síntoma: `curl` y `journalctl`. Sigue fallando, con otro error.
:::

## Paso 3 · El nombre de la base de datos

**Objetivo:** que la app encuentre la base por su nombre.

:::pista Cómo hacerlo
El log de `tienda` dice ahora
`PostgreSQL: psql: error: could not translate host name "db.interno" to address`.
`psql` tiene que averiguar la IP del nombre **antes** de intentar conectar, así
que este es el error que ves primero, aunque haya más cosas rotas detrás. La app conecta a la base por
ese nombre, y el sistema no sabe a qué IP corresponde:
```bash
getent hosts db.interno
```
`getent hosts` resuelve un nombre igual que lo haría la app: mira
`/etc/hosts` y luego DNS. Si no imprime nada, no resuelve.

La base corre en esta misma máquina. El alias se perdió de `/etc/hosts`:
```bash
echo '127.0.0.1 db.interno' | sudo tee -a /etc/hosts
getent hosts db.interno
curl -s http://127.0.0.1:8080/health
```
`tee -a` **añade** al final del fichero (sin `-a`, lo sustituiría entero).

**Qué deberías ver:** `getent` ya devuelve `127.0.0.1 db.interno`, pero
`/health` sigue en 503. Vuelve al log: el error ha cambiado a
`Connection refused`. Ahora el nombre resuelve, pero nadie escucha en el 5432.
:::

## Paso 4 · La base de datos

**Objetivo:** encontrar por qué PostgreSQL no acepta conexiones.

:::pista Cómo hacerlo
```bash
systemctl status postgresql --no-pager
systemctl status postgresql@15-main --no-pager
```
En Debian, `postgresql.service` es sólo un **envoltorio** que arranca los
clústeres; siempre dice `active (exited)`. El que de verdad corre la base es
`postgresql@<versión>-<clúster>`, aquí `postgresql@15-main`. La `@` indica una
unidad *plantilla*: la misma definición para cada clúster.

**Qué deberías ver:** `postgresql@15-main` en `failed`. ¿Por qué?
```bash
sudo tail -n 10 /var/log/postgresql/postgresql-15-main.log
```
`invalid value for parameter "shared_buffers": "256MBB"`: una errata en un
cambio de configuración (CHG-7301). El cambio tenía un objetivo (darle más
memoria a la base), así que no se borra: se corrige.
```bash
grep -rn shared_buffers /etc/postgresql/15/main/conf.d/
sudo sed -i 's/^shared_buffers = 256MBB/shared_buffers = 256MB/' /etc/postgresql/15/main/conf.d/50-tuning.conf
sudo systemctl restart postgresql@15-main
sudo -u postgres psql -XAtc 'SHOW shared_buffers'
```
`sudo -u postgres psql` entra como el usuario administrador de la base; `-c`
ejecuta una consulta y `-XAt` quita formato para que salga sólo el valor.

**Qué deberías ver:** `256MB`. Vuelve al síntoma:
```bash
curl -s http://127.0.0.1:8080/health
```
`tienda ok (240 productos)`. El síntoma original ha desaparecido.
:::

## Paso 5 · El postmortem

**Objetivo:** `~/postmortem.md` con las cinco secciones y las **tres** causas.

:::pista Cómo hacerlo
Usa tus horas reales. Ejemplo de estructura:
```markdown
# Postmortem — Game day app-05

## Resumen
503 en la tienda por tres fallos encadenados: volumen de subidas lleno por un
core dump, el alias db.interno ausente de /etc/hosts y PostgreSQL caído por la
errata shared_buffers = 256MBB (CHG-7301).

## Cronología
- 10:05 journal de tienda: "No space left on device" en /srv/app/uploads.
- 10:08 core.tienda.4127 (20 MB) movido a /var/crash.
- 10:12 "could not translate host name db.interno". Alias restaurado en /etc/hosts.
- 10:18 "Connection refused": postgresql@15-main failed por shared_buffers=256MBB. Corregido y reiniciado.
- 10:22 /health responde: tienda ok.

## Impacto
~20 min sin tienda. Sin pérdida de datos: las subidas se conservaron.

## Causa raíz
1. Core dump escrito en el directorio de la app, sin límite.
2. Cambio de configuración aplicado sin validar.
3. /etc/hosts regenerado fuera del aprovisionamiento.

## Acciones
- Core dumps fuera de /srv (kernel.core_pattern o LimitCORE=0).
- Validar la configuración de PostgreSQL antes de aplicarla.
- /etc/hosts gestionado por el aprovisionamiento.
- Alertas de disco al 80 % y de servicios en failed.
```
:::

## Comprueba

```bash
curl -s http://127.0.0.1:8080/health
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Varias averías a la vez son normales:** no cierres hasta que el síntoma
  original desaparezca.
- Lee siempre **el log del servicio afectado** antes de tocar nada.
- **Corregir no es borrar:** respeta el objetivo del cambio que falló.
- **Postmortem sin culpables:** causas en sistemas y procesos, acciones con
  responsable.

## Si te atascas

- **`check.sh` falla por el postmortem:** te falta una sección o una de las
  tres causas.
- **`systemctl status postgresql` dice `active` y la app no conecta:** mira
  `postgresql@15-main`.
- **Faltan subidas de clientes:** borraste de más en `uploads`. Lo único que
  sobraba era el core dump.
