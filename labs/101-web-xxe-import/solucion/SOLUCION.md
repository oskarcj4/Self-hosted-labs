# Solución — Importador XML con XXE (vía BLUE)

> Solo el arreglo. La lectura por XXE (RED) la resuelves tú.

## Causa

XML permite declarar entidades en una DTD, y una entidad `SYSTEM` puede
apuntar a un recurso externo (`file://`, `http://`). El parser estaba montado
con `resolve_entities=True` y `load_dtd=True`: al encontrar `&xxe;` en el
documento, lee el fichero y mete su contenido en el árbol, que acaba en la
respuesta. Es XXE (XML External Entity).

Variantes del mismo fallo: SSRF por entidad `http://` hacia un interno, lectura
de ficheros, y DoS por "billion laughs" (entidades anidadas que explotan en
memoria).

## Arreglo

```python
parser = etree.XMLParser(resolve_entities=False, load_dtd=False, no_network=True)
```

En otros stacks:
- **Python stdlib**: usa `defusedxml` en vez de `xml.etree`/`minidom`/`sax`.
- **Java**: `setFeature("http://apache.org/xml/features/disallow-doctype-decl", true)`.
- **.NET**: `XmlReaderSettings.DtdProcessing = DtdProcessing.Prohibit`.

## Lecciones

- Si no necesitas DTDs ni entidades (casi nunca en una API), desactívalas.
- La regla general de XXE: prohíbe el `DOCTYPE`. Sin DTD no hay entidades que
  explotar.
- Mínimo privilegio otra vez: la app como `app`, no root; el XXE lee lo que
  `app` puede leer, no todo el host.
