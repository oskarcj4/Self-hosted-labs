# Resolución guiada · Lab 207

:::piensa Regla de oro
Nunca reinicies para comprobar un fstab. `findmnt --verify` y `mount -a` te dicen
lo mismo que el arranque, sin riesgo.
:::

## Paso 1 · Diagnóstico

:::pista Cómo hacerlo
```bash
cat /etc/fstab
sudo findmnt --verify
sudo mount -a
```
Cada línea falla distinto. Léelas una a una.
:::

## Paso 2 · Línea de /datos

**Pregúntate:** `mount` no crea el punto de montaje. ¿Existe `/datos`?

:::pista Cómo hacerlo
```bash
sudo mkdir -p /datos
```
:::

## Paso 3 · Línea de /var/log/app

:::pista Cómo hacerlo
Mira el tipo de sistema de ficheros (`lsblk -f`) y compáralo con la línea. Corrige con `sudo nano /etc/fstab`.
:::

## Paso 4 · Línea de /backup

**Pregúntate:** ¿ese UUID existe? Si el volumen no está adjunto, ¿debe morir el arranque?

:::pista Cómo hacerlo
Añade `nofail` a las opciones (`defaults,nofail`). Así `mount -a` y el arranque lo ignoran si falta.
:::

## Paso 5 · Comprueba

:::pista Cómo hacerlo
```bash
sudo findmnt --verify
sudo mount -a && findmnt /datos /var/log/app
```
:::

## Cómo actuar en una situación así

- Copia de seguridad antes de editar: `sudo cp /etc/fstab /etc/fstab.bak`.
- En un EC2 con acceso sólo por consola, un fstab malo puede exigir montar el volumen raíz en otra instancia para arreglarlo.
- Usa `UUID=`/`LABEL=` (en EBS NVMe el nombre `/dev/nvmeXn1` puede cambiar entre arranques).

## Si te atascas

- `mount -a` se queja del punto de montaje: `mkdir -p`.
- Sigue saliendo el tipo erróneo: busca en el fichero espacios vs tabuladores y la palabra `ext44`.
