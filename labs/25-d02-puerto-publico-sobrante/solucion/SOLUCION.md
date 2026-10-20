# Solución — Día 02: Quitar un puerto público innecesario

## 1. ¿Quién tiene el 8080 y desde dónde se declara?

```bash
sudo ss -tlnp | grep 8080          # -> nginx
sudo nginx -T | grep -n 'listen'
```

`nginx -T` vuelca la configuración **efectiva** (todos los includes). Aparecen
dos declaraciones del 8080:

- `sites-enabled/compat-test` → un `server` entero de la prueba de compatibilidad.
- `sites-enabled/shop` → una línea `listen 8080;   # compat` dentro del sitio bueno.

Si sólo quitas una, nginx sigue escuchando en el 8080.

## 2. Retirar las dos

```bash
sudo rm /etc/nginx/sites-enabled/compat-test          # desactiva el sitio (queda en sites-available)
sudo sed -i '/listen 8080;/d' /etc/nginx/sites-available/shop
sudo nginx -t && sudo systemctl reload nginx
```

## 3. Verificar

```bash
sudo ss -tlnp | grep 8080 || echo "8080 cerrado"
sudo nginx -T | grep -c 8080        # 0
IP=$(hostname -I | awk '{print $1}')
curl -s http://$IP/ | grep Tienda
curl -s http://$IP/health
```

## Lecciones

- Cerrar un puerto = quitar **todas** sus declaraciones, no sólo el fichero obvio.
- `nginx -T` muestra la config que de verdad carga nginx; `grep` en un solo fichero engaña.
- Comprueba siempre el servicio que debe seguir vivo (puerto 80) **desde la red**,
  no sólo desde `localhost`.
- Un firewall delante es defensa en profundidad, pero lo correcto es que el
  servicio ni siquiera escuche.
