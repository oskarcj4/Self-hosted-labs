# Resolución guiada · Lab 92

:::piensa ¿Firmado por quién, y de qué?
Una firma válida sólo dice "lo firmó el dueño de **esta** clave". Si la clave
pública con la que verificas llega en el mismo pull request que el artefacto,
el atacante elige la clave con la que le verificas: firma con la suya, pone su
pública, y todo sale en verde. El gate tiene que preguntar dos cosas: ¿lo
firmó **quien yo confío**? ¿Y describe **la imagen que voy a publicar**?
:::

**El plan:** (1) ver con qué clave verifica el gate, (2) fijar el ancla de
confianza, (3) atar el SBOM a la imagen, (4) sacar el inventario real y
(5) firmar y verificar.

## Paso 1 · ¿Con qué clave verifica el gate?

:::pista Cómo hacerlo
```bash
cd ~/release
cat verify.sh
openssl pkey -pubin -in keys/sbom.pub -outform DER | sha256sum
openssl pkey -pubin -in /etc/release/trusted.pub -outform DER | sha256sum
```
`openssl pkey -pubin -in X -outform DER` convierte la clave pública a su forma
binaria; su `sha256sum` es una **huella**: dos claves son la misma sólo si su
huella coincide.

**Qué deberías ver:** `verify.sh` usa `keys/sbom.pub`, la del repo, y su
huella no es la de `/etc/release/trusted.pub`. El PR #214 trajo una clave
nueva y un SBOM firmado con ella.
:::

## Paso 2 · Un ancla de confianza fija

:::pista Cómo hacerlo
En `verify.sh`, verifica siempre contra la clave que puso root:
```bash
openssl dgst -sha256 -verify /etc/release/trusted.pub -signature dist/sbom.json.sig dist/sbom.json
```
y borra `keys/sbom.pub` para que nadie vuelva a usarla.

`openssl dgst -sha256 -verify <pública> -signature <firma> <fichero>` calcula
el hash del fichero y comprueba que la firma se hizo sobre ese hash con la
clave privada que corresponde a esa pública. Un usuario normal no puede
modificar `/etc/release/`, así que un PR tampoco.
:::

## Paso 3 · Ata el SBOM a la imagen

**Pregúntate:** ¿sirve una firma válida sobre un SBOM que describe otra
imagen?

:::pista Cómo hacerlo
No. Tras verificar la firma, compara el `id` que dice el SBOM con el de la
imagen real:
```bash
img="${1:-shop/rel:1.0}"
want=$(docker image inspect -f '{{.Id}}' "$img")
got=$(jq -r .id dist/sbom.json)
[ "$got" = "$want" ] || { echo "FAIL: el SBOM describe $got, no $img"; exit 1; }
```
- `${1:-shop/rel:1.0}`: el primer argumento, o esa imagen por defecto.
- `docker image inspect -f '{{.Id}}'` da el identificador de la imagen: el hash
  de su contenido. Si alguien sustituye la imagen, cambia.
:::

## Paso 4 · El inventario real

:::pista Cómo hacerlo
`sbom-gen.sh` tiene que sacar los paquetes **de la imagen**, no de una lista
escrita a mano:
```bash
img="${1:-shop/rel:1.0}"
id=$(docker image inspect -f '{{.Id}}' "$img")
docker run --rm --network none --entrypoint apk "$img" info -v 2>/dev/null | sort \
  | jq -R . | jq -s --arg img "$img" --arg id "$id" '{image: $img, id: $id, packages: .}' \
  > dist/sbom.json
```
- `--entrypoint apk … info -v` ejecuta en la imagen el gestor de paquetes de
  Alpine, que lista lo instalado con versión. `--network none`: sin red.
- `jq -R .` convierte cada línea en una cadena JSON; `jq -s` las junta en una
  lista (`-s`, *slurp*), y construye el objeto con `--arg` (valores pasados
  desde la shell).
:::

## Paso 5 · Firma y verifica

```bash
./sbom-gen.sh
openssl dgst -sha256 -sign ~/.signing/release.key -out dist/sbom.json.sig dist/sbom.json
./verify.sh
grep -rl "PRIVATE KEY" ~/release || echo "ninguna clave privada en el repo"
bash /opt/lab/check.sh
```
`-sign <privada>` firma el hash del fichero. La clave privada está fuera del
repositorio, en `~/.signing/`, y ahí se queda.

**Qué deberías ver:** `OK: release shop/rel:1.0 verificado`.

## Cómo actuar en una situación así

- El ancla de confianza (la clave pública) nunca viaja con lo que verifica.
  Va fija en el sistema que verifica, o en un registro de transparencia.
- Firmar no basta: el contenido firmado tiene que estar atado al artefacto
  (aquí, el `id` de la imagen).
- En la vida real: `syft` para el SBOM y `cosign` para firmar y adjuntarlo a la
  imagen.

## Si te atascas

- **`Verification Failure`:** firmaste con otra clave o modificaste
  `sbom.json` después de firmar. Vuelve a firmar.
- **`FAIL: el SBOM describe …`:** generaste el SBOM de otra imagen; repite
  `./sbom-gen.sh` con la correcta.
- **El check encuentra una clave privada:** quedó alguna dentro de `~/release`.
