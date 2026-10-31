# Solución — HTTP con curl: códigos y tiempos

## Qué pasaba

| Ruta | Código | Motivo |
|---|---|---|
| `/catalogo` | 301 | redirige a `/productos` |
| `/admin` | 403 | prohibido |
| `/interno` | 401 | pide autenticación |
| `/no-existe` | 404 | no existe |
| `/api/pedidos` | 502 | nginx apunta a `127.0.0.1:8001`; el backend escucha en `8081` |

## Arreglo

```bash
U=http://tienda.lab
c(){ curl -s -o /dev/null -w '%{http_code}' "$U$1"; }
L=$(curl -sI $U/catalogo | awk -F': ' 'tolower($1)=="location"{print $2}' | tr -d '\r')
{
  echo "catalogo=$(c /catalogo)"; echo "admin=$(c /admin)"; echo "interno=$(c /interno)"
  echo "no_existe=$(c /no-existe)"; echo "pedidos=$(c /api/pedidos)"; echo "redireccion=$L"
} > ~/codigos.txt
sudo sed -i 's/127.0.0.1:8001/127.0.0.1:8081/' /etc/nginx/sites-available/tienda
sudo nginx -t && sudo systemctl reload nginx && sleep 2
echo "ttfb_pedidos=$(curl -s -o /dev/null -w '%{time_starttransfer}' $U/api/pedidos)" >> ~/codigos.txt
bash /opt/lab/check.sh
```

El backend tarda 1-3 s en responder: ese es el TTFB esperado.

## Más allá del lab

- Un backend lento merece `proxy_read_timeout` explícito y un health check.
- Monitoriza `$upstream_response_time` en el log de nginx.
