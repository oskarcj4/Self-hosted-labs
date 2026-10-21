# Resolución guiada · Día 04

:::piensa Antes de tocar nada
En nginx muchas directivas se **heredan**: lo que pones en `http` vale para todos los `server`, y lo que pones en `server` vale para todos sus `location`, salvo que uno lo cambie. Si un listado sigue apareciendo después de "quitarlo", es que viene de un nivel superior.
:::

## Paso 1 · Reproduce el problema

**Pregúntate:** ¿qué rutas muestran listado? Pruébalas todas, no sólo la que te reportaron.

:::pista Cómo comprobarlo
```bash
IP=$(hostname -I | awk '{print $1}')
for u in /downloads/ /downloads/drivers/ /downloads/internal/ /assets/; do
  printf '%-24s ' "$u"; curl -s http://$IP$u | grep -q 'Index of' && echo LISTADO || echo ok
done
```
:::

## Paso 2 · Encuentra todas las fuentes

**Pregúntate:** ¿en qué ficheros y en qué nivel (`http`, `server`, `location`) aparece `autoindex on`?

:::pista Cómo comprobarlo
```bash
sudo nginx -T | grep -nE '^# configuration file|autoindex|location|server \{|http \{'
```
Para cada `autoindex on`, anota el fichero y el bloque que lo contiene. Si uno está en un fichero de `conf.d/`, probablemente está a nivel `http`: afecta a **todo**.
:::

## Paso 3 · Desactívalas todas

**Pregúntate:** ¿borro las líneas o las pongo en `off`? Las dos cosas funcionan (`off` es el valor por defecto). Ponerlas en `off` deja claro que fue intencionado.

:::pista Cómo hacerlo
```bash
sudo sed -i 's/autoindex on;/autoindex off;/' <cada fichero que encontraste>
sudo nginx -t && sudo systemctl reload nginx
sudo nginx -T | grep 'autoindex on' || echo "sin listados"
```
:::

## Paso 4 · Verifica lo que debe dar error y lo que no

**Pregúntate:** ¿he roto las descargas? El listado debe dar `403`/`404`, pero los ficheros enlazados deben seguir dando `200`.

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://$IP/downloads/
curl -s http://$IP/ | grep -o 'href="[^"]*"'    # qué ficheros están enlazados
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Busca la directiva en la config efectiva** (`nginx -T`), no fichero a fichero.
- **Piensa en herencia**: `http` → `server` → `location`.
- **Quitar el listado no protege `internal/`**: si alguien adivina la URL del fichero, lo descarga. Lo correcto es sacar ese material del docroot.

## Si te atascas

- Quitaste los de `location` y `/downloads/` sigue listando: hay uno a nivel `http` (mira `conf.d/`).
