# Solución — Día 04: Desactivar el listado de directorios

## 1. Encontrar todas las fuentes de `autoindex`

```bash
sudo nginx -T | grep -n -E '^# configuration file|autoindex'
```

Hay tres:

| Fichero | Nivel | Efecto |
|---|---|---|
| `/etc/nginx/conf.d/00-legacy.conf` | `http` | listado en **todo** el servidor (p.ej. `/assets/`) |
| `sites-available/files` → `location /downloads/` | location | listado de `/downloads/` y `internal/` |
| `sites-available/files` → `location /downloads/drivers/` | location | listado de `drivers/` |

Si sólo quitas los de los `location`, `/downloads/` **sigue listándose**
porque hereda el `autoindex on` del nivel `http`.

## 2. Desactivarlos

```bash
sudo sed -i 's/autoindex on;/autoindex off;/' /etc/nginx/conf.d/00-legacy.conf /etc/nginx/sites-available/files
sudo nginx -t && sudo systemctl reload nginx
```

(También vale borrar las líneas: `autoindex off` es el valor por defecto.
Las directivas `autoindex_exact_size` / `autoindex_localtime` son inocuas sin
`autoindex on`, pero puedes limpiarlas.)

## 3. Verificar

```bash
IP=$(hostname -I | awk '{print $1}')
curl -s -o /dev/null -w '%{http_code}\n' http://$IP/downloads/            # 403
curl -s -o /dev/null -w '%{http_code}\n' http://$IP/downloads/manual-usuario.pdf  # 200
sudo nginx -T | grep 'autoindex on' || echo "sin listados"
```

## Lecciones

- El listado convierte "URL desconocida" en "inventario completo": facilita
  encontrar ficheros que nadie enlazó (`internal/`).
- En nginx, `autoindex` se hereda de `http` → `server` → `location`. Busca
  con `nginx -T`, no fichero a fichero.
- Desactivar el listado **no** protege `internal/`: quien adivine la URL del
  CSV lo descarga. Lo correcto es sacar ese material del docroot.
