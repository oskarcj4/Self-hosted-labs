# Resolución guiada · Servicio en bucle de reinicios

:::piensa Antes de tocar nada
`Restart=always` no arregla un servicio que **no puede** arrancar: sólo
reintenta deprisa hasta que systemd se rinde (`start-limit-hit`). Deja de
reiniciar a ciegas y lee el journal. Puede haber **más de una** causa: arregla
la primera y vuelve a mirar.
:::

## Paso 1 · Lee por qué se cae (causa 1)

**Pregúntate:** ¿qué dice la última línea útil del journal?

:::pista Cómo comprobarlo
```bash
systemctl status payments-worker            # failed (resources), start-limit-hit
sudo journalctl -u payments-worker -n 20 --no-pager
# Failed to load environment files: No such file or directory
ls /etc/payments/     # payments.env, token  (worker.env ya no existe)
```
La unit carga un `EnvironmentFile` que ya no está.
:::

## Paso 2 · Corrige con drop-in (reemplazando el valor viejo)

**Pregúntate:** ¿cómo cambio el `EnvironmentFile` sin editar la unit original?
Con `systemctl edit`, vaciando primero la directiva repetible.

:::pista Cómo hacerlo
```bash
sudo systemctl edit payments-worker
```
```ini
[Service]
EnvironmentFile=
EnvironmentFile=/etc/payments/payments.env
```
La línea vacía **borra** el valor heredado; sin ella systemd seguiría cargando
el fichero viejo. No pongas la URL ni el token dentro de la unit.
```bash
sudo systemctl reset-failed payments-worker   # borra el contador de arranques
sudo systemctl start payments-worker
```
:::

## Paso 3 · Mira otra vez: el puerto ocupado (causa 2)

**Pregúntate:** arranca y vuelve a caer. ¿Nueva causa?

:::pista Cómo verlo
```bash
sudo journalctl -u payments-worker -n 5 --no-pager
# [Errno 98] Address already in use  (127.0.0.1:9090)
sudo ss -ltnp 'sport = :9090'          # users:(("python3",pid=123,...))
systemctl status 123                    # debug-9090.service (transitoria, "BORRAR")
```
Un `systemd-run` de depuración de hace semanas, aún vivo. Al ser transitoria,
pararla basta (no tiene fichero en disco, no vuelve):
```bash
sudo systemctl stop debug-9090
sudo systemctl reset-failed payments-worker
sudo systemctl restart payments-worker
```
:::

## Paso 4 · Verifica la estabilidad, no el instante

```bash
watch -n1 'systemctl show payments-worker -p ActiveState,NRestarts,MainPID'
curl -s http://127.0.0.1:9090/health
systemctl is-enabled payments-worker
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **`Restart=always` + `RestartSec=1` esconden el fallo.** Mira `NRestarts` y
  el journal, no sólo `active`.
- **`start-limit-hit`**: systemd se rindió. Arregla la causa → `reset-failed`
  → arranca.
- **Cambios a una unit en drop-in** (`systemctl edit`). Para reemplazar una
  directiva repetible (`EnvironmentFile`, `ExecStart`), vacíala primero.
- **`EnvironmentFile=-/ruta`** (con `-`) la hace opcional: aquí sería un error,
  arrancaría sin config.
- **"Address already in use"** → `ss -ltnp` → `systemctl status PID`.

## Si te atascas

- Sigue `start-limit-hit` → te falta `reset-failed` tras arreglar la causa.
- Arranca y recae → hay otra causa; `journalctl -u ... -n 5` otra vez.
