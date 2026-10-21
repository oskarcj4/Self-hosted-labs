# Resolución guiada · Día 26

:::piensa Antes de tocar nada
Si el servicio más expuesto (`web`) puede hablar directamente con la base de datos, comprometer `web` es comprometer los datos. Segmentar es dibujar quién habla con quién y dejar que la red sólo permita eso: `web ↔ api ↔ db`, nunca `web ↔ db`.
:::

## Paso 1 · Dibuja el flujo

**Pregúntate:** ¿quién necesita hablar con quién?

| Servicio | Habla con |
|---|---|
| web | api |
| api | web, db |
| db | api |

`api` es el único que está en medio: será el único en las dos redes.

## Paso 2 · Comprueba la situación actual

:::pista Cómo comprobarlo
```bash
cd ~/store
cat compose.yaml
docker network ls | grep store
docker compose exec web python -c "import socket;socket.create_connection(('db',5432),timeout=2);print('web llega a db')"
```
:::

## Paso 3 · Declara las redes y asígnalas

**Pregúntate:** ¿cómo traduzco la tabla a Compose? Una sección `networks:` arriba del todo y una lista `networks:` en cada servicio.

:::pista Cómo hacerlo
```yaml
services:
  web:
    networks: [frontend]
  api:
    networks: [frontend, backend]
  db:
    networks: [backend]

networks:
  frontend:
  backend:
    internal: true
```
(Mantén el resto de cada servicio como estaba.) `internal: true` corta la salida a internet de esa red: útil contra exfiltración desde la base de datos.
```bash
docker compose up -d --remove-orphans
```
:::

## Paso 4 · Verifica el aislamiento y la cadena

**Pregúntate:** ¿qué prueba demuestra que `web` ya no llega a `db`? Y ¿la cadena completa sigue funcionando?

```bash
docker compose exec web python -c "import socket;socket.create_connection(('db',5432),timeout=2)" || echo "web aislado de db"
curl -s localhost:8080
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Dibuja el flujo antes de escribir YAML.**
- **El DNS interno sólo resuelve servicios de tus mismas redes**: si `web` no está en `backend`, ni siquiera sabe qué es `db`.
- **Publicar puertos y redes internas son cosas distintas**: `web` sigue publicada aunque su red sea `frontend`.

## Si te atascas

- La cadena se rompe: comprueba que `api` está en **las dos** redes.
- Quedan contenedores en la red vieja: `--remove-orphans` y `docker network rm store_default`.
