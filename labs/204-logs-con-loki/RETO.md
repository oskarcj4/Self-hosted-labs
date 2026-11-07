# Logs con Loki

> Loki · Promtail · etiquetas y cardinalidad · `replace` · `multiline` · LogQL

## Escenario

La tienda acaba de montar Loki (`:3100`) con Promtail para centralizar los
logs. Lleva un día en marcha y ya hay quejas:

- De **pagos** (`/var/log/tienda/pagos.log`, una línea JSON por evento) no ha llegado nada.
- El **catálogo** crea un stream nuevo por cada IP de cliente. Loki indexa por etiquetas, así que cada valor distinto es un stream más y el índice crece sin control.
- Las trazas de error de Python del catálogo llegan **troceadas**: una entrada por línea, imposible de leer o de contar.

Para colmo, los mensajes de pagos llevan números de tarjeta completos. En
cuanto lo arregles, esos números acabarían en Loki.

## Objetivos

1. Que pagos llegue a Loki, con las tarjetas enmascaradas (`tarjeta=****1111`) **antes** de salir de la máquina.
2. Usar sólo etiquetas de baja cardinalidad (`app`, `nivel`). El pedido, el usuario y la IP se quedan en la línea.
3. Que cada error del catálogo llegue con su traza en una sola entrada.
4. Dos consultas LogQL en `~/consultas/`: los pagos lentos y los errores por app.

Los detalles están en `~/TAREA.txt`.

## Pistas

```bash
sudo nano /etc/promtail/config.yml && sudo systemctl restart promtail
journalctl -u promtail -n 20
logcli series '{}' --since=1m --analyze-labels
logcli query '{app="pagos"} | json' --since=1m --limit=5
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
