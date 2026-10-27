# Resolución guiada · Lab 100 (vía BLUE)

:::piensa
Solo doy el arreglo. La falsificación (red) es tuya; el validador la reconoce.
:::

## El fallo

```python
alg = header.get("alg")
if alg == "none":
    return payload          # acepta el token sin comprobar firma
```

El verificador deja que el **token** diga cómo verificarse. Quien crea el
token elige `alg`, así que elige no tener firma.

## El arreglo: el servidor fija el algoritmo

```python
if header.get("alg") != "HS256":
    return None
expected = b64u(hmac.new(SECRET, (h_b + "." + p_b).encode(),
                         hashlib.sha256).digest()).decode()
if hmac.compare_digest(expected, s_b):
    return payload
return None
```

El algoritmo esperado es una decisión del servidor, no un dato del token. Sin
una firma HS256 válida con el secreto, el token no vale.

```bash
nano /srv/app/app.py
app-reload
bash /opt/lab/check.sh blue
```
