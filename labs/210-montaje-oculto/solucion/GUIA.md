# Resolución guiada · Lab 210

:::piensa df y du miden cosas distintas
`df` pregunta al sistema de ficheros cuántos bloques hay ocupados. `du` suma lo
que ve recorriendo nombres. Si faltan nombres (ocultos o borrados), no cuadran.
:::

## Paso 1 · Confirma la discrepancia

:::pista Cómo comprobarlo
```bash
df -h /almacen
sudo du -shx /almacen
```
:::

## Paso 2 · ¿Hay algo oculto bajo un montaje?

**Pregúntate:** ¿cómo miras un directorio sin que un submontaje lo tape?

:::pista Cómo hacerlo
```bash
sudo mkdir -p /mnt/vista
sudo mount --bind /almacen /mnt/vista
ls -la /mnt/vista/datos
```
:::

## Paso 3 · Colócalo donde pertenece

:::pista Cómo hacerlo
```bash
sudo mv /mnt/vista/datos/subida-2025-*.bin /almacen/datos/
sudo umount /mnt/vista
```
Lo mueves desde la vista "de abajo" hacia el montaje real: el disco de datos.
:::

## Paso 4 · Ficheros borrados pero abiertos

:::pista Cómo hacerlo
```bash
sudo lsof -nP +L1
sudo systemctl restart colector
df -h /almacen
```
`+L1` lista ficheros con 0 enlaces (borrados) todavía abiertos.
:::

## Cómo actuar en una situación así

- Prevención: monta antes de escribir, o crea el directorio con `chattr +i` mientras no esté montado.
- `logrotate` con `copytruncate` o `postrotate` que avise al servicio; nunca `rm` de un log vivo.
- Si no puedes reiniciar el servicio: `: > /proc/<PID>/fd/<N>` trunca el fichero borrado.

## Si te atascas

- `mv` dice "No space left": estás moviendo hacia el sitio equivocado.
- `df` sigue alto tras reiniciar: otro proceso tiene el fichero; `lsof +L1` otra vez.
