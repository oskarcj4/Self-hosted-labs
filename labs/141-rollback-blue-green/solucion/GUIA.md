# Resolución guiada · Lab 141

:::piensa Antes de tocar nada
El reloj corre: primero se para el sangrado (tráfico a blue), después se
arregla la causa (health check) y al final se deja el runbook. No
reinicies HAProxy: un `restart` corta todas las conexiones abiertas.
:::

## Paso 1 · ¿Quién responde y qué falla?

:::pista Cómo comprobarlo
```bash
curl -si http://127.0.0.1/api/checkout | head -5     # 500 y X-App-Version: 1.5.0
curl -s http://127.0.0.1:8002/health                  # green: 503
curl -s http://127.0.0.1:8001/health                  # blue: 200
```
Anota `version_mala=1.5.0` y `version_buena=1.4.0` en `~/incidente.txt`.
:::

## Paso 2 · ¿Por qué HAProxy cree que green está sano?

**Pregúntate:** ¿qué URL comprueba el health check y qué devuelve green ahí?

:::pista Cómo comprobarlo
`option httpchk GET /`: la portada de green da 200 aunque la base de datos
no case con la versión. Un health check útil prueba las dependencias.
:::

## Paso 3 · Rollback ya, por el socket

**Pregúntate:** `echo "set server shop/green state maint" | socat ...` dice
"Permission denied". ¿Por qué?

:::pista Cómo hacerlo
El socket es `level user` (sólo lectura). Cambia a `level admin` y haz
**reload** (no restart): el maestro de HAProxy conserva su PID.
```bash
sudo sed -i 's/level user/level admin/' /etc/haproxy/haproxy.cfg
sudo haproxy -c -f /etc/haproxy/haproxy.cfg && sudo systemctl reload haproxy
echo "set server shop/green state maint" | sudo socat stdio /run/haproxy/admin.sock
curl -si http://127.0.0.1/api/checkout | grep -i x-app-version   # 1.4.0
```
Con green en mantenimiento, el servidor `backup` (blue) recibe el tráfico.
:::

## Paso 4 · Health check de verdad

:::pista Cómo hacerlo
```text
backend shop
    option httpchk GET /health
    http-check expect status 200
```
`haproxy -c` y `systemctl reload haproxy`. Prueba con
`set server shop/green state ready`: en unos segundos green cae solo a DOWN.
:::

## Paso 5 · El runbook

**Pregúntate:** ¿cómo sabe el script que el rollback funcionó de verdad?

:::pista Cómo hacerlo
Que no se limite a enviar órdenes: que **compruebe** que el checkout
responde con `X-App-Version: 1.4.0` y salga con error si no. Usa
`set -euo pipefail` y órdenes que se puedan repetir (`state maint` dos
veces no rompe nada).
:::

## Cómo actuar en una situación así

- Rollback = mover tráfico. Mantén la versión anterior viva hasta que la
  nueva aguante un rato con tráfico real.
- El health check debe fallar cuando el servicio no sirve al usuario, pero
  no por una dependencia opcional (no tumbes todo porque caiga el caché).
- Ensaya el rollback en cada despliegue: cronométralo.

## Si te atascas

- `Permission denied` en el socket: `level admin` + reload.
- `systemctl restart` ya hecho: el check lo detecta. `reset` del lab y repite con reload.
- green sigue UP tras cambiar el check: ¿hiciste reload? `haproxy -c` debe pasar.
