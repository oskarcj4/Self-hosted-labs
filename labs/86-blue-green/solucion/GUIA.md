# Resolución guiada · Lab 86

:::piensa Cambiar el tráfico, no el código
En un despliegue *blue-green* hay dos copias completas de la aplicación
corriendo a la vez: la vieja (green, aquí 1.0.0 y vulnerable) y la nueva
(blue, 1.2.0 parcheada). El despliegue no es instalar nada: es **mover el
tráfico** de una a otra en el balanceador, en un instante. Y la vieja no se
apaga: es el plan de vuelta atrás, que también es instantáneo.
:::

**El plan:** (1) comprobar que blue está sana, (2) apuntar el balanceador a
blue, (3) recargar sin cortar y (4) verificar.

## Paso 1 · ¿Blue está lista?

**Objetivo:** no mandar tráfico a algo que no funciona.

:::pista Cómo hacerlo
```bash
curl -s http://127.0.0.1:8082/health
curl -s http://127.0.0.1:8082/version
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8082/vuln
curl -s http://127.0.0.1/version
systemctl show -p MainPID --value nginx
```
Las tres primeras van **directas** a blue (puerto 8082), sin pasar por nginx;
la cuarta, a través del balanceador, como un cliente. La última da el PID del
proceso maestro de nginx, para comprobar al final que no se reinició.

**Qué deberías ver:** blue sana, en `1.2.0`, con `/vuln` cerrado (no 200), y el
balanceador sirviendo todavía `1.0.0 green`.
:::

## Paso 2 · Apunta el balanceador a blue

:::pista Cómo hacerlo
```bash
sudo nano /etc/nginx/sites-available/shop
```
El bloque `upstream shop` es la lista de backends entre los que nginx reparte.
Déjalo con **sólo** blue:
```nginx
upstream shop {
    server 127.0.0.1:8082;   # blue
}
```
Quita la línea de `:8081`. Si dejaras las dos, nginx repartiría entre ambas y
la mitad del tráfico seguiría yendo a la versión vulnerable.
:::

## Paso 3 · Recarga sin cortar

:::pista Cómo hacerlo
```bash
sudo nginx -t && sudo systemctl reload nginx
```
- `nginx -t` comprueba la configuración sin aplicarla; el `&&` hace que sólo se
  recargue si es válida.
- `reload` hace que el proceso maestro relea la configuración y sustituya a sus
  *workers* poco a poco: las conexiones abiertas terminan con la configuración
  vieja y las nuevas van a blue. El maestro (y su PID) sigue siendo el mismo.
  `restart` mataría el proceso y cortaría a todos los clientes.
:::

:::ojo No apagues green
`systemctl stop shop-green` hace fallar el lab, y en la vida real te dejaría
sin plan B. Si blue falla en producción, la vuelta atrás es repetir el paso 2
con `:8081` y recargar: segundos.
:::

## Paso 4 · Verifica

```bash
for i in 1 2 3 4; do curl -s http://127.0.0.1/version; done
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1/vuln
curl -s http://127.0.0.1:8081/version
systemctl show -p MainPID --value nginx
bash /opt/lab/check.sh
```
**Qué deberías ver:** sólo `1.2.0 blue` a través del balanceador, `/vuln` ya
no da 200, green sigue respondiendo en `:8081` y el mismo PID que en el paso 1.

## Cómo actuar en una situación así

- Blue-green hace el despliegue y la vuelta atrás instantáneos, a cambio de
  tener el doble de recursos durante la transición.
- Comprueba la nueva versión **antes** de mandarle tráfico, no después.
- Con bases de datos de por medio, las dos versiones tienen que funcionar con
  el mismo esquema (lab 157).

## Si te atascas

- **Sigue saliendo green a veces:** quedan las dos líneas en el `upstream`.
- **El check dice que nginx se reinició:** usaste `restart`. El PID ya cambió;
  reinicia el lab y usa `reload`.
- **`nginx -t` falla:** cada `server` del `upstream` termina en `;`.
