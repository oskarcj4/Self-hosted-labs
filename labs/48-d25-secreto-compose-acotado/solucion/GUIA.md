# Resolución guiada · Día 25

:::piensa Antes de tocar nada
Mínimo privilegio también vale para secretos: **cada servicio, sólo los suyos**. Los anclajes de YAML (`&app` / `<<: *app`) ahorran repetir líneas, pero también copian cosas sin que se vean. El YAML que escribes no es el que Compose aplica: el que aplica es el **expandido**.
:::

## Paso 1 · ¿A quién llega el secreto de verdad?

**Pregúntate:** ¿cómo veo la configuración con los anclajes ya resueltos?

:::pista Cómo comprobarlo
```bash
cd ~/analytics
cat compose.yaml
docker compose config
for s in web worker reporter upstream; do echo "== $s"; docker compose exec $s ls /run/secrets 2>&1; done
```
Fíjate en qué bloque está `secrets:` en el YAML original: si está en el anclaje común, lo hereda todo el que lo use.
:::

## Paso 2 · ¿Quién lo usa?

**Pregúntate:** de los servicios que lo reciben, ¿cuál se autentica contra la API externa? Sólo ése lo necesita.

## Paso 3 · Mueve el secreto del anclaje al servicio

:::pista Cómo hacerlo
Quita `secrets:` del bloque `x-app` y añádelo sólo en `reporter`:
```yaml
  reporter:
    <<: *app
    environment:
      ROLE: reporter
    secrets:
      - api_token
```
La sección `secrets:` de nivel superior (la que dice de qué fichero sale) se queda igual.
```bash
docker compose config | grep -n -B3 api_token
docker compose up -d
```
:::

## Paso 4 · Verifica

```bash
for s in web worker upstream; do echo "== $s"; docker compose exec $s ls /run/secrets 2>&1; done
sleep 6; docker compose exec reporter cat /tmp/status
curl -s -o /dev/null -w '%{http_code}\n' localhost:8080
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Revisa siempre `docker compose config`**, no sólo el YAML: anclajes, `extends` y overrides cambian el resultado.
- **Secretos por servicio**, nunca en bloques comunes.
- Si `web` (expuesto) tuvo el token, en un caso real hay que **rotarlo**.

## Si te atascas

- `docker compose config` da error: revisa la indentación de `secrets:` dentro de `reporter`.
