# Resolución guiada (BLUE) · Credenciales por defecto y errores verbosos

:::piensa Antes de tocar nada
Dos fugas, las dos en configuración, no en código: una contraseña por defecto
en el panel y errores verbosos que filtran un secreto por `/debug`. Tu trabajo
no es entrar al panel: es **cerrar las dos puertas sin romper el panel** para
quien tiene la contraseña buena. Cerrar y no romper: las dos cosas cuentan.
:::

## Paso 1 · Entiende qué lee la app

**Pregúntate:** ¿qué claves de la config decide el comportamiento?

:::pista Dónde mirar
```bash
cat /srv/app/app.py        # legible: busca config.json
cat /etc/panel/config.json # panel_pass y verbose_errors
```
`panel_pass` es la contraseña del panel; `verbose_errors` decide si `/debug`
suelta el traceback entero.
:::

## Paso 2 · Confirma las dos fugas

**Pregúntate:** ¿entra la contraseña por defecto? ¿filtra el error?

:::pista Cómo comprobarlo
```bash
curl -s -u admin:admin http://127.0.0.1:8080/panel   # entra (mal)
curl -s 'http://127.0.0.1:8080/debug?q=x'            # traceback con TCLAB{ (mal)
```
:::

## Paso 3 · Pon una contraseña fuerte

**Pregúntate:** ¿aleatoria y larga, o algo que también se adivina?

:::pista Cómo hacerlo
```bash
NEWPASS=$(head -c18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c20)
```
Guárdala; la necesitas para comprobar que el panel sigue vivo.
:::

## Paso 4 · Calla los errores verbosos

**Pregúntate:** ¿qué necesita ver el cliente de un 500? Nada más que el 500.

:::pista Cómo hacerlo
```bash
cat > /etc/panel/config.json <<EOF
{
  "panel_pass": "$NEWPASS",
  "verbose_errors": false
}
EOF
app-reload
```
:::

## Paso 5 · Verifica que cerraste y NO rompiste

```bash
curl -s -u admin:admin http://127.0.0.1:8080/panel        # 401
curl -s -u "admin:$NEWPASS" http://127.0.0.1:8080/panel   # 200
curl -s 'http://127.0.0.1:8080/debug?q=x'                 # sin TCLAB{
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Credenciales por defecto**: cámbialas el primer día; largas, aleatorias, sin
  reutilizar. Es la primera puerta que prueba un atacante (OWASP A07).
- **Errores en producción**: `debug=off`. El detalle va al log interno, nunca al
  cuerpo de la respuesta (OWASP A05).
- **Endurecer ≠ romper**: tras cerrar, comprueba siempre que lo legítimo sigue
  funcionando.

## Si te atascas

- `/panel` da 401 también con la contraseña nueva → el JSON quedó mal escrito;
  `cat /etc/panel/config.json` y revisa comillas/comas, luego `app-reload`.
- `/debug` sigue filtrando → `verbose_errors` no quedó en `false`, o no
  recargaste con `app-reload`.
- `app-reload: command not found` → usa `sudo /usr/local/bin/app-apply`.
