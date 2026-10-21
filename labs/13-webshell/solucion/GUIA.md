# Resolución guiada · Lab 13

:::piensa Antes de tocar nada
En una web con decenas de ficheros no se revisa uno a uno: se busca **por comportamiento**. Un fichero que ejecuta comandos del sistema a partir de lo que llega por HTTP tiene que llamar a ciertas funciones. Busca esas funciones y busca también ficheros que están donde no deberían.
:::

## Paso 1 · Busca por contenido

**Pregúntate:** ¿qué funciones necesita un script para ejecutar comandos del sistema?

**Por qué importa:** el nombre del fichero se puede disfrazar; lo que hace, no.

:::pista Cómo comprobarlo
```bash
grep -rnEl 'system\(|shell_exec\(|passthru\(|eval\(base64_decode' /var/www 2>/dev/null
```
`-l` lista sólo los ficheros que coinciden.
:::

## Paso 2 · Busca por ubicación

**Pregúntate:** ¿en qué carpeta de una web **nunca** debería haber código ejecutable? En la de subidas de usuarios.

**Por qué importa:** si ambas búsquedas (contenido y ubicación) señalan el mismo fichero, la confianza es alta.

:::pista Cómo comprobarlo
```bash
ls -laR /var/www/html/uploads
find /var/www -name '*.php' -path '*uploads*'
```
Fíjate en ficheros ocultos (empiezan por `.`).
:::

## Paso 3 · Confirma y retira

**Pregúntate:** ¿qué hace ese fichero exactamente? Léelo (con `cat`, no abriéndolo en el navegador).

:::pista Cómo hacerlo
```bash
cat <fichero-sospechoso>
sudo rm -f <fichero-sospechoso>
```
Repite la búsqueda del paso 1 para asegurarte de que no hay más.
:::

## Paso 4 · Lo legítimo sigue en su sitio

```bash
ls /var/www/html
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Busca por comportamiento y por ubicación**, no por nombre.
- **Raramente hay una sola**: repite la búsqueda tras borrar.
- **Línea base de integridad**: con hashes de los ficheros buenos, cualquier fichero nuevo o cambiado destaca.
- **La causa raíz** suele ser un formulario de subida sin validar: si no lo corriges, volverán a subirla.
- Prevención: la carpeta `uploads/` no debe ejecutar código (configuración del servidor web).

## Si te atascas

- `grep` no devuelve nada: comprueba que buscas en `/var/www` (con `-r`).
