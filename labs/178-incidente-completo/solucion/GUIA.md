# Resolución guiada · Lab 178

:::piensa El orden importa
Primero mitigar (que los clientes vuelvan a ver sus pedidos), luego la causa,
luego prevenir. Y comunicar desde el primer minuto: "investigando" ya es útil.
:::

## Paso 1 · Comunicar y diagnosticar

:::pista Qué mirar
Escribe la primera línea de `comunicado.txt` con la hora. Después:
`curl -i` (502: nginx no obtiene respuesta de la app), `df -h` (un volumen al
100 %) y `journalctl -u pedidos` (`No space left on device`).
:::

## Paso 2 · Liberar espacio sin romper nada

:::pista Cómo hacerlo
```bash
sudo truncate -s 0 /var/log/pedidos/app.log     # la app lo tiene abierto
sudo gzip /var/log/pedidos/app.log.{1,2,3}      # logs viejos sin comprimir
```
Si ya hiciste `rm app.log`, el espacio sigue ocupado: `sudo lsof +L1` lo
muestra. Reinicia la app para soltarlo.
:::

## Paso 3 · La causa

:::pista Qué mirar
`cat /var/log/despliegues.log`: el último cambio puso `LOG_LEVEL=DEBUG`.
Cada petición escribe un volcado de 8 KB.
:::

:::pista Cómo hacerlo
Cambia `LOG_LEVEL=DEBUG` por `INFO` en `/etc/systemd/system/pedidos.service`,
`daemon-reload` y `restart`.
:::

## Paso 4 · Prevenir

:::pista Cómo hacerlo
```
/var/log/pedidos/*.log {
    size 5M
    rotate 5
    compress
    missingok
    notifempty
    copytruncate
}
```
`copytruncate` porque la app no reabre el fichero. Sin él, seguiría
escribiendo en el fichero rotado.
:::

## Paso 5 · El postmortem

:::pista Qué escribir
Las horas salen de `despliegues.log`, de la primera línea `No space left` de
`journalctl -o short-iso` y de `alerta.txt`. Sin culpables: "el DEBUG podía
llegar a producción sin límite", no "X activó DEBUG".
:::

## Cómo actuar en una situación así

- Alerta de disco al 80 %: avisa antes de que se caiga el servicio.
- Las acciones del postmortem con responsable y fecha. Si no, no se hacen.
- Postmortem sin culpables: la gente cuenta lo que pasó de verdad y el sistema mejora.
