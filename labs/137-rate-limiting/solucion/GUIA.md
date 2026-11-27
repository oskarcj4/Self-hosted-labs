# Resolución guiada · Lab 137

:::piensa Mide antes de cambiar
Si no tienes un "antes", no puedes demostrar que el límite funciona. Y el
límite tiene que frenar al bot **sin** molestar al usuario normal ni a los
ficheros estáticos: por eso se aplica sólo a la ruta que se ataca.
:::

**El plan:** (1) encontrar al bot, (2) medir sin límite, (3) declarar las
zonas, (4) aplicarlas al login y (5) medir otra vez.

## Paso 1 · ¿Quién machaca el login?

**Objetivo:** la IP que más pide `/api/login`.

:::pista Cómo hacerlo
```bash
sudo awk '$7 ~ /^\/api\/login/ {print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head
```

| Parte | Qué hace |
|---|---|
| `awk '… {print $1}'` | `awk` parte cada línea del log por espacios: `$1` es la IP y `$7` la ruta pedida. |
| `$7 ~ /^\/api\/login/` | Sólo las líneas cuya ruta **empieza** (`^`) por `/api/login`. Las `/` van escapadas (`\/`) porque `/…/` delimita la expresión. |
| `sort \| uniq -c` | Junta las IP iguales (`uniq` sólo junta líneas contiguas, por eso antes `sort`) y cuenta cuántas hay. |
| `sort -rn \| head` | De más a menos, las 10 primeras. |

**Qué deberías ver:** una IP con muchísimas más peticiones que el resto.
Escríbela en `~/limite.txt` como `ip_bot=<IP>`.
:::

## Paso 2 · Mide sin límite

**Objetivo:** guardar cómo responde el login a una ráfaga, antes de tocar nada.

:::pista Cómo hacerlo
```bash
hey -n 300 -c 30 -m POST -d 'usuario=admin&clave=x' http://127.0.0.1/api/login > ~/hey-antes.txt
grep -A4 'Status code' ~/hey-antes.txt
```
**hey** es un generador de carga HTTP:

| Opción | Qué significa |
|---|---|
| `-n 300` | 300 peticiones en total. |
| `-c 30` | 30 clientes a la vez. |
| `-m POST -d '…'` | Método `POST` con ese cuerpo de formulario, como un intento de login. |

**Qué deberías ver:** en *Status code distribution*, las 300 con `[401]`
(credenciales incorrectas). El backend contesta a todas, por rápido que pidan.
:::

## Paso 3 · Declara las zonas

**Objetivo:** las "tablas" donde nginx lleva la cuenta de cada cliente.

**Pregúntate:** las zonas se declaran una vez y se usan donde quieras. ¿En qué
parte de la configuración van? ¿Qué identifica a cada cliente?

:::pista Cómo hacerlo
```bash
sudo tee /etc/nginx/conf.d/limites.conf <<'N'
limit_req_zone  $binary_remote_addr zone=login:10m rate=5r/s;
limit_conn_zone $binary_remote_addr zone=conexiones:10m;
limit_req_status  429;
limit_conn_status 429;
N
```
En Debian, `conf.d/*.conf` se carga dentro del bloque `http`, que es donde
tienen que ir las zonas.

| Directiva | Qué significa |
|---|---|
| `$binary_remote_addr` | La clave de la cuenta: la IP del cliente (en binario, ocupa menos). |
| `zone=login:10m` | Nombre de la zona y memoria (10 MB ≈ 160 000 IP). |
| `rate=5r/s` | 5 peticiones por segundo por IP. |
| `limit_conn_zone … zone=conexiones` | Otra tabla, para contar conexiones abiertas **a la vez** por IP. |
| `limit_*_status 429` | Qué responder al que se pasa. Por defecto es `503`, que parece una caída; `429 Too Many Requests` dice la verdad. |
:::

## Paso 4 · Aplícalas sólo al login

**Objetivo:** que el límite afecte a `/api/login` y a nada más.

:::pista Cómo hacerlo
```bash
sudo nano /etc/nginx/sites-available/web
```
Dentro del bloque `location /api/login`, encima de `proxy_pass`:
```nginx
location /api/login {
    limit_req zone=login burst=10 nodelay;
    limit_conn conexiones 10;
    proxy_pass http://127.0.0.1:9137;
}
```

| Directiva | Qué significa |
|---|---|
| `limit_req zone=login` | Aplica a esta ruta el ritmo de la zona `login`. |
| `burst=10` | Tolera hasta 10 peticiones por encima del ritmo, como ráfaga. |
| `nodelay` | Las de la ráfaga se sirven al momento, sin hacerlas esperar en cola. Lo que pase de la ráfaga recibe `429`. |
| `limit_conn conexiones 10` | Máximo 10 conexiones simultáneas por IP. |

Como sólo está en `location /api/login`, `/static/` y el resto no se ven
afectados.
```bash
sudo nginx -t && sudo systemctl reload nginx
```
`nginx -t` comprueba la configuración sin aplicarla; `reload` la aplica sin
cortar conexiones.
:::

## Paso 5 · Mide otra vez

```bash
hey -n 300 -c 30 -m POST -d 'usuario=admin&clave=x' http://127.0.0.1/api/login > ~/hey-despues.txt
grep -A4 'Status code' ~/hey-despues.txt
sudo tail -n 20 /var/log/nginx/access.log | grep ' 429 '
bash /opt/lab/check.sh
```
**Qué deberías ver:** unos pocos `[401]` (las que pasaron el límite) y la
mayoría `[429]`. En el log, el bot también recibe `429`.

## Cómo actuar en una situación así

- **Límites distintos por ruta:** el login es caro y atacable; los estáticos no.
- **Detrás de un proxy o CDN**, `$binary_remote_addr` es la IP del proxy, y
  limitarías a todos a la vez. Usa `set_real_ip_from` y `real_ip_header`.
- Un límite por IP no frena una botnet con miles de IP: complementa con
  fail2ban sobre los 429, bloqueo por cuenta y CAPTCHA.

## Si te atascas

- **Sale 503 en vez de 429:** falta `limit_req_status 429;`.
- **`nginx -t`: `"limit_req_zone" directive is not allowed here`:** pusiste la
  zona dentro de `server` o `location`. Va en `conf.d/`.
- **`nginx -t`: `zero size shared memory zone "login"`:** usas una zona que no
  existe o tiene otro nombre.
- **`/static/` también da 429:** pusiste el límite a nivel de `server`.
