#!/usr/bin/env bash
# Lab 149 (Mr. Robot M8): defacement de fsociety.
# La portada del sitio amaneció pintada por fsociety. El alumno la restaura
# desde el respaldo bueno y monta integridad de ficheros (AIDE + inotify) para
# que un próximo cambio salte al instante.
set -e
export HOME=/root
WEB=/var/www/html

# --- sitio legítimo + respaldo conocido-bueno ---------------------------------
install -d -m 0755 $WEB /opt/backups
cat > /opt/backups/index.html.orig <<'HTML'
<!doctype html>
<title>Allsafe Cybersecurity</title>
<h1>Allsafe Cybersecurity</h1>
<p>Protegemos lo que importa. Portal corporativo.</p>
HTML
cp /opt/backups/index.html.orig $WEB/index.html
chmod 0644 /opt/backups/index.html.orig $WEB/index.html

cat > /etc/nginx/sites-available/web <<'N'
server {
    listen 80 default_server;
    root /var/www/html;
    index index.html;
    location / { try_files $uri $uri/ =404; }
}
N
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/web /etc/nginx/sites-enabled/web
systemctl enable --now nginx

# --- configuración mínima de AIDE sólo para el webroot ------------------------
install -d -m 0755 /etc/aide /var/lib/aide
cat > /etc/aide/aide-www.conf <<'CONF'
database_in=file:/var/lib/aide/aide.db
database_out=file:/var/lib/aide/aide.db.new
report_url=stdout
NORMAL = sha256+p+u+g+s+n+m
/var/www NORMAL
CONF

# --- DEFACEMENT (lo que el alumno encuentra al llegar) ------------------------
cat > $WEB/index.html <<'HTML'
<!doctype html>
<title>Hacked by fsociety</title>
<body style="background:#000;color:#0f0">
<h1>fsociety was here</h1>
<p>Hello, friend. Leave me here.</p>
</body>
HTML
chmod 0644 $WEB/index.html
# Marca de tiempo del defacement (de madrugada).
touch -d "$(date +%Y-%m-%d) 03:07:00" $WEB/index.html

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/IR-149.txt <<'TXT'
IR-149 · allsafe-149 · "la web está pintada"
La portada muestra un mensaje de fsociety. Respaldo bueno:
/opt/backups/index.html.orig

1. Confirma el defacement y restaura la portada desde el respaldo.
2. Inicia una línea base de integridad con AIDE sobre /var/www
   (config lista en /etc/aide/aide-www.conf). Deja la base en
   /var/lib/aide/aide.db y que 'aide --check' salga limpio tras restaurar.
3. Monta vigilancia en tiempo real del webroot: un servicio con inotifywait
   que registre cambios en /var/log/fim.log (servicio fim-www), o un cron que
   corra 'aide --check'. Que quede activo.
4. ~/hallazgos.txt:
     pagina_afectada=/var/www/html/index.html
     firma_defacement=fsociety
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 149 plantado."
