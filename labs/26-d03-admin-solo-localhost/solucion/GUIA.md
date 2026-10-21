# Resolución guiada · Día 03

:::piensa Antes de tocar nada
Un servicio puede ser accesible desde la red por **dos caminos**: porque él mismo escucha en una interfaz de red, o porque **otro servicio** en la misma máquina (un proxy) le reenvía tráfico. Cerrar uno y olvidar el otro es el error típico de este reto.
:::

## Paso 1 · ¿Dónde escucha y quién lo configura?

**Pregúntate:** ¿el `0.0.0.0` viene del código, de la unidad systemd o de un fichero de configuración?

**Por qué importa:** quieres cambiar la **configuración**, para que el arreglo sobreviva a un reinicio.

:::pista Cómo comprobarlo
```bash
sudo ss -tlnp | grep 9090
systemctl cat ops-admin
cat /etc/ops-admin/admin.conf
```
:::

## Paso 2 · Primera puerta: el bind

:::pista Cómo hacerlo
```bash
sudo sed -i 's/^BIND_ADDR=.*/BIND_ADDR=127.0.0.1/' /etc/ops-admin/admin.conf
sudo systemctl restart ops-admin
sudo ss -tlnp | grep 9090
```
Ahora debería decir `127.0.0.1:9090`.
:::

## Paso 3 · ¿Sigue siendo accesible desde la red?

**Pregúntate:** ¿cómo lo pruebo de verdad? Desde la **IP de red**, no desde `localhost`. Y prueba todas las vías: el puerto directo y la web pública.

**Por qué importa:** nginx corre en la misma máquina, así que sí puede llegar a `127.0.0.1:9090`. Si tiene un `proxy_pass` hacia ahí, re-publica el panel.

:::pista Cómo comprobarlo
```bash
IP=$(hostname -I | awk '{print $1}')
curl -s --max-time 2 http://$IP:9090/ || echo "directo: cerrado"
curl -s http://$IP/admin/ | head -3
sudo nginx -T | grep -n -B2 -A4 'proxy_pass'
```
:::

## Paso 4 · Segunda puerta: el proxy

:::pista Cómo hacerlo
Quita el bloque `location` que reenvía al panel en el fichero de sitio de nginx (usa `nginx -T` para saber cuál es), y después:
```bash
sudo nginx -t && sudo systemctl reload nginx
curl -s http://$IP/admin/ | head -3
```
:::

## Paso 5 · Lo que debe seguir funcionando

```bash
curl -s http://127.0.0.1:9090/ | head -3    # el panel, en local
curl -s -o /dev/null -w '%{http_code}\n' http://$IP/   # el portal público
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Enumera todos los caminos** hacia un servicio: bind directo, proxies, túneles, port-forwards.
- **Prueba siempre desde la red**; `localhost` no demuestra nada sobre exposición.
- Para administración remota: túnel SSH (`ssh -L 9090:127.0.0.1:9090 usuario@host`), no publicar.

## Si te atascas

- `restart` falla: `journalctl -u ops-admin -n 20`.
- `/admin/` sigue mostrando el panel: queda el `location` en nginx o no recargaste.
