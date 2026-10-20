# Día 10 — Frontera de escritura de logs

> 30 días de DevSecOps · Linux · Permisos e identidad de servicios

## Escenario

`paymentsd` (usuario `payments`) registra cada transacción en
`/var/log/payments/transactions.log`: importes, tarjetas enmascaradas y
**tokens de pago**. Para "evitar problemas de permisos" la carpeta es `0777`
y el log `0666`: cualquiera puede leerlo… o falsificar entradas.

Y hay una trampa más: aunque arregles el fichero hoy, **logrotate** lo
recreará mañana con los permisos de su configuración.

## Objetivos

1. La carpeta `/var/log/payments` y **todos** sus logs (también los ya
   rotados, `*.log.1`) sin ningún permiso para "otros".
2. Un usuario normal (`analista`) no debe poder leerlos.
3. `paymentsd` debe poder seguir escribiendo (sigue corriendo como `payments`).
4. La configuración de **logrotate** debe crear los logs nuevos con permisos
   cerrados y con el dueño correcto; una rotación forzada debe funcionar.

## Comandos que te pueden servir

```bash
ls -la /var/log/payments/
systemctl show paymentsd -p User -p Group
cat /etc/logrotate.d/payments
sudo logrotate -d /etc/logrotate.d/payments      # simulación: muestra qué haría y errores
sudo logrotate -f /etc/logrotate.d/payments      # rotación real
curl -s http://127.0.0.1:8600/                   # salud del servicio
```

> El validador **fuerza una rotación** para comprobar que tu arreglo la sobrevive.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
