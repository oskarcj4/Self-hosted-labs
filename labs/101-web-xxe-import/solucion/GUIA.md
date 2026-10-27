# Resolución guiada · Lab 101 (vía BLUE)

:::piensa
Solo doy el arreglo. El XXE (red) es tuyo; el validador lo reconoce.
:::

## El fallo

```python
parser = etree.XMLParser(resolve_entities=True, load_dtd=True, no_network=False)
```

Cargar la DTD y resolver entidades permite declarar
`<!ENTITY xxe SYSTEM "file:///...">` y que el parser lea ese fichero al
expandir `&xxe;`.

## El arreglo: parser sin entidades externas

```python
parser = etree.XMLParser(resolve_entities=False, load_dtd=False, no_network=True)
root = etree.fromstring(xml_bytes, parser)
```

- `resolve_entities=False`: no expande entidades.
- `load_dtd=False`: ignora la DTD donde se declaran.
- `no_network=True`: ni siquiera intenta buscar DTDs/entidades por red.

El import de XML normal (sin entidades) sigue funcionando.

```bash
nano /srv/app/app.py
app-reload
bash /opt/lab/check.sh blue
```
