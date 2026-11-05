# Resolución guiada · Lab 146

:::piensa Dos preguntas, en este orden
¿Es el fichero que el proveedor publicó (integridad, sha256)? ¿Lo firmó de
verdad el proveedor (procedencia, GPG)? Si una falla, no se ejecuta. Y aunque
pasen ambas, se ejecuta aislado.
:::

## Paso 1 · Integridad de lo entregado

:::pista Cómo comprobarlo
```bash
cd /opt/entrega && sha256sum -c SHA256SUMS
```
`instalador.sh: FAILED`. El fichero cambió por el camino.
:::

## Paso 2 · Procedencia

**Pregúntate:** ¿la firma corresponde al contenido que tengo delante?

:::pista Cómo comprobarlo
```bash
gpg --import /opt/entrega/vendor.pub
gpg --verify /opt/entrega/instalador.sh.asc /opt/entrega/instalador.sh
```
`BAD signature`. No es lo que el proveedor firmó.
:::

## Paso 3 · Usa el legítimo y escribe el veredicto

:::pista Cómo hacerlo
```bash
gpg --verify /srv/mirror/instalador.sh.asc /srv/mirror/instalador.sh   # Good signature
WANT=$(sha256sum /srv/mirror/instalador.sh | cut -d' ' -f1)
cat > ~/veredicto.txt <<V
entregado_integro=no
firma_valida=no
sha_correcto=$WANT
V
```
:::

## Paso 4 · Ejecútalo en una jaula sin red

:::pista Cómo hacerlo
```bash
bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp \
      --bind ~/instalado /mnt --unshare-net \
      env DESTINO=/mnt bash /srv/mirror/instalador.sh | tee ~/salida-sandbox.txt
```
`contacto=sin-red` demuestra que la red estaba cortada.
:::

## Cómo actuar en una situación así

- Verifica SIEMPRE antes de ejecutar; aísla SIEMPRE lo de origen externo.
- Una firma válida no es un cheque en blanco: la sandbox limita el daño si la
  clave del proveedor estuviera comprometida.

## Si te atascas

- `gpg --verify` dice "Good signature" con aviso amarillo de confianza: es
  normal, no has establecido trust. Lo que cuenta es que valide.
- La salida dice `contacto=ok`: olvidaste `--unshare-net`.
- `~/instalado/OK` no aparece: revisa que montaste `--bind ~/instalado /mnt` y
  pasaste `DESTINO=/mnt`.
