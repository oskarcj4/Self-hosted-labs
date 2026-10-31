# Resolución guiada · Lab 122

:::piensa Antes de tocar nada
Si restauras mientras el proceso que cifra sigue vivo, cifra también lo que
restauras. Orden: **medir → detener → verificar el respaldo → restaurar → verificar el resultado**.
:::

## Paso 1 · ¿Cuánto daño hay?

:::pista Cómo comprobarlo
```bash
find /srv/datos -type f -name '*.lock' | wc -l
cat /srv/datos/LEEME-RESCATE.txt
```
Anota `alterados=N` en `~/incidente.txt`.
:::

## Paso 2 · ¿Quién está escribiendo?

**Pregúntate:** ¿qué herramienta te enseña en tiempo real qué ficheros se crean y borran?

:::pista Cómo comprobarlo
```bash
sudo inotifywait -m -r -e create,delete /srv/datos     # Ctrl+C para salir
sudo lsof +D /srv/datos
systemctl list-units --type=service | grep -i index
```
:::

## Paso 3 · Detén y guarda evidencia

:::pista Cómo hacerlo
```bash
sudo systemctl disable --now datos-indexer
sudo mkdir -p /root/evidencia
sudo cp /usr/local/sbin/datos-indexer /etc/systemd/system/datos-indexer.service /root/evidencia/
sudo rm -f /usr/local/sbin/datos-indexer /etc/systemd/system/datos-indexer.service
sudo systemctl daemon-reload
```
:::

## Paso 4 · ¿El respaldo está sano?

**Pregúntate:** ¿por qué montarlo en sólo lectura? ¿Y por qué comprobar los hashes antes de copiar?

:::pista Cómo comprobarlo
```bash
sudo mkdir -p /mnt/respaldo
sudo mount -o ro,loop /var/backups/respaldo-offline.img /mnt/respaldo
cd /mnt/respaldo/datos && sudo sha256sum -c --quiet ../SHA256SUMS
```
:::

## Paso 5 · Restaura y verifica

:::pista Cómo hacerlo
```bash
sudo rsync -a --delete /mnt/respaldo/datos/ /srv/datos/
cd /srv/datos && sudo sha256sum -c --quiet /mnt/respaldo/SHA256SUMS && echo OK
cd / && sudo umount /mnt/respaldo
```
`--delete` quita los `.lock` y la nota de rescate.
:::

## Cómo actuar en una situación así

- **Respaldo desconectado (offline / inmutable)**: si el atacante lo alcanza, lo cifra también.
- **Un respaldo no probado no es un respaldo**: verifica hashes y ensaya restauraciones.
- Regla 3-2-1: 3 copias, 2 medios, 1 fuera.

## Si te atascas

- `mount` falla: necesitas `sudo` y `-o loop`.
- `sha256sum -c` falla tras restaurar: el servicio sigue vivo; vuelve al paso 3.
