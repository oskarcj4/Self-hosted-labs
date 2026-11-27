# Resolución guiada · Lab 99 (vía BLUE)

:::piensa El servidor ataca por ti
En SSRF (*Server-Side Request Forgery*) el atacante no entra en la red
interna: convence a un servidor que **ya está dentro** de que haga la petición
por él. Aquí es peor: el fetcher añade la cabecera secreta que abre los
servicios internos. El atacante no la conoce, pero no le hace falta.
:::

Esta guía resuelve la vía **BLUE** (arreglar). La captura (RED) es tuya: los
pasos 1 y 2 te dan todo lo que hace falta entender.

**El plan:** (1) ver el uso legítimo y por qué el acceso directo falla,
(2) encontrar dónde el fetcher decide a dónde ir, (3) restringirlo a un único
destino y (4) comprobar.

## Paso 1 · El uso normal y el acceso directo

**Objetivo:** ver la diferencia entre pedir algo **tú** y pedirlo **a través
del fetcher**.

:::pista Cómo hacerlo
```bash
curl -s "http://127.0.0.1:8080/fetch?url=http://api.internal:8090/status"
curl -s "http://127.0.0.1:9000/flag"
```
**Qué deberías ver:** la primera devuelve `status: ok` (el fetcher pidió
`/status` por ti). La segunda, `forbidden`: tu petición no lleva la cabecera
`X-Internal-Auth`, y el servicio interno sólo atiende a quien la lleva.

`api.internal` es un nombre que apunta a `127.0.0.1` en `/etc/hosts`
(`getent hosts api.internal` te lo confirma). Es decir: los tres servicios
viven en la misma máquina y sólo se distinguen por el **puerto**. Esto es
clave para el paso 3.
:::

## Paso 2 · ¿A dónde puede ir el fetcher?

**Objetivo:** encontrar en el código qué controla el destino.

**Pregúntate:** el frontend sólo necesita `api.internal:8090/status`. ¿Qué
comprueba el fetcher antes de hacer la petición?

:::pista Cómo comprobarlo
```bash
grep -n -A5 'def do_fetch' /srv/app/app.py
```
```python
req = urllib.request.Request(url, headers={"X-Internal-Auth": AUTH})
```
Nada. Pide **cualquier** `url` que le llegue y le añade la cabecera secreta.
Si le pides una URL interna distinta a la prevista, la pide por ti, con su
credencial. Esa es la idea de la vía RED. A esto se le llama *confused
deputy*: alguien con permisos actúa en nombre de quien no los tiene.
:::

## Paso 3 · Una lista blanca de destinos

**Objetivo:** que el fetcher sólo pueda ir al destino legítimo.

**Pregúntate:** ¿qué partes de una URL identifican a dónde va la petición? ¿Es
suficiente con comprobar el nombre del host?

:::pista Cómo hacerlo
```bash
nano /srv/app/app.py
```
Sustituye la función `do_fetch` entera por esta:
```python
ALLOW = {("api.internal", 8090)}

def do_fetch(url):
    p = urlparse(url)
    port = p.port or (443 if p.scheme == "https" else 80)
    if p.scheme not in ("http", "https") or (p.hostname, port) not in ALLOW:
        raise ValueError("destino no permitido: %s" % url)
    req = urllib.request.Request(url, headers={"X-Internal-Auth": AUTH})
    with urllib.request.urlopen(req, timeout=4) as r:
        return r.read().decode(errors="replace")
```

| Pieza | Por qué está ahí |
|---|---|
| `urlparse(url)` | Parte la URL en trozos: `scheme` (`http`), `hostname` (`api.internal`), `port` (`8090`), `path`… Comparar trozos es mucho más seguro que buscar texto dentro de la URL (`"api.internal" in url` lo pasaría `http://127.0.0.1:9000/?x=api.internal`). |
| `p.port or (443 if … else 80)` | Si la URL no lleva puerto, `p.port` vale `None`: se usa el puerto por defecto del esquema. Así `http://api.internal/` se compara como puerto 80 y no pasa. |
| `p.scheme not in ("http", "https")` | Bloquea otros esquemas que `urllib` sabe abrir, como `file:///etc/passwd`. |
| `(p.hostname, port) not in ALLOW` | El destino tiene que ser exactamente la pareja host + puerto permitida. |

**El puerto es imprescindible.** Si sólo comprobaras el host, como
`api.internal` es `127.0.0.1`, la URL `http://api.internal:9000/flag`
pasaría el filtro y llegaría al servicio de la flag.

El `raise ValueError` no tumba la app: el manejador ya captura cualquier
excepción de `do_fetch` y responde `502 fetch error: …`.

```bash
app-reload        # reinicia la app (~2 s)
app-logs          # si algo falla, aquí verás el error de Python
```
:::

## Paso 4 · Comprueba

```bash
curl -s "http://127.0.0.1:8080/fetch?url=http://api.internal:8090/status"
curl -s "http://127.0.0.1:8080/fetch?url=http://api.internal:9000/flag"
bash /opt/lab/check.sh blue
```
**Qué deberías ver:** `status: ok` en la primera y
`fetch error: destino no permitido` en la segunda.

## Cómo actuar en una situación así

- **Valida a dónde sale el servidor**, no sólo qué entra. Lista blanca de
  host + puerto (+ esquema), nunca lista negra de "IP prohibidas": siempre hay
  otra forma de escribir `127.0.0.1` (`0x7f000001`, `localhost`, `[::1]`…).
- **No inyectes credenciales** en peticiones cuyo destino elige el usuario: es
  lo que convierte un SSRF en acceso autenticado.
- Esta lista blanca aún no cubre **redirecciones** (si el destino permitido
  responde `302` hacia un interno, `urlopen` la sigue) ni **DNS rebinding**.
  En la nube, bloquea además `169.254.169.254` (metadatos de la instancia).

## Si te atascas

- **El destino legítimo también da `destino no permitido`:** revisa que
  `ALLOW` tenga el puerto como **número** (`8090`), no como texto (`"8090"`):
  `p.port` es un entero y `("api.internal", "8090")` no coincidiría nunca.
- **La app no arranca:** indentación de la función. `app-logs` dice la línea.
