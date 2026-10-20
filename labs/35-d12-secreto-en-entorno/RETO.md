# Día 12 — Sacar un secreto del entorno del proceso

> 30 días de DevSecOps · Linux · Secretos y limpieza de políticas

## Escenario

`ingest` reenvía datos a la API de analítica con un token que va en la
unidad systemd como `Environment=INGEST_API_TOKEN=...`. Parece inofensivo,
pero ese token se puede leer:

- con `systemctl show ingest -p Environment` o `systemctl cat ingest` (**cualquier usuario**),
- en `/proc/<pid>/environ` del proceso (y lo heredan todos sus hijos),
- en volcados de error, `ps e`, informes de fallos…

La aplicación ya soporta otras formas de recibir el token (lee su código en
`/opt/ingest/ingest.py`).

## Objetivos

1. El token no debe aparecer en `Environment=` de la unidad ni de ningún drop-in.
2. El proceso en ejecución no debe llevarlo en su entorno.
3. `ingest` debe cargarlo desde un **fichero** o una **credencial de systemd**
   y seguir funcionando: `curl http://127.0.0.1:8700/` → `token valido`.
4. Ningún fichero con el token puede ser legible por un usuario normal.
5. `ingest` sigue corriendo como `ingest`.

## Comandos que te pueden servir

```bash
systemctl cat ingest
systemctl show ingest -p Environment
sudo cat /proc/$(systemctl show ingest -p MainPID --value)/environ | tr '\0' '\n'
sed -n 1,30p /opt/ingest/ingest.py          # ¿de dónde puede leer el token?
sudo nano /etc/systemd/system/ingest.service
sudo systemctl daemon-reload && sudo systemctl restart ingest
```

> En este laboratorio systemd corre dentro de un contenedor y `LoadCredential=`
> no está disponible: usa la variante con fichero que soporta la app.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
