# Incidente completo: de la alerta al postmortem

> SRE · guardia · disco lleno · logrotate · comunicación · postmortem sin culpables

## Escenario

Estás de guardia. Salta la alerta (`~/incidente/alerta.txt`): la tienda
devuelve **5xx** y los clientes no ven sus pedidos.

Este lab junta todo el ciclo de un incidente:

1. **Restaurar** el servicio: primero que funcione.
2. **Quitar la causa**, no sólo el síntoma.
3. **Prevenir** que se repita.
4. **Comunicar** mientras pasa: actualizaciones con hora.
5. **Aprender**: un postmortem **sin culpables**. Habla de qué permitió el
   fallo en el sistema, no de quién hizo el cambio.

Cuidado con un clásico: borrar (`rm`) un log que un proceso tiene abierto **no
libera el espacio** mientras el proceso siga vivo.

## Objetivos

1. `curl localhost:8080/pedidos` devuelve 200 y el volumen de logs tiene espacio.
2. La app ya no registra en DEBUG.
3. `/etc/logrotate.d/pedidos`: rota por tamaño (`size`), comprime, guarda un
   número limitado de copias (`rotate N`) y la app sigue escribiendo en
   `app.log` tras rotar (`copytruncate` o `postrotate`).
4. `~/incidente/comunicado.txt`: al menos dos actualizaciones `HH:MM ...`, la
   última de resolución.
5. `~/incidente/postmortem.md` (plantilla en `~/incidente`): todas las
   secciones, línea de tiempo con las **horas reales** (despliegue, primer
   error, alerta, arreglo), al menos dos acciones con responsable y fecha, y
   sin nombres de personas.

## Pistas

```bash
curl -i localhost:8080/pedidos
df -h; sudo du -sh /var/log/*
sudo journalctl -u pedidos -o short-iso | grep -m1 'No space'
cat /var/log/despliegues.log
sudo lsof +L1                       # ficheros borrados pero aún abiertos
sudo truncate -s 0 FICHERO          # vacía sin cambiar el inodo
sudo logrotate -d /etc/logrotate.d/pedidos
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
