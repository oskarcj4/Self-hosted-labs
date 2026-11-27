# Resolución guiada · Lab 85

:::piensa ¿Dónde está el corte?
Hay dos copias de la app y un nginx delante que reparte entre ellas. Los
clientes sólo hablan con nginx. Si reinicias **una** copia, nginx manda el
tráfico a la otra y nadie se entera. Si reinicias **nginx**, todos los
clientes pierden la conexión a la vez. Por eso el parche se aplica a los
backends de uno en uno, y a nginx no se le toca.
:::

**El plan:** (1) ver el estado y apuntar el PID de nginx, (2) parchear
`shop-a` y comprobarlo, (3) parchear `shop-b` y (4) verificar a través del
balanceador.

## Paso 1 · ¿Qué hay ahora?

**Objetivo:** saber qué versión sirve cada backend y tener una referencia del
PID de nginx para demostrar después que no se reinició.

:::pista Cómo hacerlo
```bash
curl -s http://127.0.0.1:8081/version
curl -s http://127.0.0.1:8082/version
curl -s http://127.0.0.1/version
systemctl show -p MainPID --value nginx
```
- Los dos primeros `curl` van **directos** a cada backend; el tercero, a
  través de nginx (puerto 80), como un cliente.
- `systemctl show -p MainPID --value nginx` imprime sólo el PID del proceso
  maestro de nginx. `-p` elige la propiedad y `--value` quita el
  `MainPID=` de delante.

**Qué deberías ver:** `1.0.0 app-a`, `1.0.0 app-b`, y un PID. Un `reload`
mantiene ese PID (el maestro relee la config y sustituye a sus *workers*); un
`restart` mata el proceso y arranca otro con un PID nuevo.

Mira también cómo reparte nginx:
```bash
cat /etc/nginx/sites-available/shop
```
El bloque `upstream shop` lista los dos backends. Si uno no responde, nginx
reintenta la petición con el otro (`proxy_next_upstream`, activo por defecto
para errores de conexión).
:::

## Paso 2 · Parchea `shop-a` y compruébalo

**Objetivo:** pasar un backend a 1.2.0 mientras el otro sigue atendiendo.

**Pregúntate:** ¿qué tienes que copiar y adónde? ¿Qué hay que reiniciar para
que el proceso cargue el código nuevo?

:::pista Cómo hacerlo
```bash
ls /opt/shop/releases/1.2.0 /srv/app-a
sudo cp -a /opt/shop/releases/1.2.0/. /srv/app-a/
sudo systemctl restart shop-a
curl -s http://127.0.0.1:8081/version
```
- `cp -a` copia conservando permisos, dueños y fechas (`-a` = *archive*).
- El `/.` al final del origen significa "el **contenido** de la carpeta". Sin
  él, `cp` crearía `/srv/app-a/1.2.0/` dentro, en vez de sobrescribir los
  ficheros.
- Python lee el código al arrancar: hasta que no reinicias `shop-a`, sigue
  sirviendo 1.0.0 aunque los ficheros ya sean nuevos.

**Qué deberías ver:** `1.2.0 app-a`. Ahora pregunta varias veces al
balanceador:
```bash
for i in 1 2 3 4; do curl -s http://127.0.0.1/version; done
```
Saldrán mezcladas `1.2.0 app-a` y `1.0.0 app-b`. Es normal a mitad de un
rolling: lo que importa es que todas responden.
:::

## Paso 3 · Parchea `shop-b`

**Objetivo:** completar el parche. Dejar un backend en 1.0.0 "para no tocar"
deja la vulnerabilidad viva en la mitad del tráfico.

:::pista Cómo hacerlo
```bash
sudo cp -a /opt/shop/releases/1.2.0/. /srv/app-b/
sudo systemctl restart shop-b
curl -s http://127.0.0.1:8082/version
```
No hace falta tocar nginx: su configuración apunta a `:8081` y `:8082`, y
eso no ha cambiado. Sólo ha cambiado el programa que escucha detrás.
:::

:::ojo No hagas `systemctl restart nginx`
Corta todas las conexiones abiertas y cambia el PID maestro: el validador lo
detecta. Si algún día tienes que cambiar la configuración de nginx, usa
`sudo nginx -t && sudo systemctl reload nginx`.
:::

## Paso 4 · Verifica a través del balanceador

```bash
for i in 1 2 3 4; do curl -s http://127.0.0.1/version; done
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1/vuln
systemctl show -p MainPID --value nginx
bash /opt/lab/check.sh
```
`-o /dev/null -w '%{http_code}\n'` tira el cuerpo e imprime sólo el código
HTTP. **Qué deberías ver:** sólo `1.2.0`, un `404` en `/vuln` y el mismo PID
que en el paso 1.

## Cómo actuar en una situación así

- **Rolling:** con N instancias, parchea una, comprueba su salud y sigue.
  El balanceador mantiene el servicio en pie todo el tiempo.
- En un caso real, saca la instancia del balanceador **antes** de reiniciarla
  (drain) para no cortar las peticiones que estaba atendiendo. El lab 219 lo
  hace con HAProxy y Ansible.
- Reiniciar el proxy es un corte. `reload` o no tocarlo.

## Si te atascas

- **`/srv/app-a/1.2.0/` aparece como carpeta nueva:** te faltó el `/.` al
  final del origen en el `cp`. Bórrala y repite.
- **El backend sigue diciendo 1.0.0:** copiaste pero no reiniciaste ese
  servicio (`shop-a` o `shop-b`).
- **El check dice que nginx se reinició:** ya no tiene arreglo en esta
  partida (el PID cambió). Reinicia el lab y hazlo sin tocar nginx.
