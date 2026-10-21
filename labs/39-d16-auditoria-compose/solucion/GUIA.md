# Resolución guiada · Día 16

:::piensa Antes de tocar nada
El disco describe lo que **alguien quería** desplegar; el runtime describe lo que **está corriendo**. Tras un hotfix con un fichero borrado, los dos ya no coinciden. Y la regla de oro: una auditoría no cambia nada. Un `docker compose up` "para ver" reconciliaría el stack con el disco y **borraría la evidencia**.
:::

## Paso 1 · ¿Qué corre y qué publica?

**Pregúntate:** ¿qué contenedores forman el stack y cuál publica un puerto en el host?

:::pista Cómo comprobarlo
```bash
docker compose -p handoff ps
docker ps --format 'table {{.Names}}\t{{.Ports}}'
```
En `0.0.0.0:A->B/tcp`, **A** es el puerto del host y **B** el del contenedor. El informe pide el del host.
:::

## Paso 2 · Redes de cada servicio

**Pregúntate:** ¿cómo pregunto a Docker en qué redes está un contenedor? `docker inspect` tiene toda la información; un formato Go te saca sólo lo que quieres.

:::pista Cómo comprobarlo
```bash
for s in web api worker db; do
  printf '%s: ' $s
  docker inspect handoff-$s-1 --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}'
  echo
done
```
:::

## Paso 3 · Volúmenes compartidos

**Pregúntate:** ¿qué volumen montan **varios** servicios? Ese es el que importa: es un canal de datos entre ellos.

:::pista Cómo comprobarlo
```bash
for s in web api worker db; do
  echo "$s: $(docker inspect handoff-$s-1 --format '{{range .Mounts}}{{.Type}}:{{.Name}}->{{.Destination}} {{end}}')"
done
```
:::

## Paso 4 · Compara con el README

**Pregúntate:** ¿qué dice la documentación que no coincide con lo que acabas de ver? Esas diferencias son el valor de tu auditoría.

```bash
cat ~/handoff/README.md ~/handoff/compose.yaml
```

## Paso 5 · Escribe el informe

:::pista Formato
```bash
mkdir -p ~/audit
cat > ~/audit/handoff.txt <<'EOF'
entrypoint_servicio=<servicio>
entrypoint_puerto=<puerto del host>
redes_web=<redes>
redes_api=<redes>
redes_worker=<redes>
redes_db=<redes>
volumen_compartido=<volumen>
volumen_montado_en=<servicios>
EOF
bash /opt/lab/check.sh
```
:::

## Cómo actuar en una situación así

- **Audita con `docker inspect`**, no con los YAML.
- **No reconcilies** (`up`, `down`, `restart`) hasta haber documentado: perderías el hotfix y la evidencia.
- **Filtra por proyecto** con las etiquetas: `docker ps --filter label=com.docker.compose.project=handoff`.
- Las diferencias encontradas son tareas: actualizar el YAML con el hotfix real, o retirarlo.

## Si te atascas

- No sabes el nombre de un contenedor: `docker compose -p handoff ps --format '{{.Name}}'`.
