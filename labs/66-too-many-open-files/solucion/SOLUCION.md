# Solución — Too many open files

## 1. El error

```bash
sudo journalctl -u ingest -n 5 --no-pager
# FATAL: no puedo abrir /srv/ingest/inbox/lote-062.json (llevo 61 abiertos): [Errno 24] Too many open files
```

`EMFILE` (errno 24): el **proceso** llegó a su límite de descriptores. Llegó
a 61 lotes porque stdin, stdout y stderr también cuentan.

## 2. ¿Qué límite tiene de verdad?

```bash
systemctl show -p LimitNOFILE ingest        # LimitNOFILE=64
systemctl cat ingest | grep Limit           # LimitNOFILE=64  (plantilla de 2019)
```

Mientras está vivo (entre reinicios), `/proc` muestra el límite del proceso:

```bash
cat /proc/$(systemctl show -p MainPID --value ingest)/limits | grep 'open files'
# Max open files            64                   64                   files
```

### ¿Por qué no sirvió `limits.conf`?

`/etc/security/limits.conf` lo aplica **PAM** (`pam_limits`) al abrir una
sesión: `login`, `ssh`, `su`, `sudo`. Por eso `sudo -u ingest bash -c
'ulimit -n'` dice 65535. Pero systemd arranca los servicios **sin PAM**: sus
límites salen de la unit (`LimitNOFILE=`) o de `DefaultLimitNOFILE=` en
`/etc/systemd/system.conf`.

## 3. El arreglo: un drop-in

```bash
sudo systemctl edit ingest
```

```ini
[Service]
LimitNOFILE=4096
```

```bash
sudo systemctl restart ingest       # 'edit' ya hace daemon-reload; el proceso viejo no cambia solo
systemctl show -p LimitNOFILE ingest
cat /proc/$(systemctl show -p MainPID --value ingest)/limits | grep 'open files'
sudo ls /proc/$(systemctl show -p MainPID --value ingest)/fd | wc -l     # ~505
curl -s http://127.0.0.1:8600/health       # ingest ok 500 lotes
```

Y limpia la entrada inútil de `limits.conf` (o deja un comentario que diga que
no aplica a systemd), para que el siguiente no se lleve el mismo engaño.

## Lecciones

- El límite que importa es el del **proceso**: `/proc/PID/limits`. Ni tu
  `ulimit -n` ni `limits.conf` describen un servicio de systemd.
- Para un proceso ya en marcha sin reiniciar: `prlimit --pid PID
  --nofile=4096:4096` (útil en una emergencia; no es persistente).
- `infinity` o 1M "para no volver a tener el problema" esconde fugas de
  descriptores hasta que agotan el límite del sistema (`fs.file-max`).
- Monitoriza los descriptores abiertos (`ls /proc/PID/fd | wc -l`) frente al
  límite: si suben sin parar, es una fuga, no falta de límite.
