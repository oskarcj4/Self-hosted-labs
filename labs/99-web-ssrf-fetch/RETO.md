# Gateway con SSRF

> Web · OWASP A10 SSRF · doble vía (red / blue) · arquetipo HTB fácil/media
> "fetcher de URLs que alcanza servicios internos"

## Escenario

El gateway corre tres servicios en `localhost` (todos dentro de esta máquina):

| puerto | servicio        | ruta        | quién debería usarlo |
|--------|-----------------|-------------|----------------------|
| 8080   | fetcher público | `/fetch?url=` | el frontend |
| 8090   | `api.internal`  | `/status`   | solo el gateway |
| 9000   | metadata interno| `/flag`     | **nunca** desde fuera |

El fetcher pide **cualquier** URL que le mandes y le añade la cabecera
`X-Internal-Auth` que los servicios internos exigen. Ese secreto solo lo
conoce el proceso `app` (está en `/srv/app/.env`, que no puedes leer). Por eso
curlear `:9000` a mano te da `403`: te falta la cabecera. El fetcher, en
cambio, la pone por ti.

Eres `analista`, sin sudo. La flag la sirve el metadata interno.

## Dos formas de resolverlo

### 🔴 RED — captura la flag
Haz que el fetcher pida por ti la URL del servicio interno. Guarda la flag:

```bash
echo 'TCLAB{...}' > ~/flag.txt
bash /opt/lab/check.sh red
```

### 🔵 BLUE — arregla la vulnerabilidad
Edita `/srv/app/app.py` para que el fetcher solo acepte el destino legítimo
(`api.internal:8090`). Debe seguir devolviendo su `/status`, pero no alcanzar
`:9000` ni otros internos.

```bash
nano /srv/app/app.py
app-reload
bash /opt/lab/check.sh blue
```

## Reconocimiento

```bash
curl -s "http://127.0.0.1:8080/fetch?url=http://api.internal:8090/status"
curl -s "http://127.0.0.1:9000/flag"      # directo: 403 (sin la cabecera)
# ¿a qué más puede llegar el fetcher por ti?
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
