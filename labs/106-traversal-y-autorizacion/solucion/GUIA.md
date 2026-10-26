# Resolución guiada (BLUE) · Path traversal + bypass de autorización

:::piensa Antes de tocar nada
Dos fugas, las dos de control de acceso: `/download` deja salir de `/srv/docs`
con `../`, y `/admin` concede acceso porque el cliente manda `X-Admin: true`. Las
dos confían en algo que controla quien pide. Tu trabajo no es sacar las banderas:
es **cerrar las dos puertas sin romper la descarga legítima**. Cerrar y no
romper: las dos cosas cuentan.
:::

## Paso 1 · Entiende qué decide la app

**Pregúntate:** ¿qué claves de la config gobiernan cada endpoint?

:::pista Dónde mirar
```bash
cat /srv/app/app.py            # /download usa sanitize_path; /admin usa trust_admin_header
cat /etc/panel/config.json     # las dos en el valor inseguro
```
:::

## Paso 2 · Confirma las dos fugas

**Pregúntate:** ¿llego al fichero privado? ¿me cuela la cabecera?

:::pista Cómo comprobarlo
```bash
curl -s 'http://127.0.0.1:8080/download?file=../private/user.flag'  # sale TCLAB{ (mal)
curl -s -H 'X-Admin: true' http://127.0.0.1:8080/admin             # sale TCLAB{ (mal)
```
:::

## Paso 3 · Cierra las dos (y NO rompas la descarga)

**Pregúntate:** ¿confino la ruta y dejo de creer al cliente?

:::pista Cómo hacerlo
```bash
cat > /etc/panel/config.json <<'JSON'
{
  "sanitize_path": true,
  "trust_admin_header": false
}
JSON
app-reload
```
:::

## Paso 4 · Verifica

```bash
curl -s 'http://127.0.0.1:8080/download?file=../private/user.flag'  # 403, sin TCLAB
curl -s 'http://127.0.0.1:8080/download?file=readme.txt'            # sigue OK
curl -s -H 'X-Admin: true' http://127.0.0.1:8080/admin             # 403
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Path traversal**: normaliza la ruta y confírmala dentro del directorio base;
  mejor aún, no concatenes entrada del usuario: usa un id y un mapa a ficheros
  (OWASP A01).
- **Autorización**: decídela en el servidor con el rol real del usuario
  autenticado, en cada petición; nunca por cabeceras/cookies/campos que manda el
  cliente (OWASP A01).
- **Endurecer ≠ romper**: tras cerrar, comprueba que lo legítimo sigue pasando.

## Si te atascas

- `readme.txt` deja de descargarse → el saneado quedó demasiado estricto o el
  JSON está mal escrito; revisa `cat /etc/panel/config.json` y `app-reload`.
- `/admin` sigue colando → `trust_admin_header` no quedó en `false`, o no
  recargaste.
- `/download` sigue leyendo `/srv/private` → `sanitize_path` no quedó en `true`.
- `app-reload: command not found` → usa `sudo /usr/local/bin/app-apply`.
