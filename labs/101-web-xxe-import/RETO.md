# Importador XML con XXE

> Web · OWASP A05 (XXE) · doble vía (red / blue) · arquetipo HTB fácil/media
> "parser XML que resuelve entidades externas"

## Escenario

El importador recibe perfiles en XML en `http://127.0.0.1:8080`:

```bash
curl -s --data-binary '<user><name>ana</name></user>' http://127.0.0.1:8080/import
# -> hola ana
```

El parser (`lxml`) se montó con la carga de DTD y la resolución de **entidades
externas** activadas. Una entidad externa puede apuntar a un fichero del
servidor y colar su contenido en la respuesta.

Corre como `app`. Eres `analista`, sin sudo. La flag está en
`/srv/app/flag.txt`, legible solo por `app`.

## Dos formas de resolverlo

### 🔴 RED — captura la flag
Manda un XML que defina una entidad externa hacia `/srv/app/flag.txt` y haga
que el servidor la devuelva. Guárdala:

```bash
echo 'TCLAB{...}' > ~/flag.txt
bash /opt/lab/check.sh red
```

### 🔵 BLUE — arregla la vulnerabilidad
Edita `/srv/app/app.py` para que el parser no cargue DTD ni resuelva entidades
externas. El import normal (`<name>ana</name>`) debe seguir funcionando.

```bash
nano /srv/app/app.py
app-reload
bash /opt/lab/check.sh blue
```

## Reconocimiento

```bash
curl -s --data-binary '<user><name>ana</name></user>' http://127.0.0.1:8080/import
# estructura de una entidad: <!DOCTYPE x [ <!ENTITY e SYSTEM "file:///..."> ]>
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
