# Resolución guiada · Lab 98 (vía BLUE)

:::piensa
Solo doy el arreglo. La inyección (red) es tuya; el validador la reconoce.
:::

## El fallo

```python
cmd = "getent hosts " + host
subprocess.run(cmd, shell=True, ...)
```

`shell=True` hace que `;`, `|`, `&&`, `$()` y `` `` `` los interprete `/bin/sh`.
El `host` deja de ser un dato y pasa a ser parte del comando.

## El arreglo: sin shell + lista blanca de formato

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

Pasar una **lista** (sin `shell=True`) manda `host` como un único argumento:
no hay shell que interprete metacaracteres. La validación de formato es la
segunda capa.

```bash
nano /srv/app/app.py
app-reload
bash /opt/lab/check.sh blue
```
