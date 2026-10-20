# Solución — Día 12: Sacar un secreto del entorno del proceso

## 1. Ver la fuga

```bash
systemctl show ingest -p Environment     # INGEST_API_TOKEN=ing_live_... (como analista)
sudo cat /proc/$(systemctl show ingest -p MainPID --value)/environ | tr '\0' '\n' | grep TOKEN
```

## 2. ¿Qué otras vías soporta la app?

```bash
sed -n 1,30p /opt/ingest/ingest.py
# 1. $CREDENTIALS_DIRECTORY/ingest_token  (LoadCredential= de systemd)
# 2. el fichero indicado en INGEST_TOKEN_FILE
# 3. INGEST_API_TOKEN (obsoleta)
```

## 3. Fichero con el token, legible sólo por el servicio

```bash
sudo install -d -m 0750 -o root -g ingest /etc/ingest
sudo install -m 0640 -o root -g ingest /dev/null /etc/ingest/api_token
echo 'ing_live_4f7a9c2e8b1d6f3a5c0e' | sudo tee /etc/ingest/api_token >/dev/null
```

`root:ingest 0640`: root lo administra, el grupo del servicio lo lee, nadie más.

## 4. Pasar la **ruta** en vez del secreto

El token está en la unidad original: hay que quitarlo de ahí (un drop-in con
`Environment=` vacío lo anularía, pero el texto seguiría visible en `systemctl cat`).

```bash
sudo sed -i 's#^Environment=INGEST_API_TOKEN=.*#Environment=INGEST_TOKEN_FILE=/etc/ingest/api_token#' \
  /etc/systemd/system/ingest.service
sudo systemctl daemon-reload
sudo systemctl restart ingest
```

## 5. Verificar

```bash
curl -s http://127.0.0.1:8700/            # ingest ok: token valido (origen: file)
systemctl show ingest -p Environment      # INGEST_TOKEN_FILE=... INGEST_BATCH=500
sudo cat /proc/$(systemctl show ingest -p MainPID --value)/environ | tr '\0' '\n' | grep -c ing_live   # 0
cat /etc/ingest/api_token                 # Permission denied (como analista)
```

## En un servidor real: `LoadCredential=`

Con systemd ≥ 247 en un host normal, lo más limpio es:

```ini
[Service]
LoadCredential=ingest_token:/etc/ingest/api_token
```

systemd (root) lee el fichero (que puede quedarse en `0600 root`) y lo expone
en `$CREDENTIALS_DIRECTORY/ingest_token`, una ruta privada sólo para ese
servicio. En este laboratorio systemd corre dentro de un contenedor y no puede
montar ese directorio privado, por eso usamos la variante con fichero.

## Lecciones

- Las variables de entorno **no son un almacén de secretos**: se heredan,
  se listan (`systemctl show`) y se vuelcan en logs y trazas.
- Pasa al proceso la **ruta** al secreto, no el secreto.
- Si el token estuvo visible, en un caso real: **rotarlo**.
