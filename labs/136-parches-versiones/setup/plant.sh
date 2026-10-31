#!/usr/bin/env bash
# Lab 136: la web anuncia versiones (PHP y nginx), deja phpinfo() publicado y
# usa una librería PHP con vulnerabilidades conocidas.
set -e
INI=/etc/php/8.2/fpm/php.ini
sed -i 's/^;\?expose_php.*/expose_php = On/' $INI
A=/srv/app
mkdir -p $A/public
cat > $A/public/index.php <<'P'
<?php echo "Hola desde PHP\n";
P
echo '<?php phpinfo();' > $A/public/info.php
cat > $A/composer.json <<'J'
{
    "name": "empresa/contacto",
    "require": {
        "phpmailer/phpmailer": "6.4.0",
        "guzzlehttp/psr7": "1.8.1"
    }
}
J
cat > $A/composer.lock <<'J'
{
    "_readme": ["This file locks the dependencies of your project to a known state"],
    "content-hash": "7c1e5a2b9f0d4e3a8b6c1d2e3f4a5b6c",
    "packages": [
        {
            "name": "guzzlehttp/psr7",
            "version": "1.8.1",
            "source": {"type": "git", "url": "https://github.com/guzzle/psr7.git", "reference": "35ea11d335fd638b5882ff1725228b3d35496ab1"},
            "type": "library"
        },
        {
            "name": "phpmailer/phpmailer",
            "version": "v6.4.0",
            "source": {"type": "git", "url": "https://github.com/PHPMailer/PHPMailer.git", "reference": "050d430203105c27c30efd1dce7aa421ad882d01"},
            "type": "library"
        }
    ],
    "packages-dev": [],
    "aliases": [],
    "minimum-stability": "stable",
    "prefer-stable": false,
    "prefer-lowest": false,
    "platform": [],
    "platform-dev": []
}
J
cat > /etc/nginx/sites-available/app <<'N'
server {
    listen 80 default_server;
    root /srv/app/public;
    index index.php;
    location / { try_files $uri $uri/ =404; }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    }
}
N
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app
sed -i 's/^\(\s*\)#\?\s*server_tokens.*/\1server_tokens on;/' /etc/nginx/nginx.conf
systemctl enable --now php8.2-fpm nginx
systemctl restart php8.2-fpm

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/SEC-136.txt <<'TXT'
SEC-136 · web-136 · gestión de parches
1. Inventario: ~/inventario.txt con
     php=<versión exacta>  nginx=<versión exacta>
     actualizables=<nº de paquetes del sistema con actualización pendiente>
2. Escanea las dependencias de /srv/app con trivy -> ~/trivy-app.json
   y anota cve_critica=<un CVE de severidad CRITICAL que encuentre>.
3. Deja de anunciar versiones (X-Powered-By, Server) y retira info.php.
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 136 plantado."
