# Resolución guiada · Lab 92

:::piensa
`verify.sh` contesta "¿alguien firmó esto?". La pregunta del gate es otra:
"¿lo firmó **quien yo confío**, y describe **la imagen que voy a publicar**?"
:::

## Paso 1 · ¿Con qué clave verifica el gate?

Compara las huellas de `keys/sbom.pub` y `/etc/release/trusted.pub`
(`openssl pkey -pubin -in X -outform DER | sha256sum`). No coinciden: el PR
#214 trajo su propia clave y un SBOM firmado con ella. El gate verifica con la
clave que le da el atacante.

## Paso 2 · Ancla de confianza fija

En `verify.sh`, `-verify /etc/release/trusted.pub`. Borra `keys/sbom.pub`:
que nadie vuelva a usarla.

## Paso 3 · Ata el SBOM a la imagen

Tras la firma, compara `jq -r .id dist/sbom.json` con
`docker image inspect -f '{{.Id}}' "$img"`. Si difieren, `exit 1`.

## Paso 4 · Inventario real

En `sbom-gen.sh`:
`docker run --rm --network none --entrypoint apk "$img" info -v 2>/dev/null | sort`, y
`jq -R . | jq -s '{image:..., id:..., packages: .}'`.

## Paso 5 · Firma y verifica

```bash
./sbom-gen.sh
openssl dgst -sha256 -sign ~/.signing/release.key -out dist/sbom.json.sig dist/sbom.json
./verify.sh
```
