# Resolución guiada · Día 10

:::piensa Antes de tocar nada
Un permiso que arreglas a mano y que otro proceso **recrea** mañana no está arreglado. Antes de `chmod`, pregúntate siempre: **¿quién crea este fichero?** Aquí hay dos respuestas: la app, que escribe, y logrotate, que cada día crea el fichero nuevo con los permisos que tenga en su configuración.
:::

## Paso 1 · Diagnóstico completo

**Pregúntate:** ¿qué permisos tienen la carpeta, el log actual y los rotados? ¿Y qué dice logrotate?

:::pista Cómo comprobarlo
```bash
ls -la /var/log/payments/
systemctl show paymentsd -p User -p Group
cat /etc/logrotate.d/payments
sudo logrotate -d /etc/logrotate.d/payments
```
`-d` es simulación: te dice qué haría y qué errores encuentra. Lee los errores.
:::

## Paso 2 · Define la frontera

| Quién | Necesita |
|---|---|
| `payments` (servicio) | escribir |
| grupo de lectores autorizados | leer |
| resto | nada |

## Paso 3 · Carpeta y logs existentes

**Pregúntate:** ¿incluyo los rotados (`*.log.1`)? Sí: también tienen tokens.

:::pista Cómo hacerlo
```bash
sudo chown payments:payments /var/log/payments /var/log/payments/transactions.log*
sudo chmod 0750 /var/log/payments
sudo chmod 0640 /var/log/payments/transactions.log*
```
:::

## Paso 4 · Arregla quien recrea el fichero

**Pregúntate:** ¿qué línea de logrotate decide los permisos del log nuevo? `create MODO DUEÑO GRUPO`.

:::pista Cómo hacerlo
```bash
sudo sed -i 's/^\(\s*\)create .*/\1create 0640 payments payments/' /etc/logrotate.d/payments
sudo logrotate -d /etc/logrotate.d/payments
sudo logrotate -f /etc/logrotate.d/payments
ls -l /var/log/payments/
```
Fíjate: con la carpeta en `0777`, logrotate se negaba a rotar. Una carpeta escribible por todos permite ataques con enlaces simbólicos durante la rotación.
:::

## Paso 5 · Verifica

```bash
sleep 3; sudo tail -1 /var/log/payments/transactions.log   # el servicio sigue escribiendo
cat /var/log/payments/transactions.log                      # como analista: denegado
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Pregunta quién crea el fichero** (la app, logrotate, systemd con `LogsDirectory=`…) y arregla la configuración de ese actor.
- **Fuerza el evento** que recrea el fichero (`logrotate -f`) para comprobar que tu arreglo sobrevive.
- **Los logs con datos sensibles se protegen como la base de datos.**

## Si te atascas

- `logrotate -d` sigue quejándose: revisa los permisos de la carpeta.
- El servicio deja de escribir: el log nuevo no es de `payments`.
