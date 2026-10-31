# Respaldo y recuperación tras un cifrado masivo

> Defensa del host · find -mmin · inotifywait · rsync · sha256sum -c

## Escenario

Nadie puede abrir nada de `/srv/datos` y ha aparecido `LEEME-RESCATE.txt`
(`~/ticket/INC-122.txt`). Hay un respaldo semanal **desconectado**: una
imagen de disco sin montar en `/var/backups/respaldo-offline.img`, con su
`SHA256SUMS`. Un respaldo que está siempre montado se cifra junto con todo lo
demás; por eso éste está desconectado.

## Objetivos

1. Mide el daño: cuántos ficheros se alteraron. Anótalo en
   `~/incidente.txt` como `alterados=<N>`.
2. Antes de restaurar, encuentra **qué** está escribiendo en `/srv/datos` y
   detenlo para siempre. Si restauras con él vivo, vuelve a cifrar.
3. Monta el respaldo **en sólo lectura**, comprueba que está sano y restaura
   con `rsync -a` (propietarios y permisos incluidos), sin dejar restos
   cifrados ni la nota.
4. Verifica la restauración con `sha256sum -c`.
5. Desmonta el respaldo: vuelve a quedar desconectado.

## Comandos que te pueden servir

```bash
find /srv/datos -type f -mmin -30 | wc -l
sudo inotifywait -m -r /srv/datos          # ¿alguien sigue escribiendo?
ps aux ; systemctl list-units --type=service --state=running
sudo mount -o ro,loop /var/backups/respaldo-offline.img /mnt/respaldo
sudo rsync -a --delete --dry-run /mnt/respaldo/datos/ /srv/datos/
cd /srv/datos && sha256sum -c --quiet /mnt/respaldo/SHA256SUMS
sudo umount /mnt/respaldo
```

> `--delete` borra en el destino lo que no está en el origen: pruébalo antes
> con `--dry-run`. Y fíjate en la `/` final de las rutas de rsync.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
