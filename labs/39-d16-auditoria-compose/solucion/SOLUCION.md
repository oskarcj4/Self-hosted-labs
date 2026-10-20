# Solución — Día 16: Auditoría de traspaso de un stack Compose

## 1. ¿Qué corre y qué publica?

```bash
docker compose -p handoff ps
docker ps --format 'table {{.Names}}\t{{.Ports}}'
```

Sólo `handoff-web-1` publica algo: `0.0.0.0:8443->8080/tcp`.
El README y `compose.yaml` dicen **8080**, pero el hotfix lo cambió a **8443**.
`docker port handoff-web-1` lo confirma.

## 2. Redes de cada servicio

```bash
for s in web api worker db; do
  printf '%s: ' $s
  docker inspect handoff-$s-1 --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}'
  echo
done
```

| Servicio | Redes |
|---|---|
| web | handoff_frontend |
| api | handoff_backend, handoff_frontend |
| worker | handoff_backend |
| db | handoff_backend |

Ojo: el README dice que `db` está en `frontend`; **no es cierto**.

## 3. Volumen compartido

```bash
for s in web api worker db; do
  echo "$s: $(docker inspect handoff-$s-1 --format '{{range .Mounts}}{{.Type}}:{{.Name}}->{{.Destination}} {{end}}')"
done
```

`api` y `worker` montan `handoff_reports` en `/srv/reports` (el README decía `data`).

## 4. Informe

```bash
cat > ~/audit/handoff.txt <<'EOF'
entrypoint_servicio=web
entrypoint_puerto=8443
redes_web=frontend
redes_api=backend,frontend
redes_worker=backend
redes_db=backend
volumen_compartido=reports
volumen_montado_en=api,worker
EOF
```

## Lecciones

- Compose fusiona varios ficheros (`-f a.yaml -f b.yaml`). Si uno desaparece,
  el disco deja de describir el runtime: **audita con `docker inspect`**.
- Un `docker compose up -d` "inocente" reconcilia el stack con lo que hay en
  disco y borra el hotfix (y la evidencia). Primero se audita, luego se cambia.
- Las etiquetas `com.docker.compose.project/service` permiten filtrar
  contenedores por stack: `docker ps --filter label=com.docker.compose.project=handoff`.
