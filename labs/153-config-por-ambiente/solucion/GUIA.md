# Resolución guiada · Lab 153

:::piensa La configuración no es código
La misma app debe correr en desarrollo y en producción. Si un valor que cambia
entre ambientes está escrito en el código, ya no es la misma app: para cambiar
de ambiente hay que tocar el código. Y si ese valor es un secreto, acaba en el
repositorio, a la vista de cualquiera con acceso. El principio (*12-factor*):
la configuración vive en el **entorno** del proceso.
:::

**El plan:** (1) que la app lea del entorno, (2) poner los valores en un
fichero protegido, (3) que systemd cargue ese fichero y (4) comprobarlo.

## Paso 1 · La app lee del entorno

**Objetivo:** que `app.py` no lleve ningún valor de configuración escrito.

**Pregúntate:** ¿cómo lee un programa en Python una variable de entorno? ¿Qué
debería pasar si no existe?

:::pista Cómo hacerlo
`/opt/allsafe/app.py` es tuyo (no necesitas `sudo`). Cambia la primera línea y
el bloque de configuración:
```python
import json, os
```
```python
APP_ENV    = os.environ.get("APP_ENV", "dev")
LOG_LEVEL  = os.environ.get("LOG_LEVEL", "INFO")
DB_HOST    = os.environ.get("DB_HOST", "localhost")
SECRET_KEY = os.environ.get("SECRET_KEY", "")
```
- `os.environ` es un diccionario con las variables de entorno del proceso.
  `.get("NOMBRE", valor)` devuelve la variable o, si no existe, ese valor por
  defecto.
- Los valores por defecto son **seguros**: `dev` y no `prod`, y el secreto
  vacío. Si alguien arranca la app sin configurar, no se conecta por error a
  producción, y `secret_set` dirá `false`.
:::

## Paso 2 · Los valores, en un fichero protegido

**Objetivo:** un fichero con la configuración de producción que sólo pueda leer
root.

:::pista Cómo hacerlo
```bash
sudo tee /etc/allsafe/app.env >/dev/null <<'EOF'
APP_ENV=prod
LOG_LEVEL=INFO
DB_HOST=db-prod.allsafe.local
SECRET_KEY=s3cr3t-allsafe-prod-KEY
EOF
sudo chmod 600 /etc/allsafe/app.env
```
El formato es `NOMBRE=valor`, una por línea, sin espacios alrededor del `=`.
`chmod 600`: sólo root lo lee. No pasa nada porque la app no corra como root:
systemd lee el fichero **antes** de lanzar el proceso y le pasa las variables.
:::

## Paso 3 · Que systemd lo cargue

**Objetivo:** que el servicio arranque con esas variables.

:::pista Cómo hacerlo
```bash
sudo systemctl edit --full allsafe-api
```
`edit --full` abre el fichero de la unidad entero en el editor. Añade en
`[Service]`, encima de `ExecStart`:
```ini
EnvironmentFile=/etc/allsafe/app.env
```
`EnvironmentFile=` le dice a systemd que lea ese fichero y ponga cada línea
como variable de entorno del proceso.

Usa `--full`. Sin él, `systemctl edit` crea un fichero aparte
(`/etc/systemd/system/allsafe-api.service.d/override.conf`) que se suma a la
unidad. Funciona igual, pero el validador busca la línea en la unidad
principal.

`edit` ya hace el `daemon-reload` al guardar. Reinicia para que el proceso
nuevo arranque con las variables:
```bash
sudo systemctl restart allsafe-api
```
:::

## Paso 4 · Comprueba

```bash
curl -s localhost:8080/
sudo cat /proc/$(systemctl show -p MainPID --value allsafe-api)/environ | tr '\0' '\n' | grep APP_ENV
grep -n s3cr3t /opt/allsafe/app.py || echo "sin secreto en el código"
bash /opt/lab/check.sh
```
- `/proc/<PID>/environ` es el entorno con el que arrancó ese proceso. Las
  variables van separadas por un carácter nulo; `tr '\0' '\n'` las pone una
  por línea.

**Qué deberías ver:** `{"env": "prod", …, "secret_set": true}`, `APP_ENV=prod`
en el entorno del proceso y `sin secreto en el código`.

Para comprobar la idea de fondo: cambia `APP_ENV=dev` en el fichero, reinicia
y verás `"env": "dev"` sin haber tocado el código. Déjalo luego en `prod`.

## Cómo actuar en una situación así

- Cualquier valor que cambie entre ambientes es una variable, nunca una
  constante.
- Un fichero `600` es el mínimo para un secreto. En producción, un gestor de
  secretos (Vault, lab 173) que lo inyecte al arrancar.
- Nunca escribas el secreto en los logs: un `secret_set: true` basta para
  diagnosticar.
- Si el secreto estuvo en el repositorio, sigue en su historial: **rótalo**.

## Si te atascas

- **`env` sigue diciendo el valor viejo:** no reiniciaste el servicio. Las
  variables se leen al arrancar.
- **`secret_set: false`:** el proceso no ve `SECRET_KEY`. Revisa con
  `systemctl cat allsafe-api` que la línea `EnvironmentFile=` esté en
  `[Service]` y que la ruta sea exacta.
- **El check dice que falta `EnvironmentFile`:** lo pusiste en un
  `override.conf` (editaste sin `--full`). Muévelo a la unidad principal.
