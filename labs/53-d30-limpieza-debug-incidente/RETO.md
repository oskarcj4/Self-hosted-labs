# Día 30 — Limpiar la depuración tras un incidente

> 30 días de DevSecOps · Docker · Endurecimiento de imágenes

## Escenario

El mes pasado el login del portal (`~/portal`) se rompió (INC-3107). Para
investigar, alguien añadió un `compose.override.yaml` que:

- activa `AUTH_BYPASS=true` en la app: `/admin` sin contraseña,
- lanza un servicio `debug-shell` que ejecuta comandos recibidos por el
  puerto `7000`… con la raíz del host montada en `/host`.

El incidente se cerró. Los cambios "temporales" siguen ahí:

```bash
curl -s localhost:8000/admin
echo id | nc localhost 7000
```

> Recuerda: `docker compose` lee `compose.override.yaml` **automáticamente**
> si está junto a `compose.yaml`.

## Objetivos

1. La configuración efectiva (`docker compose config`) sólo debe tener el
   servicio `app` y sin `AUTH_BYPASS`.
2. No debe quedar ningún contenedor de depuración (tampoco parado) ni el puerto `7000` abierto.
3. Ningún contenedor monta `/` del host.
4. `/admin` vuelve a responder `401` sin credenciales y `200` con la
   `ADMIN_KEY` de `.env`; el portal sigue en `:8000`.

## Comandos que te pueden servir

```bash
cd ~/portal && ls -la && cat compose.yaml compose.override.yaml
docker compose config
docker compose ps -a ; docker ps -a
docker compose up -d --remove-orphans
curl -s -o /dev/null -w '%{http_code}\n' localhost:8000/admin
curl -s -H "X-Admin-Key: $(sed -n 's/^ADMIN_KEY=//p' .env)" localhost:8000/admin
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
