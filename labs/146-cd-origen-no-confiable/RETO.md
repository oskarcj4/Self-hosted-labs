# El CD de origen no confiable

> Mr. Robot · cadena de suministro · sha256 · firma GPG · sandbox con bubblewrap

## Escenario

Llega un instalador "de proveedor" por un medio que no controlas (un CD, una
descarga sin HTTPS, un USB). Regla de oro: **nada de origen externo se ejecuta
sin verificar su integridad y su procedencia, y aun así se ejecuta aislado.**

La copia entregada está en `/opt/entrega/`. El proveedor publica su mirror
oficial en `/srv/mirror/` (instalador, firma `.asc` y `SHA256SUMS`) y su clave
pública en `/opt/entrega/vendor.pub`.

- **sha256** prueba integridad: si el hash no coincide con el publicado, el
  fichero cambió por el camino.
- **Firma GPG** prueba procedencia: sólo quien tiene la clave privada del
  proveedor pudo firmar. Una firma que no valida = no es del proveedor o lo
  manipularon.
- **bubblewrap** (`bwrap`) ejecuta un binario en una sandbox: sistema de
  ficheros de solo lectura, `/tmp` efímero y **sin red** (`--unshare-net`).
  Aunque el instalador intente "llamar a casa", no puede.

## Objetivos

1. Verifica la copia entregada: `sha256sum -c` contra `SHA256SUMS` y
   `gpg --verify` con la clave del proveedor. Decide si es íntegra y si la
   firma es válida.
2. `~/veredicto.txt`:

   ```
   entregado_integro=<si|no>
   firma_valida=<si|no>
   sha_correcto=<sha256 del instalador legítimo del mirror>
   ```

3. Ejecuta el instalador **legítimo** (el del mirror, ya verificado) dentro de
   una sandbox de bubblewrap **sin red**, con la salida en
   `~/salida-sandbox.txt` y el destino montado en `~/instalado`.
   **No ejecutes la copia entregada.**

## Comandos que te pueden servir

```bash
gpg --import /opt/entrega/vendor.pub
cd /opt/entrega && sha256sum -c SHA256SUMS            # FAILED en la copia manipulada
gpg --verify /opt/entrega/instalador.sh.asc /opt/entrega/instalador.sh   # BAD signature
sha256sum /srv/mirror/instalador.sh
gpg --verify /srv/mirror/instalador.sh.asc /srv/mirror/instalador.sh     # Good signature
# Ejecutar el legítimo aislado y sin red:
bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp \
      --bind ~/instalado /mnt --unshare-net \
      env DESTINO=/mnt bash /srv/mirror/instalador.sh | tee ~/salida-sandbox.txt
```

> Una firma "Good" con aviso de confianza (el proveedor no está en tu web of
> trust) es normal en el lab: lo que importa es que **valide**. La copia
> entregada ni valida ni cuadra en hash: a la basura.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
