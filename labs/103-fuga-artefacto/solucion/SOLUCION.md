# Solución (BLUE) — Panel con fuga de artefacto + modo debug

> Esta solución es **defensiva**: cómo **cerrar** las dos vías. No es un
> walkthrough de explotación.

## Las dos fugas

El panel lee dos interruptores de `/etc/panel/config.json`:

| Interruptor | Qué abre | Bandera que expone |
|---|---|---|
| `serve_backup: true` | sirve `/backup/` (listado) y `app.py.bak` con un token | user |
| `debug: true` | `/admin` entrega sin pedir token | root |

## El arreglo

```bash
sed -i 's/"serve_backup": true/"serve_backup": false/' /etc/panel/config.json
sed -i 's/"debug": true/"debug": false/'               /etc/panel/config.json
app-reload
bash /opt/lab/check.sh
```

- **`serve_backup: false`** → `/backup/` y `app.py.bak` devuelven 404. Sin el
  token filtrado, `/area` deja de ser alcanzable.
- **`debug: false`** → `/admin` vuelve a exigir el token. El endpoint sigue
  vivo para quien tiene el token legítimo; solo se cierra el bypass.

## Por qué así

- Un **artefacto de build** (`.bak`, `.git/`, `backup.zip`, `.tar.gz`) en el
  webroot es código fuente servido a cualquiera: tokens, rutas internas,
  credenciales. No vive en el directorio público; sácalo del despliegue o
  bloquéalo en el servidor web (`location ~ /\.(git|bak)`).
- El **modo depuración** desactiva controles para facilitar el desarrollo. En
  producción desactiva controles para el atacante. Nunca viaja al despliegue.
- El validador comprueba que **lo legítimo sigue vivo** (`/`, `/admin` con
  token): arreglar no es apagar el servicio, es quitar solo lo que sobra.

## Lecciones

- Separa artefactos de build del contenido público; revisa qué sirve de verdad
  tu webroot (`curl` a las rutas típicas, escaneo de ficheros huérfanos).
- `debug=false` por defecto; que el `true` sea imposible fuera de desarrollo
  (variable de entorno distinta por entorno, no un fichero editable a mano).
- Un secreto filtrado (el token del `.bak`) hay que **rotarlo**: una vez visto,
  cerrar la fuga no basta.
