# Solución — Scan IaC del Compose

## 1. Cómo el PR #301 puso el scan en verde

| Regla del grep | Esquive | Realidad |
|----------------|---------|----------|
| `image:.*:latest` | `image: shop/api` | sin tag = `latest` |
| existe `user:` | `user: "0"` | root |
| `privileged:\s*true` | `privileged: ${API_PRIV:-true}` | privileged |

Y en el otro sentido, `privileged: true` en un **comentario** daba hallazgo.

## 2. Escáner sobre el modelo renderizado

```bash
json=$(docker compose -f "$f" config --format json) || { echo "HIGH: no evaluable"; exit 1; }
jq -r '
  .services | to_entries[] | .key as $s | .value |
    ((.image // "") as $img | ($img | split("/") | last) as $last
      | if ($img | test("@sha256:[0-9a-f]{64}$")) then empty
        elif ($last | test(":")) and ($last | test(":latest$") | not) then empty
        else "\($s): imagen sin tag fijo" end),
    ((.user // "root") | tostring | split(":")[0]
      | select(. == "" or . == "root" or . == "0") | "\($s): root"),
    (select(.privileged == true) | "\($s): privileged"),
    (.volumes[]? | select(.type == "bind" and (.source | test("docker\\.sock$")))
      | "\($s): docker.sock")
' <<<"$json"
```

## 3. Compose

```yaml
image: shop/api:1.2.0
user: "65534:65534"
```

## Lecciones

- Si el equipo puede leer el escáner, el escáner tiene que ser correcto, no
  secreto. Las reglas sobre texto se esquivan; las reglas sobre el modelo, no.
- Un escáner se prueba como cualquier código: casos que **deben** fallar y
  casos que **deben** pasar. Cada bypass encontrado es un test nuevo.
- Falsos positivos no son inocuos: llevan a `# nosec` y a desactivar el gate.
- Comprueba el runtime, no sólo el fichero: el contenedor es la verdad.
- `user:` en compose es una defensa; la buena es `USER` en el Dockerfile para
  que la imagen sea no-root aunque alguien olvide el compose.
