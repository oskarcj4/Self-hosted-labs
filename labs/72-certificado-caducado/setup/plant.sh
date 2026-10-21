#!/usr/bin/env bash
# Lab 72: el certificado TLS de shop.local caducó ayer. Lo emitió la CA interna
# (en este mismo servidor, /etc/pki/ca) hace 13 meses, y además no tiene SAN.
set -e
CA=/etc/pki/ca
mkdir -p $CA/newcerts $CA/private /etc/nginx/tls /var/lib/tclab
chmod 0700 $CA/private /var/lib/tclab
: > $CA/index.txt
echo 1000 > $CA/serial
cat > $CA/openssl.cnf <<'EOF'
# CA interna de TerminalCero (uso exclusivo de la red interna).
[ ca ]
default_ca = interna

[ interna ]
dir              = /etc/pki/ca
database         = $dir/index.txt
new_certs_dir    = $dir/newcerts
serial           = $dir/serial
certificate      = $dir/ca.crt
private_key      = $dir/private/ca.key
default_md       = sha256
default_days     = 90
policy           = politica
x509_extensions  = v3_servidor
# Copia al certificado las extensiones de la CSR (p. ej. subjectAltName).
copy_extensions  = copy
unique_subject   = no

[ politica ]
commonName       = supplied
organizationName = optional

[ v3_servidor ]
basicConstraints       = critical, CA:false
keyUsage               = critical, digitalSignature, keyEncipherment
extendedKeyUsage       = serverAuth
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid, issuer

[ v3_ca ]
basicConstraints       = critical, CA:true
keyUsage               = critical, keyCertSign, cRLSign
subjectKeyIdentifier   = hash
EOF

# La CA (válida 10 años).
openssl req -x509 -newkey rsa:3072 -nodes -keyout $CA/private/ca.key -out $CA/ca.crt \
  -days 3650 -subj "/O=TerminalCero/CN=TerminalCero CA Interna" -extensions v3_ca \
  -config $CA/openssl.cnf 2>/dev/null
chmod 0600 $CA/private/ca.key
cp $CA/ca.crt /usr/local/share/ca-certificates/terminalcero-interna.crt
update-ca-certificates >/dev/null 2>&1

# El certificado viejo: sólo CN, emitido hace 13 meses, caducado ayer.
openssl req -new -newkey rsa:2048 -nodes -keyout /etc/nginx/tls/shop.key \
  -out /tmp/shop-old.csr -subj "/O=TerminalCero/CN=shop.local" 2>/dev/null
openssl ca -batch -config $CA/openssl.cnf -in /tmp/shop-old.csr -out /etc/nginx/tls/shop.crt \
  -startdate "$(date -u -d '-396 days' +%Y%m%d%H%M%SZ)" \
  -enddate "$(date -u -d '-1 day' +%Y%m%d%H%M%SZ)" 2>/dev/null
rm -f /tmp/shop-old.csr
openssl pkey -in /etc/nginx/tls/shop.key -pubout | sha256sum | cut -c1-16 > /var/lib/tclab/old-key.fp
chmod 0600 /etc/nginx/tls/shop.key

grep -q 'shop.local' /etc/hosts || echo '127.0.0.1 shop.local www.shop.local' >> /etc/hosts
rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/shop <<'EOF'
server {
    listen 80 default_server;
    server_name shop.local www.shop.local;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl default_server;
    server_name shop.local www.shop.local;
    ssl_certificate     /etc/nginx/tls/shop.crt;
    ssl_certificate_key /etc/nginx/tls/shop.key;
    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        default_type text/plain;
        return 200 "tienda segura\n";
    }
}
EOF
ln -sf /etc/nginx/sites-available/shop /etc/nginx/sites-enabled/shop
systemctl enable --now nginx
sleep 1
cat /run/nginx.pid > /var/lib/tclab/nginx-master.pid

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/INC-7212.txt <<'EOF'
INC-7212 · shop-03 · SEV2 · "su conexión no es privada"
- Desde esta mañana los navegadores y el monitor dan error TLS en
  https://shop.local:  curl: (60) SSL certificate problem: certificate has expired
- El certificado lo emite la CA interna, que vive en este servidor:
  /etc/pki/ca  (config: /etc/pki/ca/openssl.cnf)
- Requisitos del nuevo certificado:
  * Nombres: shop.local y www.shop.local (en subjectAltName: los
    navegadores ignoran el CN desde hace años).
  * Clave nueva (no reutilices la vieja), RSA >= 2048 o ECDSA P-256.
  * Validez: 90 días. Emitido con 'openssl ca' para que quede en el
    registro de la CA (index.txt).
  * La clave privada, sólo legible por root.
- Hay clientes con conexiones largas: aplica el cambio SIN reiniciar nginx.
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 72 plantado."
