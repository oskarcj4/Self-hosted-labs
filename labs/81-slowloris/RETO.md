# Lab 81 — Mitiga un Slowloris (slow-DoS de cabeceras)

## Escenario (hardening / respuesta)

No todos los DoS son un diluvio de peticiones. **Slowloris** hace lo contrario:
abre pocas conexiones y envía las cabeceras HTTP **gota a gota**, sin
terminarlas nunca. Cada conexión ocupa un worker de Apache esperando. Con unas
cientos de conexiones lentas, el servidor se queda sin workers y deja de atender
a los clientes reales —con muy poco ancho de banda del atacante.

`web-81` tiene `mod_reqtimeout` **deshabilitado**: es vulnerable. Pruébalo tú
mismo (es tu lab) y luego mitígalo.

```bash
# En una terminal: lanza el probador (acotado a localhost, didáctico)
python3 /opt/lab/slowtest.py
# En otra: intenta cargar la web mientras tanto
curl -m 5 http://127.0.0.1/
```

## Objetivos

1. **Habilita `mod_reqtimeout`** y configura `RequestReadTimeout` con un límite
   de **cabeceras** (`header=`), de modo que Apache corte a quien no termina de
   enviarlas a tiempo.
2. Deja la **config válida** (`apache2ctl -t`) y Apache sirviendo en el 80.
3. Reejecuta el probador: las conexiones lentas deben **caer a 0** enseguida y
   `curl` seguir respondiendo.

## Comandos que te pueden servir

```bash
sudo a2enmod reqtimeout
sudoedit /etc/apache2/mods-enabled/reqtimeout.conf
sudo apache2ctl -t
sudo service apache2 restart
python3 /opt/lab/slowtest.py 150 30
```

`RequestReadTimeout` recomendado:

```apache
RequestReadTimeout header=20-40,MinRate=500 body=20,MinRate=500
```

- `header=20-40`: concede entre 20 y 40 s para las cabeceras…
- `MinRate=500`: …y exige al menos 500 B/s; el que va más lento, fuera.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
