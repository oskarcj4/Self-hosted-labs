# Resolución guiada · Día 07

:::piensa Antes de tocar nada
`chmod 777` es la respuesta equivocada a una pregunta correcta. La pregunta era: "¿por qué la app no puede escribir?". La respuesta correcta era "porque la carpeta no es suya", y se arregla cambiando el **dueño**, no abriendo la puerta a todo el mundo.
:::

## Paso 1 · Mide el daño

**Pregúntate:** ¿qué hay escribible por "otros" dentro de `uploads/`? Recuerda que el `-R` llegó a todo.

:::pista Cómo comprobarlo
```bash
sudo find /var/www/media/uploads -perm -0002 -ls
```
`-perm -0002` = tiene el bit de escritura para otros.
:::

## Paso 2 · ¿Quién debe escribir?

**Pregúntate:** ¿qué usuario usa la app? Ése, y sólo ése, necesita escribir.

:::pista Cómo comprobarlo
```bash
systemctl show media-app -p User -p Group
```
:::

## Paso 3 · Dueño correcto, permiso mínimo

**Pregúntate:** ¿carpetas y ficheros necesitan el mismo permiso? No. Las carpetas necesitan `x` para poder entrar; los ficheros no deberían tenerla.

:::pista Cómo hacerlo
```bash
U=/var/www/media/uploads
sudo chown -R www-data:www-data "$U"
sudo find "$U" -type d -exec chmod 0755 {} +
sudo find "$U" -type f -exec chmod 0644 {} +
```
Separar con `find -type d` / `-type f` evita dar `x` a los ficheros subidos.
:::

## Paso 4 · Prueba con los dos actores

**Pregúntate:** ¿cómo demuestro que un extraño ya no puede y la app sí?

```bash
sudo find "$U" -perm -0002 | wc -l                  # 0
sudo -u nobody touch "$U/avatars/x" || echo "extraño bloqueado"
curl -X POST --data-binary hola 'http://127.0.0.1:8300/upload?name=t.txt&dir=avatars'
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Ante un "Permission denied"**, pregunta *quién* intenta escribir y *de quién* es el destino. Ajusta el dueño.
- **Aplica recursivamente** y distingue carpetas de ficheros.
- **No borres datos de usuarios** al corregir permisos.
- Defensa extra: que el servidor web **no ejecute** nada de `uploads/`.

## Si te atascas

- La app sigue sin poder subir a una subcarpeta: revisa que el `chown -R` llegó a todas (`ls -la $U/*`).
