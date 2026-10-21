# Resolución guiada · Día 23

:::piensa Antes de tocar nada
`privileged: true` no es "un poco más de permisos": es **todos** los dispositivos, **todas** las capacidades y sin perfiles de seguridad. Antes de dar (o mantener) un privilegio, pregunta: **¿qué operación concreta lo necesita?** Y después: ¿esa operación hace falta de verdad?
:::

## Paso 1 · Mide lo que implica

:::pista Cómo comprobarlo
```bash
cd ~/logs
cat compose.yaml
docker compose exec collector sh -c 'ls /dev | wc -l; grep CapEff /proc/1/status'
```
Muchos dispositivos y todas las capacidades: con eso se puede montar el disco del host.
:::

## Paso 2 · Quita el privilegio y observa qué se rompe

**Pregúntate:** ¿por qué lo pusieron? El enunciado da una pista: un `sysctl` en el arranque.

:::pista Cómo hacerlo
Borra `privileged: true` del servicio y:
```bash
docker compose up -d
docker compose ps -a
docker compose logs collector --tail 10
```
:::

## Paso 3 · ¿Hace falta esa operación?

**Pregúntate:** ¿qué hace el colector? Lee un fichero y escribe otro. ¿Abre algún socket de red? Si no, un ajuste de la cola de conexiones (`somaxconn`) no le sirve de nada.

:::pista Cómo comprobarlo
```bash
cat collector/collector.py
```
Si no lo necesita, quita el `sysctl` del `command` (o el `command` entero, para usar el `CMD` de la imagen).
:::

## Paso 4 · Y si lo necesitara…

**Pregúntate:** ¿hay forma de fijar un sysctl sin privilegios? Los `net.*` tienen espacio de nombres por contenedor, y Compose los fija con `sysctls:`:
```yaml
    sysctls:
      net.core.somaxconn: 1024
```
Bueno saberlo; aquí no hace falta.

## Paso 5 · Verifica

```bash
docker compose up -d
docker inspect logs-collector-1 --format '{{.HostConfig.Privileged}}'
echo "$(date +%FT%T) app ERROR prueba" >> logs/app.log; sleep 4; cat out/summary.txt
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Pregunta qué operación necesita el privilegio** y si esa operación hace falta.
- **Alternativas acotadas**: `sysctls:`, una sola `cap_add`, un `devices:` concreto.
- **No sustituyas `privileged` por `cap_add: [ALL]` o `SYS_ADMIN`**: es lo mismo con otro nombre.
- Extra: `cap_drop: [ALL]` y `security_opt: [no-new-privileges:true]`.

## Si te atascas

- El colector no arranca: el log dice qué comando falla. Suele ser el `sysctl` del `command`.
