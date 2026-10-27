# Solución — Admission: política de Compose

## 1. Por qué el grep no es una política

| Bypass | Texto | Lo que ejecuta Docker |
|--------|-------|-----------------------|
| Interpolación | `privileged: ${PRIV:-true}` | `privileged: true` |
| Volumen largo | `source: /var/run` | socket accesible en `/hostrun/docker.sock` |
| Raíz del host | `- /:/host:ro` | todo el host legible |
| Prefijo | `cap_add: [CAP_SYS_ADMIN]` | SYS_ADMIN |
| extends | `extends: {file: base.yaml}` | hereda `privileged` |
| Comillas/espacios | `network_mode:   "host"` | red del host |
| Otro servicio | `sidecar: {ipc: host}` | IPC del host |

Y al revés: un comentario `# antes: privileged: true` hace que el grep
rechace un manifiesto legítimo. Falsos positivos = equipos que desactivan
el gate.

## 2. Evaluar el manifiesto renderizado

```bash
json=$(docker compose -f "$f" config --format json) || { echo DENY; exit 1; }
jq -r '
  def bad_src: . == "/" or test("docker\\.sock$")
    or test("^/(var/run|run|proc|sys|etc|var/lib/docker)(/|$)");
  .services | to_entries[] | .key as $s | .value |
    (select(.privileged == true) | "\($s): privileged"),
    ({pid, ipc, network_mode, userns_mode} | to_entries[]
       | select(.value == "host") | "\($s): \(.key)=host"),
    (.volumes[]? | select(.type == "bind" and (.source | bad_src))
       | "\($s): bind \(.source)"),
    (.cap_add[]? | ascii_upcase | ltrimstr("CAP_")
       | select(IN("ALL","SYS_ADMIN","SYS_MODULE","SYS_PTRACE")) | "\($s): cap \(.)"),
    (.security_opt[]? | select(test("unconfined")) | "\($s): \(.)")
' <<<"$json"
```

Script completo en `solve.sh`.

## 3. Gancho fail-closed

```bash
set -euo pipefail
./admit.sh compose.yaml
docker compose up -d --build
```

## Lecciones

- Política sobre el **objeto evaluado**, no sobre su representación textual
  (igual que Kyverno/OPA evalúan el objeto ya decodificado, no el YAML).
- Un corpus de bypasses es el test unitario de la política. Si no tienes
  casos negativos y positivos, no sabes lo que hace tu gate.
- Fail-closed: lo que no se puede evaluar, no se despliega.
- Este gate no sustituye al runtime: quien tenga `docker` en el host puede
  saltarse `deploy.sh`. Admission vale si es el **único** camino a producción.
