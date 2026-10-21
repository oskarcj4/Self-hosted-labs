#!/bin/bash
# artifacts.interno (lab 77). Publica kvtool 1.4.1 y 1.4.2 con SHA256SUMS firmados.
#
# Simulación de compromiso del mirror (benigna, para formación):
#  - El 1.4.2 que se sirve NO es el del fabricante: es una build distinta
#    (lleva el marcador inofensivo "TAMPERED-BUILD").
#  - Su SHA256SUMS se ha regenerado y firmado con la clave DEL ATACANTE, que
#    usa el mismo nombre/correo que la del fabricante para despistar.
#  - Esa clave se ha añadido a KEYS.asc, junto a la auténtica.
# No hay ningún payload real: el objetivo es que el alumno distinga las firmas
# por la HUELLA, no por el nombre, y rechace lo que no firme el fabricante.
set -e
W=/srv/www/kvtool
mkdir -p $W /srv/lab
genkey(){ GNUPGHOME=$1 gpg -q --batch --pinentry-mode loopback --passphrase '' \
  --quick-gen-key "Kvtool Release <release@kvtool.example>" ed25519 sign 3y; }
mkdir -m 700 -p /root/legit /root/evil
genkey /root/legit; genkey /root/evil
fpr(){ GNUPGHOME=$1 gpg --batch --with-colons --list-keys | awk -F: '/^fpr/ {print $10; exit}'; }

build(){  # build <versión> <marcador 0|1>
  local v=$1 d; d=$(mktemp -d)
  cat > $d/kvtool <<EOF
#!/bin/sh
# kvtool: cliente del almacén clave-valor de la plataforma.
case "\$1" in
  --version) echo "kvtool $v" ;;
  get) echo "(demo) valor de \$2" ;;
  put) echo "(demo) guardado \$2=\$3" ;;
  *) echo "uso: kvtool --version | get <clave> | put <clave> <valor>" ;;
esac
EOF
  # Build manipulada: un marcador inofensivo. Basta para que el hash cambie.
  [ "$2" = 1 ] && echo '# TAMPERED-BUILD (no es la build del fabricante)' >> $d/kvtool
  chmod 0755 $d/kvtool
  mkdir -p $W/$v
  tar -C $d -czf $W/$v/kvtool-$v-linux-amd64.tar.gz kvtool
  [ "$2" = 0 ] && sha256sum $d/kvtool | cut -d' ' -f1 > /srv/lab/legit-$v.sha
  (cd $W/$v && sha256sum kvtool-$v-linux-amd64.tar.gz > SHA256SUMS)
  rm -rf $d
}
build 1.4.1 0
build 1.4.2 1
sign(){ GNUPGHOME=$1 gpg -q --batch --yes --pinentry-mode loopback --passphrase '' \
  --armor --detach-sign -o $W/$2/SHA256SUMS.asc $W/$2/SHA256SUMS; }
sign /root/legit 1.4.1        # 1.4.1: firma del fabricante
sign /root/evil  1.4.2        # 1.4.2: firma del atacante (otra clave, mismo nombre)
{ GNUPGHOME=/root/legit gpg --armor --export; GNUPGHOME=/root/evil gpg --armor --export; } > $W/KEYS.asc
echo 1.4.2 > $W/LATEST
fpr /root/legit > /srv/lab/fingerprint
# Las tripas del lab (sólo para el plant y el validador).
mkdir -p /srv/www/__lab && cp /srv/lab/* /srv/www/__lab/
cd /srv/www && exec python3 -m http.server 80
