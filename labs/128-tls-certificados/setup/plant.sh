#!/usr/bin/env bash
# Lab 128: cinco webs HTTPS en el mismo proxy, cada una con un certificado
# distinto (válido, caducado, autofirmado, nombre equivocado y un phishing
# con certificado perfectamente válido).
set -e
CA=/root/ca
mkdir -p $CA/certs /etc/nginx/tls
touch $CA/index.txt; echo 1000 > $CA/serial
cat > $CA/ca.cnf <<'C'
[ ca ]
default_ca = lab
[ lab ]
dir = /root/ca
database = $dir/index.txt
new_certs_dir = $dir/certs
serial = $dir/serial
default_md = sha256
policy = pol
copy_extensions = copy
unique_subject = no
[ pol ]
commonName = supplied
organizationName = optional
C
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -keyout $CA/ca.key -out $CA/ca.crt \
  -subj "/O=Empresa Lab/CN=Empresa Lab CA Interna" 2>/dev/null
chmod 600 $CA/ca.key
cp $CA/ca.crt /usr/local/share/ca-certificates/empresa-lab-ca.crt
update-ca-certificates >/dev/null

# firmar <nombre> <SAN> <inicio> <fin>
firmar(){
  openssl req -new -newkey rsa:2048 -nodes -keyout /etc/nginx/tls/$1.key -subj "/CN=$2" \
    -addext "subjectAltName=DNS:$2" -out /tmp/$1.csr 2>/dev/null
  openssl ca -batch -config $CA/ca.cnf -cert $CA/ca.crt -keyfile $CA/ca.key \
    -startdate "$3" -enddate "$4" -in /tmp/$1.csr -out /etc/nginx/tls/$1.crt 2>/dev/null
  cp /tmp/$1.csr $CA/$1.csr; rm -f /tmp/$1.csr
}
INI=$(date -u -d '-20 days' +%Y%m%d%H%M%SZ)
FIN=$(date -u -d '+70 days' +%Y%m%d%H%M%SZ)
firmar banco banco.lab "$INI" "$FIN"
firmar caducado caducado.lab 20250101000000Z 20250401000000Z
firmar intranet intranet.lab "$INI" "$FIN"
firmar phishing banco-seguro-login.lab "$(date -u -d '-1 day' +%Y%m%d%H%M%SZ)" "$FIN"
openssl req -x509 -newkey rsa:2048 -nodes -days 365 -keyout /etc/nginx/tls/autofirmado.key \
  -out /etc/nginx/tls/autofirmado.crt -subj "/CN=autofirmado.lab" -addext "subjectAltName=DNS:autofirmado.lab" 2>/dev/null
chmod 600 /etc/nginx/tls/*.key

srv(){  # srv <server_name> <cert>
cat <<N
server {
    listen 443 ssl;
    server_name $1;
    ssl_certificate     /etc/nginx/tls/$2.crt;
    ssl_certificate_key /etc/nginx/tls/$2.key;
    location / { default_type text/html; return 200 "<h1>$1</h1>\n"; }
}
N
}
{ srv banco.lab banco; srv caducado.lab caducado; srv autofirmado.lab autofirmado
  srv intranet-vieja.lab intranet; srv banco-seguro-login.lab phishing; } > /etc/nginx/sites-available/tls
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/tls /etc/nginx/sites-enabled/tls
echo '127.0.0.1 banco.lab caducado.lab autofirmado.lab intranet-vieja.lab banco-seguro-login.lab' >> /etc/hosts
systemctl enable --now nginx

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/TLS-128.txt <<'TXT'
TLS-128 · proxy-128
Auditoría de los certificados que sirve este proxy. Para cada web anota el
estado del certificado en ~/tls.txt (valido | caducado | autofirmado | nombre_incorrecto):
  banco.lab=  caducado.lab=  autofirmado.lab=  intranet-vieja.lab=  banco-seguro-login.lab=
Además:
  phishing=<web que, aun con candado, NO es del banco>
  emisor_banco=<CN de quien firmó el certificado de banco.lab>
Después renueva el de caducado.lab con la CA interna (/root/ca) para que
vuelva a ser válido.
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 128 plantado."
