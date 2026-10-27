# Solución — Gateway con SSRF (vía BLUE)

> Solo el arreglo. La captura (RED) la resuelves tú.

## Causa

El fetcher deja que el cliente elija el destino y, encima, añade la cabecera
`X-Internal-Auth`. El atacante no conoce ese secreto, pero no lo necesita:
hace que el gateway haga la petición por él. Eso es SSRF, y aquí además
atraviesa la confianza "la llamada viene del gateway".

## Arreglo: allowlist estricta

```python
ALLOW = {("api.internal", 8090)}
p = urlparse(url); port = p.port or (443 if p.scheme=="https" else 80)
if p.scheme not in ("http","https") or (p.hostname, port) not in ALLOW:
    raise ValueError("destino no permitido")
```

- **Host + puerto**, no solo host: `api.internal` = `127.0.0.1`, así que sin
  el puerto el interno (`:9000`) seguiría alcanzable.
- **Esquema**: bloquea `file://`, `gopher://`, `dict://`, etc.

## Lo que una allowlist simple todavía no cubre

- **Redirecciones**: si el destino permitido responde 302 a un interno,
  `urlopen` lo sigue. Desactiva redirects o revalida cada salto.
- **DNS rebinding / TOCTOU**: el nombre se resuelve dos veces; un atacante que
  controle el DNS puede apuntar primero a lo permitido y luego al interno.
  Resuelve una vez, valida la IP y conéctate a esa IP.
- **Metadata de nube** (`169.254.169.254`): el caso real de este arquetipo.
  Bloquea rangos privados/link-local además de la allowlist.

## Lecciones

- En SSRF, el servidor es el que ataca: valida **a dónde** sale, no solo qué
  entra.
- Allowlist por host+puerto (y a ser posible IP resuelta) vence a la blocklist.
- No inyectes credenciales de confianza en peticiones cuyo destino controla el
  usuario: ese es el eslabón que convierte un SSRF en acceso autenticado.
