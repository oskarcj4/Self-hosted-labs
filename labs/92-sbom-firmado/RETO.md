# SBOM firmado y verificado

> Pipeline / runtime · supply chain · SBOM · firma · ancla de confianza

## Escenario

El gate de release de `~/release` está **en verde**:

```bash
cd ~/release && ./verify.sh     # Verified OK
```

Y aun así algo huele mal. El último PR (#214, "rotar clave de SBOM") tocó
`keys/sbom.pub` y `dist/`. Lo que sabes seguro:

- La clave de firma del release vive en `~/.signing/release.key` (fuera del repo).
- La clave pública **de confianza** la puso root en `/etc/release/trusted.pub`.
- La imagen que se va a publicar es `shop/rel:1.0`.

Una firma válida sólo dice "lo firmó el dueño de *esta* clave". Si la clave
pública viene en el mismo PR que el artefacto, el atacante elige con qué
clave le verificas.

## Objetivos

1. `verify.sh` confía **sólo** en `/etc/release/trusted.pub`. Una clave
   dentro del repo no es un ancla de confianza.
2. `verify.sh [imagen]` falla si el `id` del SBOM no es el de esa imagen
   (`docker image inspect`). Firmar un SBOM no sirve si describe otra cosa.
3. `sbom-gen.sh` saca el inventario de la imagen real: `packages` es la lista
   de `apk info -v` dentro de `shop/rel:1.0`, no una lista a mano.
4. `dist/sbom.json` + `dist/sbom.json.sig` firmados con la clave del release
   y `./verify.sh` en verde.
5. Ninguna clave privada dentro de `~/release`.

El check va a intentar colarte un SBOM firmado con otra clave, un SBOM
alterado y una imagen sustituida.

## Comandos que te pueden servir

```bash
cd ~/release
cat verify.sh sbom-gen.sh dist/sbom.json
openssl pkey -pubin -in keys/sbom.pub -outform DER | sha256sum
openssl pkey -pubin -in /etc/release/trusted.pub -outform DER | sha256sum
docker image inspect -f '{{.Id}}' shop/rel:1.0
docker run --rm --entrypoint apk shop/rel:1.0 info -v
openssl dgst -sha256 -sign ~/.signing/release.key -out dist/sbom.json.sig dist/sbom.json
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
