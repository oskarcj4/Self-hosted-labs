# Resolución guiada · Lab 116

:::piensa La diferencia con la referencia
Un programa con bit **SUID** se ejecuta con los permisos de su dueño, no con
los de quien lo lanza: un SUID de root es un atajo a root para cualquiera. Las
**capabilities** de fichero dan trozos de poder de root sin SUID, y no salen
en la misma búsqueda. Tienes una referencia de cómo era el sistema recién
instalado: cada diferencia hay que explicarla.
:::

**El plan:** (1) comparar los SUID con la referencia, (2) revisar las
capabilities, (3) averiguar de dónde viene cada hallazgo, (4) corregir y
(5) documentar.

## Paso 1 · Los SUID de ahora frente a la referencia

:::pista Cómo hacerlo
```bash
sudo find / -xdev -perm -4000 -type f 2>/dev/null | sort > /tmp/actual.txt
diff ~/auditoria/referencia-suid.txt /tmp/actual.txt
```
- `-perm -4000`: ficheros con el bit SUID (el `4` de la cifra de los permisos
  especiales).
- `-xdev`: sin salir del sistema de ficheros raíz.
- `sort` en las dos listas para que `diff` compare línea a línea.
- En la salida de `diff`, las líneas con `>` están en el segundo fichero (el
  actual) y no en el primero (la referencia): son las **nuevas**.

**Qué deberías ver:** dos SUID nuevos: uno escondido en `/tmp/.cache/` y un
binario de `vim` (`/usr/bin/vim.tiny` o `vim.basic`, según la imagen).
:::

## Paso 2 · Las capabilities

**Pregúntate:** un programa sin SUID, ¿puede hacerse root?

:::pista Cómo hacerlo
Sí, si tiene la capability adecuada.
```bash
sudo getcap -r / 2>/dev/null
diff ~/auditoria/referencia-caps.txt <(sudo getcap -r / 2>/dev/null | sort)
```
`getcap -r /` lista los ficheros con capabilities. `<(…)` pasa la salida de un
comando a `diff` como si fuera un fichero.

**Qué deberías ver:** un `/usr/local/lib/.pyhelper` con `cap_setuid=ep`.
`cap_setuid` permite cambiar de usuario, y si es una copia de Python basta un
`os.setuid(0)` para ser root.
:::

## Paso 3 · ¿De dónde viene cada uno?

**Pregúntate:** ¿es un binario de un paquete al que alguien añadió el bit, o
una copia suelta que no pertenece a ningún paquete?

:::pista Cómo hacerlo
Con las rutas que te dio el `diff`:
```bash
dpkg -S /tmp/.cache/.dbus-helper
dpkg -S /usr/bin/vim.tiny
file /tmp/.cache/.dbus-helper /usr/local/lib/.pyhelper
sha256sum /tmp/.cache/.dbus-helper /usr/bin/find
```
- `dpkg -S <fichero>` dice qué paquete lo instaló; si no es de ninguno, da
  error.
- `file` dice qué tipo de fichero es.
- Comparar el `sha256sum` con el de un binario conocido revela de qué es copia.

**Qué deberías ver:** `.dbus-helper` no es de ningún paquete y es una copia de
`find`; `vim` sí es de un paquete, pero su SUID no está en la referencia;
`.pyhelper` es una copia de `python3`. Los tres dan una shell de root (puedes
ver cómo en GTFOBins).
:::

## Paso 4 · Corrige sin romper

:::pista Cómo hacerlo
```bash
sudo mkdir -p /root/cuarentena
sudo sha256sum /tmp/.cache/.dbus-helper /usr/local/lib/.pyhelper | sudo tee /root/cuarentena/sha256.txt
sudo chmod u-s /tmp/.cache/.dbus-helper
sudo mv /tmp/.cache/.dbus-helper /root/cuarentena/
sudo chmod u-s /usr/bin/vim.tiny
sudo setcap -r /usr/local/lib/.pyhelper
sudo mv /usr/local/lib/.pyhelper /root/cuarentena/
```
- `chmod u-s` quita el bit SUID; `setcap -r` quita las capabilities.
- Las copias sueltas van a cuarentena (no se borran: son evidencia).
- Al binario de paquete sólo se le quita el bit: borrarlo rompería `vim`.
- No toques los SUID de la referencia (`passwd`, `su`, `sudo`…): los
  necesitan.
:::

## Paso 5 · Documenta

```bash
nano ~/auditoria/informe.txt
bash /opt/lab/check.sh
```
Una línea por hallazgo, con la ruta completa, qué era y qué hiciste.

## Cómo actuar en una situación así

- Ten una referencia de SUID y capabilities y compárala periódicamente.
- Monta `/tmp`, `/home` y `/var/tmp` con `nosuid` (lab 209): un SUID ahí no
  funcionaría.
- Un SUID nuevo casi nunca es un accidente: busca cómo llegó y quién lo usó.

## Si te atascas

- **`dpkg -S /usr/bin/vim.basic`: no encontrado:** en esta imagen es
  `vim.tiny`; usa la ruta que te dio el `diff`.
- **`diff` saca muchísimo:** te faltó ordenar alguna de las dos listas.
- **El check sigue viendo la capability:** `setcap -r` antes de moverlo, o
  comprueba con `getcap` en la nueva ruta.
