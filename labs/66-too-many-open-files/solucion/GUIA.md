# Resolución guiada · Too many open files

:::piensa Antes de tocar nada
`ulimit -n` dice 65535 y aun así el servicio cae por `EMFILE`. La clave: el
límite que importa es el del **proceso** (`/proc/PID/limits`), y un servicio de
systemd **no** hereda `/etc/security/limits.conf` (eso es PAM, para sesiones
login/ssh/sudo). systemd toma el límite de la unit (`LimitNOFILE=`). Por eso tu
shell y el servicio ven números distintos.
:::

## Paso 1 · El error

```bash
sudo journalctl -u ingest -n 5 --no-pager
# [Errno 24] Too many open files   (al abrir el lote 62: stdin/out/err también cuentan)
```

## Paso 2 · El límite real del proceso

**Pregúntate:** ¿qué `LimitNOFILE` tiene la unit, y qué ve el proceso vivo?

:::pista Cómo comprobarlo
```bash
systemctl show -p LimitNOFILE ingest        # 64
cat /proc/$(systemctl show -p MainPID --value ingest)/limits | grep 'open files'   # 64 64
```
:::

:::pista Por qué `limits.conf` no sirvió
`/etc/security/limits.conf` lo aplica **PAM** al abrir sesión (`login`, `ssh`,
`su`, `sudo`). Por eso `sudo -u ingest bash -c 'ulimit -n'` da 65535. Pero
systemd arranca los servicios **sin PAM**: el límite sale de la unit
(`LimitNOFILE=`) o de `DefaultLimitNOFILE=` en `/etc/systemd/system.conf`.
:::

## Paso 3 · Arréglalo con drop-in

**Pregúntate:** ¿cómo subo a 4096 sin tocar la unit original? `systemctl edit`.

:::pista Cómo hacerlo
```bash
sudo systemctl edit ingest
```
```ini
[Service]
LimitNOFILE=4096
```
```bash
sudo systemctl restart ingest     # 'edit' hace daemon-reload; el proceso viejo no cambia solo
systemctl show -p LimitNOFILE ingest
cat /proc/$(systemctl show -p MainPID --value ingest)/limits | grep 'open files'   # 4096
sudo ls /proc/$(systemctl show -p MainPID --value ingest)/fd | wc -l               # ~505
curl -s http://127.0.0.1:8600/health       # ingest ok 500 lotes
```
No uses `infinity`: esconde fugas de descriptores hasta agotar `fs.file-max`.
Limpia la entrada inútil de `limits.conf` (o comenta que no aplica a systemd).
:::

## Paso 4 · Verifica

```bash
systemctl show -p LimitNOFILE,ActiveState,NRestarts ingest
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **El límite que importa es el del proceso**: `/proc/PID/limits`. Ni tu
  `ulimit -n` ni `limits.conf` describen un servicio de systemd.
- **Emergencia sin reiniciar**: `prlimit --pid PID --nofile=4096:4096` (no
  persiste).
- **`infinity`/1M "por si acaso"** oculta fugas de fd.
- **Monitoriza** `ls /proc/PID/fd | wc -l` frente al límite: si sube sin parar,
  es fuga, no falta de límite.

## Si te atascas

- Cambiaste el límite y sigue 64 → no reiniciaste el servicio (el proceso viejo
  conserva su límite).
- `limits.conf` no surte efecto → correcto: no aplica a systemd; usa
  `LimitNOFILE` en un drop-in.
