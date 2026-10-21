# Resolución guiada · Día 02

:::piensa Antes de tocar nada
"Quito el puerto y sigue escuchando" significa una cosa: **está declarado en más de un sitio**. nginx junta muchos ficheros (includes) en una sola configuración. Si buscas en un fichero, ves una parte. Si preguntas a nginx qué ha cargado, lo ves todo.
:::

## Paso 1 · ¿Quién escucha en el 8080?

:::pista Cómo comprobarlo
```bash
sudo ss -tlnp | grep -E ':(80|8080)\b'
```
:::

## Paso 2 · ¿Dónde se declara?

**Pregúntate:** ¿cómo veo la configuración **completa** que nginx usa, con todos los includes y el nombre de cada fichero?

**Por qué importa:** `nginx -T` es la única fuente fiable. Cada bloque va precedido de `# configuration file <ruta>`.

:::pista Cómo comprobarlo
```bash
sudo nginx -T | grep -nE '^# configuration file|listen'
```
Cuenta cuántos `listen 8080` hay y en qué fichero está cada uno. ¿Es un sitio entero sobrante, o una línea dentro de un sitio bueno, o los dos?
:::

## Paso 3 · Retira cada declaración

**Pregúntate:** para un sitio sobrante, ¿borro el fichero o lo desactivo? En Debian, `sites-enabled/` contiene enlaces a `sites-available/`: quitar el enlace lo desactiva sin perder el fichero.

**Pregúntate también:** para una línea dentro del sitio bueno, ¿edito el enlace o el fichero real? El real, en `sites-available/`.

:::pista Cómo hacerlo
```bash
ls -la /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/<sitio-sobrante>
sudo sed -i '/listen 8080;/d' /etc/nginx/sites-available/<sitio-bueno>
```
:::

## Paso 4 · Valida, recarga y prueba desde la red

**Pregúntate:** ¿probar con `localhost` demuestra que la tienda funciona para los clientes? No: pruébalo contra la IP de la máquina.

:::pista Cómo comprobarlo
```bash
sudo nginx -t && sudo systemctl reload nginx
sudo ss -tlnp | grep 8080 || echo "8080 cerrado"
IP=$(hostname -I | awk '{print $1}')
curl -s -o /dev/null -w '%{http_code}\n' http://$IP/
curl -s http://$IP/health
bash /opt/lab/check.sh
```
:::

## Cómo actuar en una situación así

- **`nginx -T` antes de editar**: localiza todas las declaraciones.
- **`nginx -t` antes de recargar**: una config rota tumba la web.
- **Comprueba lo que debe seguir vivo** (no sólo que lo malo se fue), y desde la red.
- Lo correcto es que el servicio no escuche; un firewall delante es defensa en profundidad, no la solución.

## Si te atascas

- El 8080 sigue: vuelve a `nginx -T | grep 8080`; queda alguna declaración.
- `nginx -t` falla tras editar: has dejado una llave `{}` descompensada.
