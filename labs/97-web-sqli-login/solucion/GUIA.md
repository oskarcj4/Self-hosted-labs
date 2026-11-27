# Resolución guiada · Lab 97 (vía BLUE)

:::piensa Código y datos mezclados
Una consulta SQL es un pequeño programa. Si el usuario puede meter texto
**dentro** de ese programa, puede cambiar lo que hace. Eso es la inyección:
no "un carácter raro", sino que la entrada deja de ser dato y pasa a ser
código. El arreglo no es filtrar comillas, es no mezclar nunca las dos cosas.
:::

Esta guía resuelve la vía **BLUE** (arreglar). La captura (RED) es tuya: los
pasos 1 y 2 te dan todo lo que necesitas para entender por qué funciona.

**El plan:** (1) ver cómo responde el login, (2) encontrar la consulta en el
código y entender por qué es inyectable, (3) arreglarla con parámetros y
(4) comprobar que lo legítimo sigue entrando y la inyección no.

## Paso 1 · ¿Cómo habla la aplicación?

**Objetivo:** saber qué devuelve un login bueno y uno malo, para reconocer
después si algo ha cambiado.

:::pista Cómo hacerlo
```bash
curl -s --data-urlencode "user=ana" --data-urlencode "password=Primavera2024" \
     http://127.0.0.1:8080/login
curl -s --data-urlencode "user=ana" --data-urlencode "password=mala" \
     http://127.0.0.1:8080/login
```
`--data-urlencode "campo=valor"` envía un formulario por `POST` (como el
navegador al pulsar "entrar") y codifica los caracteres especiales del valor.
Sin el `urlencode`, una comilla, un espacio o un `&` en la contraseña
romperían el envío antes de llegar a la app.

**Qué deberías ver:** `OK bienvenido=ana role=user` y luego
`credenciales invalidas`.
:::

## Paso 2 · ¿Dónde está el fallo?

**Objetivo:** encontrar la línea exacta y entender **por qué** es inyectable.

**Pregúntate:** el código recibe `user` y `password` como texto. ¿Cómo llegan
esos textos a la consulta SQL?

:::pista Cómo comprobarlo
```bash
grep -n -A6 'def check_login' /srv/app/app.py
```
`-A6` muestra también las 6 líneas siguientes a la coincidencia (*After*).
Verás esto:
```python
q = ("SELECT username, role, flag FROM users "
     "WHERE username = '%s' AND password = '%s'" % (user, password))
```
El `%` de Python **pega** el texto del usuario dentro de la consulta antes
de mandarla a la base de datos. La base de datos recibe una sola cadena y no
sabe qué parte escribió el programador y qué parte el usuario.

Si `user` vale `ana' -- `, la consulta queda:
```sql
SELECT ... WHERE username = 'ana' -- ' AND password = '...'
```
La comilla del usuario **cierra** el literal, y `--` convierte el resto de la
línea en comentario: la comprobación de la contraseña desaparece. Esa es la
idea que necesitas para la vía RED.
:::

## Paso 3 · Arréglalo con parámetros

**Objetivo:** que la entrada del usuario no pueda volver a formar parte de
la sintaxis SQL, sea cual sea su contenido.

**Pregúntate:** ¿y si en vez de construir la cadena tú, le pasas a la base de
datos la consulta y los valores **por separado**?

:::pista Cómo hacerlo
```bash
nano /srv/app/app.py
```
Cambia esas líneas por:
```python
    q = ("SELECT username, role, flag FROM users "
         "WHERE username = ? AND password = ?")
    try:
        rows = cur.execute(q, (user, password)).fetchall()
```
Los `?` son **marcadores** (*placeholders*): huecos con nombre en la consulta.
`execute(q, (user, password))` manda la consulta y los valores por separado;
SQLite compila primero la consulta y después mete cada valor en su hueco
**como dato**. Una comilla dentro de `user` es sólo un carácter más del
nombre, nunca el final del literal.

Fíjate en que hay que cambiar **dos** sitios: los `'%s'` por `?` (sin
comillas: el marcador no las lleva) y el `.execute(q)` para que reciba la
tupla de valores.

Aplica el cambio:
```bash
app-reload        # reinicia la app (tarda ~2 s)
app-logs          # si algo falla, aquí verás el error de Python
```
:::

:::ojo No lo arregles escapando comillas
Reemplazar `'` por `''` o filtrar palabras como `OR` parece funcionar, pero
siempre hay otra codificación u otro contexto que se escapa. Los parámetros
no "limpian" la entrada: hacen que nunca se interprete. Por eso son la única
solución fiable.
:::

## Paso 4 · Comprueba

```bash
# legítimo: entra
curl -s --data-urlencode "user=ana" --data-urlencode "password=Primavera2024" \
     http://127.0.0.1:8080/login
# inyección: ahora 401, sin flag
curl -s --data-urlencode "user=' OR '1'='1" --data-urlencode "password=x" \
     http://127.0.0.1:8080/login
bash /opt/lab/check.sh blue
```
**Qué deberías ver:** `OK bienvenido=ana role=user` y después
`credenciales invalidas`.

## Cómo actuar en una situación así

- **Siempre consultas parametrizadas** (`?`, `%s` del driver, `:nombre`…),
  también en scripts internos "que sólo uso yo".
- Busca el patrón en todo el código: `grep -rnE "execute\(.*(%|\+|f\")" .`
  encuentra consultas montadas con `%`, `+` o f-strings.
- Aquí además las contraseñas están **en claro** en la base de datos: en un
  caso real, se guardan con un hash lento (bcrypt, argon2).

## Si te atascas

- **ana ya no entra (`credenciales invalidas`):** casi siempre es uno de estos
  dos. (a) Dejaste comillas alrededor de los marcadores (`'?'`): entonces son
  texto, la consulta tiene 0 huecos y le pasas 2 valores. (b) Cambiaste los `?`
  pero no el `.execute(q)`: 2 huecos y 0 valores. En los dos casos SQLite da
  `Incorrect number of bindings`, pero la app captura el error y lo convierte en
  un login fallido, así que no lo verás en `app-logs`. Revisa las dos líneas.
- **El check dice que la app no responde:** error de sintaxis o de
  indentación de Python. `app-logs` te dice la línea.
