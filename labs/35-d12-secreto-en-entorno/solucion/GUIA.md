# Resolución guiada · Día 12

:::piensa Antes de tocar nada
Las variables de entorno parecen privadas, pero no lo son: se listan con `systemctl show`, se ven en `/proc/<pid>/environ`, las heredan todos los procesos hijos y acaban en volcados de error. El patrón correcto es pasar al proceso **la ruta** del secreto, no el secreto.
:::

## Paso 1 · Mide la fuga

**Pregúntate:** ¿por cuántas vías puede leerse hoy el token? Pruébalas como usuario normal.

:::pista Cómo comprobarlo
```bash
systemctl cat ingest
systemctl show ingest -p Environment
sudo cat /proc/$(systemctl show ingest -p MainPID --value)/environ | tr '\0' '\n'
```
:::

## Paso 2 · ¿Qué alternativas soporta la app?

**Pregúntate:** antes de diseñar, lee el código. ¿De dónde sabe leer el token?

:::pista Cómo comprobarlo
```bash
sed -n 1,30p /opt/ingest/ingest.py
```
Verás una variable que acepta una **ruta** a un fichero. Ésa es tu vía (el enunciado avisa de que `LoadCredential=` no funciona en este contenedor).
:::

## Paso 3 · Fichero legible sólo por el servicio

**Pregúntate:** aquí, a diferencia del día 09, el que abre el fichero **es el servicio** (no systemd). ¿Qué permisos necesita entonces? Lectura para su grupo.

:::pista Cómo hacerlo
```bash
sudo install -d -m 0750 -o root -g ingest /etc/ingest
sudo install -m 0640 -o root -g ingest /dev/null /etc/ingest/api_token
echo '<token>' | sudo tee /etc/ingest/api_token >/dev/null
```
:::

## Paso 4 · Quita el secreto de la unidad

**Pregúntate:** ¿basta con un drop-in que vacíe la variable? No: el texto original seguiría visible en `systemctl cat`. Hay que editar la línea de la unidad.

:::pista Cómo hacerlo
Cambia `Environment=INGEST_API_TOKEN=...` por `Environment=INGEST_TOKEN_FILE=/etc/ingest/api_token` en `/etc/systemd/system/ingest.service`, y:
```bash
sudo systemctl daemon-reload
sudo systemctl restart ingest
```
:::

## Paso 5 · Verifica cada vía de fuga

```bash
curl -s http://127.0.0.1:8700/
systemctl show ingest -p Environment
sudo cat /proc/$(systemctl show ingest -p MainPID --value)/environ | tr '\0' '\n' | grep -c '<prefijo-del-token>'
cat /etc/ingest/api_token          # como analista: denegado
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Lee el código** para saber qué mecanismos soporta la app antes de inventar.
- **Pregunta quién abre el fichero**: si es systemd, `0600 root`; si es el servicio, lectura para su grupo.
- En un host normal, lo más limpio es `LoadCredential=`.
- Si estuvo visible: **rotar** el token.

## Si te atascas

- La app dice "token no válido": comprueba que el fichero no tiene espacios o líneas extra (`cat -A`).
- `systemctl show` sigue mostrando el token: falta `daemon-reload`.
