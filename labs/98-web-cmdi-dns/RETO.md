# Herramienta de red con command injection

> Web · OWASP A03 Injection (OS command) · doble vía (red / blue) · arquetipo
> HTB fácil "parámetro que acaba en una shell"

## Escenario

El panel de operaciones expone una herramienta de resolución de hosts en
`http://127.0.0.1:8080`. El endpoint `/run?host=...` ejecuta
`getent hosts <host>` **a través de una shell** (`shell=True`), con el
parámetro `host` sin validar.

Corre como el usuario `app`. Tú eres `analista`, **sin sudo**. La flag está en
`/srv/app/flag.txt`, legible solo por `app`: tienes que hacer que la app la lea
por ti (o cerrar el agujero).

## Dos formas de resolverlo

### 🔴 RED — captura la flag
Inyecta un comando en `host` que lea `/srv/app/flag.txt` y aparezca en la
respuesta. Guárdala:

```bash
echo 'TCLAB{...}' > ~/flag.txt
bash /opt/lab/check.sh red
```

### 🔵 BLUE — arregla la vulnerabilidad
Edita `/srv/app/app.py` para no usar shell y validar `host`. Debe seguir
resolviendo `localhost`, pero los metacaracteres (`;`, `|`, `` ` ``, `$()`)
no deben ejecutar nada.

```bash
nano /srv/app/app.py
app-reload
bash /opt/lab/check.sh blue
```

## Reconocimiento

```bash
curl -s "http://127.0.0.1:8080/run?host=localhost"
# ¿y si host lleva un ';' detrás?
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
