# Resolución guiada · Lab 11

:::piensa Antes de tocar nada
Si eres root y `rm` dice "Operation not permitted", el problema **no son los permisos** (root se los salta). Hay otra capa que manda por encima: los atributos del sistema de ficheros. Cuando algo "imposible" pasa, no fuerces: diagnostica.
:::

## Paso 1 · Reproduce el error

**Pregúntate:** ¿qué dice exactamente el error? "Permission denied" y "Operation not permitted" no son lo mismo.

:::pista Cómo comprobarlo
```bash
ls -la /data/.payload
sudo rm -f /data/.payload
```
Los permisos Unix (`ls -la`) parecen normales, y aun así falla. Algo más lo protege.
:::

## Paso 2 · Mira los atributos extendidos

**Pregúntate:** ¿qué herramienta muestra atributos que `ls` no enseña?

**Por qué importa:** el atributo `i` (inmutable) impide modificar, renombrar o borrar el fichero, incluso a root.

:::pista Cómo comprobarlo
```bash
lsattr /data/.payload
```
Busca la `i` en la ristra de letras.
:::

## Paso 3 · Quita la protección y borra

**Pregúntate:** antes de borrar, ¿quiero ver qué contiene? (En un caso real, sí: es evidencia.)

:::pista Cómo hacerlo
```bash
sudo cat /data/.payload
sudo chattr -i /data/.payload
lsattr /data/.payload
sudo rm -f /data/.payload
bash /opt/lab/check.sh
```
:::

## Cómo actuar en una situación así

- **"Operation not permitted" siendo root** → piensa en `lsattr` (o en un montaje de sólo lectura).
- **Busca más ficheros con el mismo truco**: `sudo lsattr -R /etc /usr/bin /data 2>/dev/null | grep -- '-i-'`.
- El atributo también es una **herramienta defensiva**: puedes proteger ficheros críticos con `chattr +i`.

## Si te atascas

- `lsattr` no muestra nada: comprueba la ruta exacta (el fichero empieza por punto).
