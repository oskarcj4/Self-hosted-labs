# Resolución guiada · Lab 98 (vía BLUE)

:::piensa ¿Quién interpreta lo que escribes?
Cuando un programa ejecuta un comando "a través de una shell", le pasa una
**línea de texto** a `/bin/sh`, y la shell la interpreta: `;` separa
comandos, `|` encadena, `$(…)` ejecuta y sustituye. Si parte de esa línea la
escribe el usuario, el usuario escribe comandos. El arreglo es que no haya
shell que interprete nada.
:::

Esta guía resuelve la vía **BLUE** (arreglar). La captura (RED) es tuya: los
pasos 1 y 2 te dan la idea.

**El plan:** (1) ver qué hace la herramienta, (2) encontrar cómo construye el
comando, (3) quitar la shell y validar el formato y (4) comprobar.

## Paso 1 · ¿Qué hace la herramienta?

**Objetivo:** ver una respuesta normal para reconocer después una anómala.

:::pista Cómo hacerlo
```bash
curl -s -G http://127.0.0.1:8080/run --data-urlencode "host=localhost"
```
`-G` hace que los datos de `--data-urlencode` se envíen **en la URL**
(`/run?host=localhost`) con un `GET`, en vez de en el cuerpo de un `POST`. El
`urlencode` importa en cuanto el valor lleva espacios o `;`: los codifica
para que lleguen intactos a la app.

**Qué deberías ver:** algo como `::1  localhost` o `127.0.0.1  localhost`.
`getent hosts` resuelve un nombre igual que lo haría cualquier programa del
sistema (mira `/etc/hosts` y luego DNS).
:::

## Paso 2 · ¿Cómo construye el comando?

**Objetivo:** encontrar el punto donde la entrada del usuario se convierte en
parte de un comando.

**Pregúntate:** el programa necesita ejecutar `getent hosts <lo que pida el
usuario>`. ¿Lo ejecuta directamente o le pide a una shell que lo haga?

:::pista Cómo comprobarlo
```bash
grep -n -A4 'def lookup' /srv/app/app.py
```
```python
cmd = "getent hosts " + host
out = subprocess.run(cmd, shell=True, ...)
```
- `"getent hosts " + host` pega el texto del usuario en una **cadena**.
- `shell=True` hace que Python lance `/bin/sh -c "<esa cadena>"`. La shell
  parte la línea y ejecuta lo que encuentre.

Si `host` vale `localhost; id`, la shell ve **dos** comandos: `getent hosts
localhost` y `id`. Y la salida de ambos vuelve en la respuesta HTTP. Esa es la
idea de la vía RED.
:::

## Paso 3 · Sin shell, y validando el formato

**Objetivo:** que `host` sea siempre **un solo argumento** de `getent`, nunca
una línea que alguien interprete.

**Pregúntate:** ¿hace falta una shell para ejecutar `getent hosts X`? ¿Qué
aspecto tiene un nombre de host válido?

:::pista Cómo hacerlo
```bash
nano /srv/app/app.py
```
Sustituye la función `lookup` entera por esta:
```python
import re
_HOST = re.compile(r"^[A-Za-z0-9._-]{1,253}$")

def lookup(host):
    if not _HOST.match(host):
        return "host invalido\n"
    out = subprocess.run(["getent", "hosts", host],
                         capture_output=True, text=True, timeout=5)
    return out.stdout + out.stderr
```

Son dos defensas distintas:

1. **Una lista en vez de una cadena, sin `shell=True`.** `subprocess.run([...])`
   ejecuta `getent` directamente y le pasa cada elemento de la lista como un
   argumento separado. No hay shell en medio, así que `;`, `|` o `$(…)` son
   letras más dentro del argumento `host`. Esto solo ya cierra la inyección.
2. **Una lista blanca de formato** (segunda capa). La expresión regular:

| Parte | Significado |
|---|---|
| `^` … `$` | Toda la cadena, de principio a fin (no "contiene", sino "es"). |
| `[A-Za-z0-9._-]` | Sólo letras, números, punto, guion bajo y guion: lo que lleva un nombre de host. |
| `{1,253}` | Entre 1 y 253 caracteres, el máximo de un nombre DNS. |

Con la lista blanca, además, un valor como `-s` (que `getent` tomaría como
opción) sí pasaría el filtro, pero no ejecuta nada: como mucho, `getent` da un
error. Lo que importa es que nunca llega a una shell.

```bash
app-reload        # reinicia la app (~2 s)
app-logs          # si algo falla, aquí verás el error de Python
```
:::

## Paso 4 · Comprueba

```bash
curl -s -G http://127.0.0.1:8080/run --data-urlencode "host=localhost"
curl -s -G http://127.0.0.1:8080/run --data-urlencode "host=localhost; id"
bash /opt/lab/check.sh blue
```
**Qué deberías ver:** la resolución de `localhost` igual que antes, y
`host invalido` para la segunda.

## Cómo actuar en una situación así

- **Nunca `shell=True` con datos del usuario** (ni `os.system`, ni
  `os.popen`, ni comillas invertidas en otros lenguajes). Pasa siempre una
  lista de argumentos.
- Si de verdad necesitas una shell, `shlex.quote()` escapa un argumento, pero
  es la segunda opción: es fácil olvidarlo en un sitio.
- Pregúntate si hace falta un comando externo: aquí `socket.getaddrinfo()`
  resuelve el nombre desde Python sin lanzar ningún proceso.

## Si te atascas

- **`localhost` deja de resolver:** revisa que la lista sea
  `["getent", "hosts", host]` (tres elementos). Si dejas `"getent hosts"` como
  un único elemento, Python busca un programa llamado literalmente
  `getent hosts`, con espacio.
- **La app no arranca tras `app-reload`:** suele ser la indentación de la
  función. `app-logs` muestra la línea del error.
