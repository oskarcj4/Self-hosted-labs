# Resolución guiada (BLUE) · Panel con fuga de artefacto + modo debug

:::piensa Antes de tocar nada
Juegas BLUE: tienes shell como `analista` y la pregunta es **cómo cerrar las dos
fugas sin romper lo legítimo**, no cómo explotarlas. Las dos vías viven en
interruptores de `/etc/panel/config.json`: un backup del código servido en el
webroot (expone el token de usuario) y un modo debug que deja `/admin` abierto.
El validador hace HTTP al panel: exige que `/` siga en 200 y que `/admin` con el
token legítimo siga funcionando. Arreglar no es apagar el panel.
:::

## Paso 1 · Mira qué sirve el panel

**Pregúntate:** ¿qué rutas responden y cuáles no deberían?

:::pista Cómo comprobarlo
```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/
curl -s http://127.0.0.1:8080/backup/
curl -s http://127.0.0.1:8080/backup/app.py.bak    # fuga: código con un token
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8080/admin   # 200 sin token = debug
```
Un `.bak` del código en el webroot y un `/admin` que entrega sin token: ahí
están las dos vías.
:::

## Paso 2 · Cierra las dos fugas en la config

**Pregúntate:** ¿dónde se controlan? En `/etc/panel/config.json`.

:::pista Cómo hacerlo
```bash
cat /etc/panel/config.json
sed -i 's/"serve_backup": true/"serve_backup": false/' /etc/panel/config.json
sed -i 's/"debug": true/"debug": false/'               /etc/panel/config.json
app-reload        # recarga el panel (sudo acotado)
```
- `serve_backup: false` → `/backup/` y `app.py.bak` dan 404; sin el token
  filtrado, `/area` deja de ser alcanzable.
- `debug: false` → `/admin` vuelve a exigir token (el endpoint sigue vivo para
  quien lo tiene).
:::

## Paso 3 · Verifica

```bash
bash /opt/lab/check.sh
```
Debe quedar: `/` 200, `/backup/` y `.bak` cerrados, `/admin` sin token denegado,
`/admin` con token válido aún 200.

## Cómo actuar en una situación así

- **Artefacto de build fuera del webroot.** `.bak`, `.git/`, `backup.zip`,
  `.tar.gz` sirven código fuente —tokens, rutas, credenciales— a cualquiera.
  Sácalo del despliegue o bloquéalo en el servidor (`location ~ /\.(git|bak)$`).
- **`debug=false` siempre en producción.** El modo debug desactiva controles;
  para el atacante también. Que el `true` sea imposible fuera de desarrollo
  (variable por entorno, no un fichero editable a mano).
- **Arreglar ≠ apagar.** El validador exige que lo legítimo siga vivo: quita
  solo lo que sobra.
- **Rota el secreto filtrado.** El token del `.bak` ya se vio: cerrar la fuga no
  lo vuelve secreto otra vez.

## Si te atascas

- `/admin` con token válido da 403 tras tu cambio → mataste el endpoint; solo
  pon `debug: false`, no toques el token.
- `/backup/app.py.bak` sigue en 200 → ¿editaste el JSON y ejecutaste
  `app-reload`? Revisa que no quedó `true`.
- `check.sh` dice que `/` no responde → el panel no arrancó; mira `/tmp/app.log`.
