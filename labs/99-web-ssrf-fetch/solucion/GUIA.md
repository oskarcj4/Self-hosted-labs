# Resolución guiada · Lab 99 (vía BLUE)

:::piensa
Solo doy el arreglo. El SSRF (red) es tuyo; el validador lo reconoce.
:::

## El fallo

```python
def do_fetch(url):
    req = urllib.request.Request(url, headers={"X-Internal-Auth": AUTH})
    return urllib.request.urlopen(req, timeout=4).read()...
```

El servidor busca el destino que elige el cliente. Como además inyecta la
cabecera de confianza, se convierte en un "confused deputy": presta su
identidad para alcanzar servicios internos.

## El arreglo: allowlist de host + puerto

```python
ALLOW = {("api.internal", 8090)}

def do_fetch(url):
    p = urlparse(url)
    port = p.port or (443 if p.scheme == "https" else 80)
    if p.scheme not in ("http", "https") or (p.hostname, port) not in ALLOW:
        raise ValueError("destino no permitido: %s" % url)
    ...
```

Ojo: la allowlist lleva **puerto**. Si solo validas el host, `api.internal`
resuelve a `127.0.0.1`, y `http://api.internal:9000/flag` seguiría llegando al
interno.

```bash
nano /srv/app/app.py
app-reload
bash /opt/lab/check.sh blue
```
