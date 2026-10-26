# Resolución guiada (BLUE) · SSRF en el proxy de estado

:::piensa Antes de tocar nada
El proxy trae URLs desde el servidor con `/fetch?url=...`. Si no restringe el
destino, el usuario elige adónde apunta el servidor, incluido su propio
`127.0.0.1:8081` (el metadata interno). Eso es SSRF. Tu trabajo no es sacar las
banderas: es **cerrar el destino interno sin romper el health legítimo**. Cerrar
y no romper: las dos cosas cuentan.
:::

## Paso 1 · Entiende cómo decide /fetch

**Pregúntate:** ¿con qué condición permite o niega un destino?

:::pista Dónde mirar
```bash
cat /srv/app/app.py            # busca /fetch, restrict_targets, allowlist
cat /etc/panel/config.json     # restrict_targets=false  <- vulnerable
```
Con `restrict_targets: false` trae cualquier URL. La allowlist ya existe pero no
se aplica.
:::

## Paso 2 · Confirma el SSRF

**Pregúntate:** ¿llega el proxy al metadata interno?

:::pista Cómo comprobarlo
```bash
curl -s 'http://127.0.0.1:8080/fetch?url=http://127.0.0.1:8081/user'   # sale TCLAB{ (mal)
```
:::

## Paso 3 · Activa la allowlist (default-deny)

**Pregúntate:** ¿deniego lista negra de IPs, o permito solo lo que sé bueno?
Permite solo lo bueno: la denylist siempre se esquiva.

:::pista Cómo hacerlo
```bash
cat > /etc/panel/config.json <<'JSON'
{
  "restrict_targets": true,
  "allowlist": ["http://status.lab:8080/health"]
}
JSON
app-reload
```
:::

## Paso 4 · Verifica que cerraste y NO rompiste

```bash
curl -s 'http://127.0.0.1:8080/fetch?url=http://127.0.0.1:8081/user'    # 403, sin TCLAB
curl -s 'http://127.0.0.1:8080/fetch?url=http://status.lab:8080/health'  # OK
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Allowlist > denylist**: una lista corta de destinos buenos es robusta;
  bloquear IPs internas se esquiva con DNS rebinding, IPv6 o redirects.
- **Valida tras resolver DNS y tras cada redirect**, no solo la cadena que
  escribió el usuario.
- **El metadata no debe confiar en "viene de loopback"**: pide autenticación.
- **Segmenta la red**: el proxy no debería tener ruta a la red interna.

## Si te atascas

- El health legítimo da 403 → su URL no está EXACTA en la allowlist (debe ser
  `http://status.lab:8080/health`, carácter por carácter).
- El metadata sigue filtrando → `restrict_targets` no quedó en `true`, o no
  recargaste con `app-reload`.
- `app-reload: command not found` → usa `sudo /usr/local/bin/app-apply`.
