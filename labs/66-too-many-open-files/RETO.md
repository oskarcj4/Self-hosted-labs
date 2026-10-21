# Too many open files

> Operaciones · ulimit · LimitNOFILE · /proc/PID/limits

## Escenario

Desde que la carga creció, `ingest` en `ingest-01` arranca y muere en bucle.
Un compañero ya "subió el límite" en `/etc/security/limits.conf`, y
`sudo -u ingest bash -c 'ulimit -n'` dice 65535... pero `ingest` sigue
cayéndose. Lee `~/ticket/INC-6606.txt`.

## Objetivos

1. Averigua qué error da `ingest` y qué límite tiene **de verdad** el proceso.
2. Sube el límite de descriptores de `ingest` a **4096** con un **drop-in**
   (sin editar la unit original). No vale `infinity`.
3. `ingest` activo, estable y con los 500 lotes abiertos:
   `curl -s http://127.0.0.1:8600/health` responde `ingest ok 500 lotes`.

## Comandos que te pueden servir

```bash
sudo journalctl -u ingest -n 20 --no-pager
systemctl show -p LimitNOFILE ingest
cat /proc/<PID>/limits                       # el límite que tiene ESE proceso
sudo ls /proc/<PID>/fd | wc -l               # descriptores abiertos ahora
sudo lsof -p <PID> | wc -l
ulimit -n ; ulimit -Hn                       # los de TU shell (no los del servicio)
sudo systemctl edit ingest
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
