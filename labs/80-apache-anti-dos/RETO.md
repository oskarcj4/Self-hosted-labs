# Lab 80 — Endurece Apache contra un flood HTTP

## Escenario (hardening)

`web-80` sirve con Apache, pero con la config **de fábrica aflojada**: sin
límite de tiempo de lectura, sin límite de peticiones por IP y con `Timeout`
enorme. Un flood lo tumba en segundos. Endurécelo.

Puedes **simular el flood tú mismo** (es tu lab, es inofensivo): genera muchas
peticiones con ApacheBench contra localhost y observa cómo responde antes y
después de tu configuración.

```bash
ab -n 2000 -c 200 http://127.0.0.1/      # 2000 peticiones, 200 concurrentes
```

## Objetivos

1. **Habilita `mod_reqtimeout`** y pon un `RequestReadTimeout` (corta a quien
   abre conexión y no termina de enviar la petición).
2. **Baja `Timeout`** a 30 o menos.
3. **Baja `KeepAliveTimeout`** a 15 o menos (no regales conexiones ociosas).
4. **Habilita `mod_evasive`** y configúralo (`DOSPageCount`, `DOSSiteCount`,
   `DOSBlockingPeriod`) para banear temporalmente a quien martillea.
5. Deja la **config válida** (`apache2ctl -t` → *Syntax OK*) y Apache sirviendo.

## Comandos que te pueden servir

```bash
sudo a2enmod reqtimeout evasive
sudoedit /etc/apache2/apache2.conf                  # Timeout / KeepAliveTimeout
sudoedit /etc/apache2/mods-enabled/reqtimeout.conf  # RequestReadTimeout
sudoedit /etc/apache2/mods-enabled/evasive.conf     # DOS*  (créalo si no existe)
sudo apache2ctl -t            # valida la sintaxis
sudo apache2ctl -M            # módulos cargados
sudo service apache2 restart  # aplica los cambios
```

Ejemplo de `RequestReadTimeout` (cabeceras y cuerpo con ritmo mínimo):

```apache
RequestReadTimeout header=20-40,MinRate=500 body=20,MinRate=500
```

Ejemplo de `mod_evasive`:

```apache
<IfModule mod_evasive20.c>
    DOSHashTableSize    3097
    DOSPageCount        5
    DOSSiteCount        100
    DOSPageInterval     1
    DOSSiteInterval     1
    DOSBlockingPeriod   60
</IfModule>
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
