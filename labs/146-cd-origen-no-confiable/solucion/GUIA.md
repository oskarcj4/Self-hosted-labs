# Resolución guiada · Lab 146

:::piensa Dos preguntas, en este orden
¿Es el fichero que el proveedor publicó? (**integridad**: el hash). ¿Lo
publicó de verdad el proveedor? (**procedencia**: la firma). Si una de las dos
falla, no se ejecuta. Y aunque pasen ambas, se ejecuta **aislado**: si la
clave del proveedor estuviera comprometida, la sandbox limita el daño.
:::

**El plan:** (1) comprobar la integridad de lo entregado, (2) comprobar su
procedencia, (3) verificar el instalador legítimo y escribir el veredicto y
(4) ejecutarlo en una sandbox sin red.

## Paso 1 · Integridad de lo entregado

:::pista Cómo hacerlo
```bash
cd /opt/entrega && sha256sum -c SHA256SUMS
```
`SHA256SUMS` contiene el hash (la huella) que el proveedor calculó de cada
fichero. `sha256sum -c` recalcula el de tu copia y lo compara.

**Qué deberías ver:** `instalador.sh: FAILED`. El fichero cambió por el
camino.
:::

## Paso 2 · Procedencia

**Pregúntate:** el hash no cuadra, pero ¿y si el atacante cambió también
`SHA256SUMS`? ¿Qué no puede falsificar?

:::pista Cómo hacerlo
La firma, porque no tiene la clave privada del proveedor.
```bash
gpg --import /opt/entrega/vendor.pub
gpg --verify /opt/entrega/instalador.sh.asc /opt/entrega/instalador.sh
```
- `gpg --import` añade la clave **pública** del proveedor a tu llavero: sirve
  para comprobar firmas, no para firmar.
- `gpg --verify firma fichero` comprueba que la firma (`.asc`) se hizo con la
  clave privada del proveedor **sobre ese contenido exacto**.

**Qué deberías ver:** `BAD signature`. No es lo que el proveedor firmó.
:::

## Paso 3 · El instalador legítimo y el veredicto

:::pista Cómo hacerlo
```bash
gpg --verify /srv/mirror/instalador.sh.asc /srv/mirror/instalador.sh
WANT=$(sha256sum /srv/mirror/instalador.sh | cut -d' ' -f1)
cat > ~/veredicto.txt <<V
entregado_integro=no
firma_valida=no
sha_correcto=$WANT
V
cat ~/veredicto.txt
```
- **Qué deberías ver** en el `gpg`: `Good signature`, con un aviso de que la
  clave no está certificada como de confianza. Es normal: no has firmado tú la
  clave del proveedor. Lo que importa es que la firma valide.
- `cut -d' ' -f1` se queda con el primer campo de la salida de `sha256sum` (el
  hash, sin el nombre del fichero).
- `<<V` sin comillas: la shell sustituye `$WANT` por su valor al escribir.
:::

## Paso 4 · Ejecútalo en una jaula sin red

:::pista Cómo hacerlo
```bash
mkdir -p ~/instalado
bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp \
      --bind ~/instalado /mnt --unshare-net \
      env DESTINO=/mnt bash /srv/mirror/instalador.sh | tee ~/salida-sandbox.txt
```
**bubblewrap** (`bwrap`) ejecuta un programa en una sandbox construida con las
piezas que le digas:

| Opción | Qué hace |
|---|---|
| `--ro-bind / /` | El sistema de ficheros entero, pero en **sólo lectura**. |
| `--dev /dev` `--proc /proc` | Un `/dev` y un `/proc` mínimos, propios. |
| `--tmpfs /tmp` | Un `/tmp` vacío que desaparece al terminar. |
| `--bind ~/instalado /mnt` | La única carpeta escribible: tu `~/instalado`, vista dentro como `/mnt`. |
| `--unshare-net` | Sin red: el instalador no puede "llamar a casa". |

`env DESTINO=/mnt` le pasa al instalador dónde instalar.

**Qué deberías ver:** en la salida, `contacto=sin-red`; y en `~/instalado`,
lo que instaló.
```bash
ls ~/instalado
bash /opt/lab/check.sh
```
:::

## Cómo actuar en una situación así

- Verifica siempre antes de ejecutar; aísla siempre lo de origen externo.
- La huella de la clave del proveedor tiene que venir por un canal distinto
  del que trae el fichero (su web, un contacto). Si viene del mismo CD, el
  atacante puede cambiarla también (lab 77).
- Una firma válida no es un cheque en blanco: la sandbox limita el daño si la
  clave del proveedor estuviera comprometida.

## Si te atascas

- **La salida dice `contacto=ok`:** olvidaste `--unshare-net`.
- **`~/instalado` está vacío:** falta `--bind ~/instalado /mnt` o
  `DESTINO=/mnt`.
- **`bwrap: Can't mkdir …: Read-only file system`:** el instalador intentó
  escribir fuera de `/mnt`. Es la sandbox funcionando; revisa `DESTINO`.
