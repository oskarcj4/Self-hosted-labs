# Resolución guiada · Lab 97 (vía BLUE)

:::piensa
La única solución que doy es la del arreglo. La captura (red) es tuya: el
validador comprueba que la lograste, no te dice cómo.
:::

## El fallo

En `check_login` la consulta se arma con `%`:

```python
q = ("SELECT username, role, flag FROM users "
     "WHERE username = '%s' AND password = '%s'" % (user, password))
rows = cur.execute(q).fetchall()
```

El usuario forma parte del **código** SQL, no de los datos. Una comilla cierra
el literal y lo que sigue es sintaxis.

## El arreglo: placeholders

Deja que el driver separe código de datos. La entrada nunca se interpola:

```python
q = ("SELECT username, role, flag FROM users "
     "WHERE username = ? AND password = ?")
rows = cur.execute(q, (user, password)).fetchall()
```

```bash
nano /srv/app/app.py     # cambia esas dos líneas
app-reload
bash /opt/lab/check.sh blue
```

## Comprueba tú mismo

```bash
# legítimo: entra
curl -s --data-urlencode "user=ana" --data-urlencode "password=Primavera2024" \
     http://127.0.0.1:8080/login
# inyección: ahora 401, sin flag
curl -s --data-urlencode "user=' OR '1'='1" --data-urlencode "password=x" \
     http://127.0.0.1:8080/login
```
