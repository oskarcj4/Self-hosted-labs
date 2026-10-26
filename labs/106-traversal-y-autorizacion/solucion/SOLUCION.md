# Solución BLUE — Path traversal + bypass de autorización

> Solo la vía defensiva: cerrar las dos cosas sin romper la descarga legítima.

## El diagnóstico

`/srv/app/app.py` lee dos claves de `/etc/panel/config.json`:

- `sanitize_path`: si es `false`, `/download` hace `open(DOCS + file)` sin
  comprobar que el resultado siga dentro de `/srv/docs`. Con `../private/user.flag`
  se sale del directorio y lee el fichero privado (**path traversal**).
- `trust_admin_header`: si es `true`, `/admin` concede acceso cuando el cliente
  manda `X-Admin: true`. El cliente controla esa cabecera, así que no autentica
  nada (**broken access control**).

Las dos son configuración; se arreglan en el JSON.

## El arreglo

```bash
cat > /etc/panel/config.json <<'JSON'
{
  "sanitize_path": true,
  "trust_admin_header": false
}
JSON
app-reload
```

Verifica:

```bash
curl -s 'http://127.0.0.1:8080/download?file=../private/user.flag'  # 403, sin TCLAB
curl -s 'http://127.0.0.1:8080/download?file=readme.txt'            # sigue funcionando
curl -s -H 'X-Admin: true' http://127.0.0.1:8080/admin             # 403, sin TCLAB
bash /opt/lab/check.sh
```

## Por qué funciona

- **Traversal**: con `sanitize_path: true`, la app normaliza la ruta
  (`os.path.normpath`) y comprueba que siga empezando por `/srv/docs/`. Cualquier
  `../` que se escape se rechaza con 403. La descarga de `readme.txt` sigue
  dentro del directorio, así que no se rompe.
- **Autorización**: con `trust_admin_header: false`, `/admin` deja de conceder
  acceso por una cabecera del cliente. La autorización debe decidirse en el
  servidor (sesión/rol verificado), nunca con un dato que manda quien pide.

## Defensa en profundidad (más allá del lab)

- No construyas rutas concatenando entrada del usuario; usa un identificador y
  un mapa a ficheros, o valida contra una allowlist de nombres.
- La autorización se comprueba en el servidor en cada petición, con el rol real
  del sujeto autenticado; nunca con cabeceras, cookies no firmadas o campos
  ocultos que el cliente puede cambiar.

## Lecciones

- Path traversal: normaliza y confina dentro del directorio base (OWASP A01).
- No te fíes de datos del cliente para autorizar (OWASP A01).
- Cerrar sin romper: la descarga legítima debe seguir pasando.
