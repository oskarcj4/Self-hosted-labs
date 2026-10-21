# Resolución guiada · Día 30

:::piensa Antes de tocar nada
Cerrar un incidente incluye **deshacer los cambios de emergencia**. Si no, el remedio se queda como una vulnerabilidad. Aquí hay dos trampas de Compose: el `compose.override.yaml` se aplica **solo**, sin que nadie lo pida, y un servicio que borras del YAML **sigue corriendo** hasta que lo eliminas explícitamente.
:::

## Paso 1 · ¿Qué configuración se aplica de verdad?

**Pregúntate:** si sólo miro `compose.yaml`, ¿veo todo? No. ¿Qué comando me da la configuración efectiva?

:::pista Cómo comprobarlo
```bash
cd ~/portal
ls -la
docker compose config
docker compose ps -a
```
Compara la salida de `docker compose config` con `compose.yaml`: lo que sobra viene del override.
:::

## Paso 2 · Comprueba el riesgo actual

**Pregúntate:** ¿qué puede hacer hoy alguien que llegue al host?

```bash
curl -s -o /dev/null -w '%{http_code}\n' localhost:8000/admin      # sin credenciales
docker ps --format '{{.Names}}\t{{.Ports}}'
```

## Paso 3 · Preserva la evidencia

**Pregúntate:** antes de borrar, ¿qué querría tener mañana el equipo del incidente? El override y los logs del servicio de depuración.

:::pista Cómo hacerlo
```bash
mkdir -p ~/evidencia-INC-3107
cp compose.override.yaml ~/evidencia-INC-3107/
docker compose logs > ~/evidencia-INC-3107/compose.log
```
:::

## Paso 4 · Retira el override y los huérfanos

**Pregúntate:** al quitar el override, `debug-shell` desaparece de la configuración. ¿Desaparece también el contenedor? No: queda **huérfano**. ¿Qué opción de `up` los elimina?

:::pista Cómo hacerlo
```bash
rm compose.override.yaml
docker compose config | grep -E 'AUTH_BYPASS|debug' || echo "config limpia"
docker compose up -d --remove-orphans
docker ps -a
```
:::

## Paso 5 · Verifica los cuatro objetivos

```bash
docker ps -a                                                          # sólo la app
curl -s -o /dev/null -w '%{http_code}\n' localhost:8000/admin         # 401
curl -s -o /dev/null -w '%{http_code}\n' -H "X-Admin-Key: $(sed -n 's/^ADMIN_KEY=//p' .env)" localhost:8000/admin   # 200
timeout 2 bash -c 'exec 3<>/dev/tcp/127.0.0.1/7000' && echo ABIERTO || echo "7000 cerrado"
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Cada cambio de emergencia: dueño, ticket y fecha de retirada.**
- **Revisa `docker compose config`**, no sólo `compose.yaml`.
- **`--remove-orphans`** al quitar servicios del YAML.
- Hubo una shell remota con el host montado: trátalo como **posible compromiso** (revisar accesos, rotar `ADMIN_KEY` y credenciales del host).

## Si te atascas

- `debug-shell` sigue en `docker ps -a`: te faltó `--remove-orphans`.
- `/admin` sigue dando 200 sin clave: la app no se recreó; repite `docker compose up -d`.
