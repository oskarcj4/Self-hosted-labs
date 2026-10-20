# Solución — Día 20: Mantener interna una base de datos

## 1. Comprobar la exposición

```bash
cd ~/inventory
docker compose ps                         # db: 0.0.0.0:5432->5432/tcp
exec 3<>/dev/tcp/$(hostname -i)/5432; echo DUMP >&3; timeout 1 cat <&3
# sku,stock,coste ...                     <- datos desde fuera, sin credenciales
```

## 2. Quitar la publicación de `db`

```yaml
  db:
    image: inventory/app:2.0
    environment:
      ROLE: db
    restart: unless-stopped
```

(Se borra el bloque `ports:` entero del servicio `db`.)

```bash
docker compose up -d       # recrea sólo 'db'
```

## 3. Verificar

```bash
docker compose ps                                 # db sin puertos
timeout 2 bash -c "exec 3<>/dev/tcp/$(hostname -i)/5432" || echo cerrado
curl -s http://$(hostname -i):8000/               # inventario api — db: PONG
```

La API sigue llegando a `db:5432` porque ambos servicios comparten la red del proyecto.

## Lecciones

- Las bases de datos no se publican: viven en la red interna, detrás de la app.
- Los "temporales" de una migración (puertos, usuarios, reglas) deben tener
  fecha de retirada y alguien que la ejecute.
- Para administración puntual: `docker compose exec`, un túnel SSH o
  `127.0.0.1:5432:5432` mientras dure la tarea.
