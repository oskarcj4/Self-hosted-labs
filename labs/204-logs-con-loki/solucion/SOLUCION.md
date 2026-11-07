# Solución — Logs con Loki

`/etc/promtail/config.yml` (las partes que cambian):

```yaml
  - job_name: pagos
    static_configs:
      - targets: [localhost]
        labels:
          app: pagos
          __path__: /var/log/tienda/pagos.log      # antes: pagos/*.log
    pipeline_stages:
      - replace:                                    # tarjeta=****1111
          expression: 'tarjeta=(\d{8,15})\d{4}\b'
          replace: '****'
      - json:
          expressions:
            nivel: level
      - labels:
          nivel:                                    # fuera pedido y user_id

  - job_name: catalogo
    ...
    pipeline_stages:
      - multiline:
          firstline: '^\d{4}-\d{2}-\d{2} '
          max_wait_time: 3s
      - regex:
          expression: '^\S+ \S+ (?P<nivel>[A-Z]+) catalogo'
      - template:
          source: nivel
          template: '{{ ToLower .Value }}'
      - labels:
          nivel:                                    # fuera ip
```

Después: `sudo systemctl restart promtail`.

Consultas:

```
# ~/consultas/pagos-lentos.logql
{app="pagos"} | json | duration_ms > 1000

# ~/consultas/errores-por-app.logql
sum by (app) (count_over_time({app=~".+", nivel="error"}[1m]))
```

Con esto quedan unos 5 streams (pagos × 3 niveles, catálogo × 3) en lugar
de uno por IP o por pedido. Las trazas llegan enteras y ningún número de
tarjeta sale de la máquina.
