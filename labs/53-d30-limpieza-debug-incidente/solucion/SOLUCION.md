# Solución — Día 30: Limpiar la depuración tras un incidente

## 1. Qué hay realmente

```bash
cd ~/portal
ls -la                     # compose.yaml, compose.override.yaml, .env
docker compose config      # app con AUTH_BYPASS: "true" + servicio debug-shell
docker compose ps
curl -s localhost:8000/admin                     # 200 sin credenciales
echo 'ls /host/root' | nc localhost 7000         # shell remota con el host montado
```

## 2. Preservar la evidencia (en un caso real)

Antes de borrar: guarda el override y los logs del incidente fuera del servidor.

```bash
mkdir -p ~/evidencia-INC-3107
cp compose.override.yaml ~/evidencia-INC-3107/
docker compose logs debug-shell > ~/evidencia-INC-3107/debug-shell.log
```

## 3. Retirar el override y los huérfanos

```bash
rm compose.override.yaml
docker compose config | grep -E 'AUTH_BYPASS|debug-shell' || echo "limpio"
docker compose up -d --remove-orphans
```

- Al no estar el override, `app` se **recrea** sin `AUTH_BYPASS`.
- `debug-shell` ya no está en la configuración: queda **huérfano** y
  `--remove-orphans` lo elimina. (Un `up -d` sin esa opción lo dejaría corriendo.)

## 4. Verificar

```bash
docker ps -a                                                  # sólo portal-app-1
curl -s -o /dev/null -w '%{http_code}\n' localhost:8000/admin # 401
curl -s -H "X-Admin-Key: $(sed -n 's/^ADMIN_KEY=//p' .env)" localhost:8000/admin   # 200
timeout 2 bash -c 'exec 3<>/dev/tcp/127.0.0.1/7000' || echo "7000 cerrado"
```

## Lecciones

- Cada cambio de emergencia necesita **dueño, ticket y fecha de retirada**, y
  cerrar el incidente incluye deshacerlo.
- `compose.override.yaml` se aplica solo: revisa siempre `docker compose config`, no sólo `compose.yaml`.
- Los servicios borrados del YAML siguen corriendo: `--remove-orphans`.
- Hubo una shell remota con el host montado: en un caso real, trátalo como
  posible compromiso (revisar accesos, rotar `ADMIN_KEY` y credenciales del host).
