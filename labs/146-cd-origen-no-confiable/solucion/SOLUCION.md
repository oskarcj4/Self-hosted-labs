# Solución — El CD de origen no confiable

## Qué pasaba

La copia entregada (`/opt/entrega/instalador.sh`) trae una línea extra que crea
`/tmp/pwned` e intenta exfiltrar a `127.0.0.1:9146`. Por eso su sha256 no cuadra
con `SHA256SUMS` y la firma GPG da **BAD signature**: el `.asc` y los hashes son
de la copia buena del mirror. La versión legítima vive en `/srv/mirror/`.

## Arreglo

```bash
# 1) Procedencia + integridad de lo entregado
gpg --import /opt/entrega/vendor.pub
cd /opt/entrega
sha256sum -c SHA256SUMS                       # instalador.sh: FAILED
gpg --verify instalador.sh.asc instalador.sh  # BAD signature  -> a la basura

# 2) Veredicto (sha del legítimo, el del mirror)
WANT=$(sha256sum /srv/mirror/instalador.sh | cut -d' ' -f1)
gpg --verify /srv/mirror/instalador.sh.asc /srv/mirror/instalador.sh   # Good signature
cat > ~/veredicto.txt <<V
entregado_integro=no
firma_valida=no
sha_correcto=$WANT
V

# 3) Ejecutar el legítimo aislado y SIN red
bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp \
      --bind ~/instalado /mnt --unshare-net \
      env DESTINO=/mnt bash /srv/mirror/instalador.sh | tee ~/salida-sandbox.txt
# -> "contacto=sin-red" e "instalado en /mnt"; la marca queda en ~/instalado/OK

bash /opt/lab/check.sh
```

## Más allá del lab

- El orden importa: **verifica antes de ejecutar**, y ejecuta aislado aunque
  verifique (defensa en profundidad: una clave robada firma malware válido).
- En CI real: `cosign verify`, pin por digest, `--require-hashes` en pip,
  comprobación de checksums en el pipeline y ejecución en runners efímeros.
- `--unshare-net` es lo que convierte "ejecuté algo raro" en "no pudo llamar a
  casa". Añade `--die-with-parent` y capacidades mínimas para endurecerlo más.
