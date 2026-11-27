# Resolución guiada · Lab 122

:::piensa El orden lo es todo
Si restauras mientras el proceso que cifra sigue vivo, cifrará también lo que
restauras. Y si restauras desde un respaldo dañado, pierdes la última copia
buena. El orden es: **medir → detener → verificar el respaldo → restaurar →
verificar el resultado → desconectar**.
:::

**El plan:** (1) medir el daño, (2) encontrar quién escribe, (3) detenerlo
guardando evidencia, (4) montar y comprobar el respaldo, (5) restaurar y
verificar, y (6) desmontar.

## Paso 1 · ¿Cuánto daño hay?

**Objetivo:** cuántos ficheros se cifraron.

:::pista Cómo hacerlo
```bash
ls /srv/datos | head
cat /srv/datos/LEEME-RESCATE.txt
find /srv/datos -type f -name '*.lock' | wc -l
```
Cada fichero cifrado ha cambiado de nombre: tiene `.lock` al final. `find
-type f -name '*.lock'` los busca (las comillas impiden que la shell
interprete el `*` antes que `find`) y `wc -l` cuenta las líneas.

**Qué deberías ver:** sólo ficheros `.lock` y la nota. Escribe el número en
`~/incidente.txt` como `alterados=<N>`.
:::

## Paso 2 · ¿Quién está escribiendo?

**Objetivo:** encontrar el proceso que cifra.

**Pregúntate:** ¿cómo ves en tiempo real qué ficheros se crean y se borran?

:::pista Cómo hacerlo
```bash
sudo inotifywait -m -r -e create,delete /srv/datos
```
**inotifywait** escucha los avisos que el kernel da cuando algo cambia en una
carpeta. `-m` sigue escuchando (sin él, sale al primer evento), `-r` incluye
las subcarpetas y `-e create,delete` sólo esos dos tipos de evento. Espera
unos 20 s: verás aparecer actividad cada vez que pasa el cifrador. Sal con
Ctrl+C. Ahora, ¿qué proceso es?
```bash
ps aux | grep -i -E 'index|crypt' | grep -v grep
systemctl list-units --type=service --state=running
```
**Qué deberías ver:** un servicio `datos-indexer` con un nombre inocente.
Míralo por dentro:
```bash
systemctl cat datos-indexer
cat /usr/local/sbin/datos-indexer
```
Recorre `/srv/datos`, convierte cada fichero (`base64 | rev`) en un `.lock` y
borra el original. Y la unidad tiene `Restart=always`: si sólo matas el
proceso, systemd lo vuelve a lanzar.
:::

## Paso 3 · Detén y guarda evidencia

**Objetivo:** que deje de cifrar y no vuelva al reiniciar, conservando una
copia para el análisis.

:::pista Cómo hacerlo
```bash
sudo systemctl disable --now datos-indexer
sudo mkdir -p /root/evidencia
sudo cp /usr/local/sbin/datos-indexer /etc/systemd/system/datos-indexer.service /root/evidencia/
sudo rm -f /usr/local/sbin/datos-indexer /etc/systemd/system/datos-indexer.service
sudo systemctl daemon-reload
```
- `disable --now` lo para ya (`--now`) y quita su arranque automático
  (`disable`).
- Se copia el script y la unidad **antes** de borrarlos: son la prueba de lo
  que pasó.
- `daemon-reload` hace que systemd olvide la unidad borrada.
:::

## Paso 4 · ¿El respaldo está sano?

**Objetivo:** conectar el respaldo sin poder dañarlo, y comprobar que sus datos
son los buenos.

**Pregúntate:** ¿por qué en sólo lectura? ¿Y por qué comprobar los hashes
**antes** de copiar nada?

:::pista Cómo hacerlo
```bash
sudo mkdir -p /mnt/respaldo
sudo mount -o ro,loop /var/backups/respaldo-offline.img /mnt/respaldo
ls /mnt/respaldo
```
- El respaldo es una **imagen de disco**: un fichero que contiene un sistema
  de ficheros entero. `-o loop` hace que Linux lo trate como si fuera un disco.
- `-o ro` lo monta en **sólo lectura**: ni tú por error, ni un proceso
  malicioso que siguiera vivo, pueden modificarlo.

Comprueba la integridad:
```bash
cd /mnt/respaldo/datos && sudo sha256sum -c --quiet ../SHA256SUMS && echo "respaldo íntegro"
```
`SHA256SUMS` guarda la huella (hash SHA-256) de cada fichero tal como era al
hacer el respaldo. `sha256sum -c` recalcula la de cada fichero y la compara;
`--quiet` sólo informa de los que no coinciden.

**Qué deberías ver:** `respaldo íntegro`. Si algo no coincidiera, el respaldo
también estaría dañado y no deberías restaurar desde él.
:::

## Paso 5 · Restaura y verifica

**Objetivo:** dejar `/srv/datos` exactamente como en el respaldo.

:::pista Cómo hacerlo
Ensaya primero, sin cambiar nada:
```bash
sudo rsync -a --delete --dry-run -v /mnt/respaldo/datos/ /srv/datos/ | tail -5
```
Y si lo que ves es lo esperado, de verdad:
```bash
sudo rsync -a --delete /mnt/respaldo/datos/ /srv/datos/
cd /srv/datos && sudo sha256sum -c --quiet /mnt/respaldo/SHA256SUMS && echo "restauración verificada"
ls /srv/datos
```

| Opción | Qué hace |
|---|---|
| `-a` | Modo archivo: copia recursivamente conservando dueños, permisos y fechas. Sin él, los ficheros quedarían de root. |
| `--delete` | Borra en el destino lo que **no** está en el origen: los `.lock` y la nota de rescate. |
| `--dry-run -v` | Enseña lo que haría sin hacerlo. Con `--delete` siempre conviene ensayar. |
| `/` al final del origen | "El **contenido** de `datos/`". Sin la barra, rsync crearía `/srv/datos/datos/`. |

**Qué deberías ver:** `restauración verificada` y los ficheros originales, sin
`.lock` ni nota.
:::

## Paso 6 · Desconecta el respaldo

```bash
cd /
sudo umount /mnt/respaldo
bash /opt/lab/check.sh
```
Primero `cd /`: no se puede desmontar una carpeta en la que está tu terminal
(`target is busy`).

## Cómo actuar en una situación así

- **Respaldo desconectado (offline o inmutable):** si el atacante lo alcanza,
  lo cifra también. Montarlo sólo para restaurar, y desmontarlo al terminar.
- **Un respaldo no probado no es un respaldo:** verifica hashes y ensaya
  restauraciones con regularidad.
- Regla 3-2-1: 3 copias, en 2 medios distintos, 1 fuera de la oficina.

## Si te atascas

- **`mount` falla:** necesitas `sudo` y `-o loop`.
- **`sha256sum -c` falla tras restaurar:** el cifrador sigue vivo (vuelve al
  paso 3), o te faltó el `-a` y no es lo mismo.
- **Aparece `/srv/datos/datos/`:** te faltó la `/` final del origen en rsync.
- **`umount: target is busy`:** tu terminal (u otra) está dentro de
  `/mnt/respaldo`. `cd /` y repite.
