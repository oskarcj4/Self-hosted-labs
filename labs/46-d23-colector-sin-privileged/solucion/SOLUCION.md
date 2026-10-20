# Solución — Día 23: Quitar privileged a un colector

## 1. Qué implica `privileged`

```bash
cd ~/logs
docker compose exec collector sh -c 'ls /dev | wc -l; grep CapEff /proc/1/status'
# decenas de dispositivos del host y CapEff: 000001ffffffffff (todas)
```

Con eso un proceso del contenedor puede montar el disco del host, cargar
módulos del kernel, etc.

## 2. Primer intento: quitar `privileged`

```bash
docker compose logs collector --tail 3
# sysctl: error setting key 'net.core.somaxconn': Read-only file system
```

Sin privilegios el `sysctl -w` del `command` falla y el `&&` impide arrancar.

## 3. ¿Lo necesita?

El colector lee un fichero y escribe otro: **no abre ningún socket**, así que
`somaxconn` no le sirve de nada. Se elimina del `command`.

Si un servicio de red sí lo necesitara, `net.*` es un sysctl con espacio de
nombres por contenedor y Compose lo fija **sin privilegios**:

```yaml
    sysctls:
      net.core.somaxconn: 1024
```

## 4. compose.yaml final

```yaml
services:
  collector:
    image: logs/collector:0.9
    build: ./collector
    volumes:
      - ./logs:/logs:ro
      - ./out:/out
    restart: unless-stopped
```

(Sin `command`: se usa el `CMD` de la imagen.)

```bash
docker compose up -d
docker inspect logs-collector-1 --format '{{.HostConfig.Privileged}}'   # false
echo "$(date +%FT%T) app ERROR prueba" >> logs/app.log; sleep 4; cat out/summary.txt
```

## Lecciones

- `privileged: true` ≈ root en el host. Casi nunca está justificado fuera de
  casos como Docker-in-Docker (¡como este laboratorio!).
- Antes de dar privilegios, pregunta qué operación concreta los necesita.
- Muchas necesidades tienen alternativa acotada: `sysctls:`, una sola
  `cap_add`, un `devices:` concreto.
- Extra: `cap_drop: [ALL]` y `security_opt: [no-new-privileges:true]`.
