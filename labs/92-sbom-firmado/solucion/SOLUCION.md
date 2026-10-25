# Solución — SBOM firmado y verificado

## 1. El gate verde que no vale nada

El PR #214 cambió `keys/sbom.pub` por la clave pública del atacante y subió un
`dist/sbom.json` firmado con su privada. `verify.sh` verificaba contra
`keys/sbom.pub`: la firma es matemáticamente válida y el gate pasa.

```bash
openssl pkey -pubin -in keys/sbom.pub -outform DER | sha256sum
openssl pkey -pubin -in /etc/release/trusted.pub -outform DER | sha256sum
```

Además el SBOM decía `id: sha256:000…` (no es la imagen) y
`packages: ["python==3.12"]` (no es un inventario).

## 2. Tres preguntas que el verificador tiene que contestar

| Pregunta | Control | Ataque que para |
|----------|---------|-----------------|
| ¿Quién firmó? | clave fija `/etc/release/trusted.pub` | firma con otra clave |
| ¿Se cambió algo? | `openssl dgst -verify` | SBOM editado tras firmar |
| ¿Es de este artefacto? | `.id` == `docker image inspect` | imagen sustituida |

```bash
openssl dgst -sha256 -verify /etc/release/trusted.pub \
  -signature dist/sbom.json.sig dist/sbom.json >/dev/null || exit 1
[ "$(jq -r .id dist/sbom.json)" = "$(docker image inspect -f '{{.Id}}' "$img")" ] || exit 1
```

## 3. Inventario sacado de la imagen

```bash
docker run --rm --network none --entrypoint apk "$img" info -v 2>/dev/null | sort \
  | jq -R . | jq -s --arg img "$img" --arg id "$id" '{image:$img, id:$id, packages:.}'
```

Límite honesto: `apk` sólo ve lo que instaló `apk`. En `python:3.12-alpine`
el propio Python está compilado desde fuente y `pip` no aparece. Por eso
existen syft/trivy: leen también metadatos de Python, Node, Go, etc.

## Lecciones

- Una firma válida sin ancla de confianza no prueba nada. La clave pública
  **nunca** viaja en el mismo cambio que el artefacto que verifica.
- El SBOM firmado tiene que estar atado al digest del artefacto. Cosign lo hace
  adjuntando la atestación al digest en el registry.
- La privada de firma no vive en el repo. En CI real: KMS/HSM o firma
  *keyless* (OIDC + Fulcio + Rekor) para no tener privada que robar.
