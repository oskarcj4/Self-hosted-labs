# Resolución guiada · Lab 101 (vía BLUE)

:::piensa Un XML puede pedir que le lean ficheros
XML permite declarar, al principio del documento (en la DTD), **entidades**:
atajos que el parser sustituye por su valor. Una entidad *externa* toma su
valor de una URL o un fichero: `<!ENTITY e SYSTEM "file:///etc/passwd">`. Si el
parser las resuelve, quien envía el XML decide qué fichero del servidor acaba
dentro del documento… y, si la app devuelve parte de él, en la respuesta.
:::

Esta guía resuelve la vía **BLUE** (arreglar). La captura (RED) es tuya: los
pasos 1 y 2 te dan la idea.

**El plan:** (1) ver el uso normal, (2) encontrar la configuración del parser,
(3) desactivar DTD y entidades y (4) comprobar.

## Paso 1 · El uso normal

:::pista Cómo hacerlo
```bash
curl -s --data-binary '<user><name>ana</name></user>' http://127.0.0.1:8080/import
```
`--data-binary` envía el texto tal cual por `POST` (`-d` quitaría los saltos
de línea, que en un XML pueden importar).

**Qué deberías ver:** `hola ana`. La app devuelve el contenido de `<name>`:
ese es el campo donde una entidad podría colar un fichero.
:::

## Paso 2 · ¿Cómo está configurado el parser?

:::pista Cómo hacerlo
```bash
grep -n -A4 'def parse_profile' /srv/app/app.py
```
```python
parser = etree.XMLParser(resolve_entities=True, load_dtd=True, no_network=False)
```
- `load_dtd=True`: lee la DTD del documento, donde se declaran las entidades.
- `resolve_entities=True`: sustituye cada `&nombre;` por su valor, y para una
  entidad externa eso significa **abrir el fichero o la URL**.

Un `<name>&e;</name>` con `e` apuntando a un fichero devuelve ese fichero en
"hola …". Esa es la idea de la vía RED.
:::

## Paso 3 · Un parser sin entidades externas

**Objetivo:** que el parser trate el XML sólo como datos.

:::pista Cómo hacerlo
```bash
nano /srv/app/app.py
```
Cambia esa línea por:
```python
    parser = etree.XMLParser(resolve_entities=False, load_dtd=False, no_network=True)
```

| Opción | Qué hace |
|---|---|
| `resolve_entities=False` | No sustituye las entidades: `&e;` no se convierte en el contenido de nada. |
| `load_dtd=False` | No carga la DTD donde se declaran. |
| `no_network=True` | Prohíbe cualquier acceso a la red al procesar el documento (otra variante del ataque usa `http://` para llegar a servicios internos). |

Un perfil normal no usa entidades, así que sigue funcionando igual.

```bash
app-reload        # reinicia la app (~2 s)
app-logs          # si algo falla, aquí verás el error de Python
```
:::

## Paso 4 · Comprueba

```bash
curl -s --data-binary '<user><name>ana</name></user>' http://127.0.0.1:8080/import
bash /opt/lab/check.sh blue
```
**Qué deberías ver:** `hola ana`, y el check confirmando que un XML con
entidad externa ya no devuelve el fichero (el nombre sale vacío).

## Cómo actuar en una situación así

- En Python, para XML que llega de fuera, usa **`defusedxml`**: trae los
  parsers de la biblioteca estándar con todo lo peligroso desactivado.
- XXE no sólo lee ficheros: con `http://` hace peticiones desde el servidor
  (SSRF, lab 99), y con entidades anidadas puede agotar la memoria (*billion
  laughs*).
- Si no necesitas XML, acepta JSON.

## Si te atascas

- **`hola ana` deja de funcionar:** revisa la indentación de la línea (4
  espacios dentro de la función) y `app-logs`.
- **El check dice que aún filtra:** quedó alguna de las tres opciones en su
  valor antiguo; las tres cuentan.
