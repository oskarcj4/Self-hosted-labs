# Resolución guiada · Lab 210

:::piensa df y du miden cosas distintas
`df` pregunta al sistema de ficheros cuántos bloques tiene ocupados. `du`
recorre los **nombres** de ficheros y suma lo que pesan. Si hay bloques
ocupados sin un nombre visible, no cuadran. Dos causas clásicas, y aquí están
las dos: ficheros **tapados** por un montaje encima, y ficheros **borrados**
que un proceso sigue teniendo abiertos.
:::

**El plan:** (1) confirmar la discrepancia, (2) mirar debajo del montaje,
(3) mover lo oculto a su sitio y (4) liberar el fichero borrado.

## Paso 1 · Confirma la discrepancia

:::pista Cómo hacerlo
```bash
df -h /almacen
sudo du -shx /almacen
findmnt -R /almacen
```
- `du -shx`: total (`-s`), legible (`-h`) y sin entrar en otros sistemas de
  ficheros montados dentro (`-x`).
- `findmnt -R` enseña el montaje y los que hay debajo (`-R`, recursivo).

**Qué deberías ver:** `df` en torno al 75 % y `du` con muy poco. Y que en
`/almacen/datos` hay **otro** disco montado.
:::

## Paso 2 · ¿Hay algo tapado?

**Pregúntate:** si se escribió en `/almacen/datos` antes de montar el disco de
datos encima, ¿dónde están esos ficheros? ¿Cómo los ves sin desmontar?

:::pista Cómo hacerlo
Siguen en el disco de abajo, invisibles. Un *bind mount* sin submontajes
enseña el directorio tal como está en ese disco:
```bash
sudo mkdir -p /mnt/vista
sudo mount --bind /almacen /mnt/vista
ls -la /mnt/vista/datos
```
`mount --bind A B` hace que `B` muestre lo mismo que `A`. Sin `--rbind`, no
arrastra lo que está montado dentro de `A`: en `/mnt/vista/datos` ves lo que
hay **debajo** del disco de datos.

**Qué deberías ver:** varios `subida-2025-*.bin` grandes que `ls /almacen/datos`
no enseña.
:::

## Paso 3 · Colócalo donde pertenece

:::pista Cómo hacerlo
```bash
sudo mv /mnt/vista/datos/subida-2025-*.bin /almacen/datos/
sudo umount /mnt/vista
df -h /almacen
```
Lo mueves desde la vista "de abajo" (el disco raíz) hasta `/almacen/datos`,
que ahora es el disco de datos: son dos sistemas de ficheros distintos, así
que `mv` copia y borra, y el espacio se libera en el de abajo.
:::

## Paso 4 · El fichero borrado que sigue abierto

:::pista Cómo hacerlo
```bash
sudo lsof -nP +L1
```
`lsof` lista los ficheros abiertos; `+L1`, sólo los que tienen menos de un
enlace, es decir, que ya no tienen nombre (borrados). `-nP` evita resolver
nombres y puertos.

**Qué deberías ver:** un proceso `colector` con un fichero `(deleted)` de
varios MB. Mientras siga abierto, sus bloques siguen ocupados. Libéralo:
```bash
sudo systemctl restart colector
df -h /almacen
bash /opt/lab/check.sh
```
Al reiniciar, el proceso viejo cierra el fichero y el kernel libera los
bloques.
:::

## Cómo actuar en una situación así

- **Prevención:** monta antes de escribir. Puedes proteger el directorio vacío
  con `chattr +i` mientras no esté montado, para que nadie escriba en él.
- Nunca `rm` de un log que un servicio tiene abierto: `logrotate` con
  `copytruncate` o con `postrotate` que avise al servicio.
- Si no puedes reiniciar el servicio: `: > /proc/<PID>/fd/<N>` vacía el
  fichero borrado a través de su descriptor.

## Si te atascas

- **`mv` dice `No space left on device`:** estás moviendo en el sentido
  equivocado o hacia el mismo disco.
- **`df` sigue alto tras reiniciar:** otro proceso tiene abierto el fichero;
  `lsof +L1` otra vez.
- **`umount: target is busy`:** tu terminal está dentro de `/mnt/vista`; `cd /`.
