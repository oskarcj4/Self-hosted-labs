#!/usr/bin/env bash
# Arranque de old-srv (lab 68): /srv/media con dueños, permisos, hardlinks y
# enlaces simbólicos. 'media' tiene aquí el UID 1500 (en new-srv, el 2001).
set -e
if [ ! -e /opt/.planted ]; then
  useradd -u 1500 -m -s /usr/sbin/nologin media
  useradd -m -s /bin/bash migra
  echo 'migra:Migra-2026' | chpasswd
  echo 'migra ALL=(root) NOPASSWD: /usr/bin/rsync' > /etc/sudoers.d/migra
  chmod 0440 /etc/sudoers.d/migra

  M=/srv/media
  mkdir -p $M/fotos/2026 $M/fotos/destacadas $M/docs/privado $M/releases/v1 $M/releases/v2 $M/releases/v3 $M/web
  for i in $(seq -w 1 30); do
    head -c $((20000 + 10#$i * 513)) /dev/urandom > $M/fotos/2026/img-0$i.jpg
  done
  # Las destacadas son hardlinks: mismo fichero, dos nombres, una sola copia en disco.
  ln $M/fotos/2026/img-007.jpg $M/fotos/destacadas/portada.jpg
  ln $M/fotos/2026/img-012.jpg $M/fotos/destacadas/banner.jpg
  echo "Contrato de cesión de imágenes 2026" > $M/docs/contrato.pdf
  printf 'empleado;bruto\nana;2400\nluis;2650\n' > $M/docs/privado/nominas-2026.csv
  for v in 1 2 3; do echo "release v$v" > $M/releases/v$v/app.txt; done
  ln -s v3 $M/releases/actual
  echo '<h1>Galería</h1>' > $M/web/index.html
  echo 'Options -Indexes' > $M/web/.htaccess
  ln -s ../fotos/destacadas $M/web/destacadas

  chown -R media:media $M
  chown -R www-data:www-data $M/web
  chown -h media:media $M/web/destacadas
  chmod 0755 $M $M/fotos $M/fotos/2026 $M/fotos/destacadas $M/releases $M/releases/v*
  chmod 0750 $M/docs $M/docs/privado
  chmod 0640 $M/docs/contrato.pdf
  chmod 0600 $M/docs/privado/nominas-2026.csv
  find $M/fotos -type f -exec chmod 0644 {} +
  i=0
  for f in $(find $M -type f | sort); do
    i=$((i + 1)); touch -d "@$((1762072200 + i * 3600))" "$f"
  done

  cat > /etc/ssh/sshd_config.d/lab.conf <<'EOF'
PermitRootLogin no
PasswordAuthentication yes
EOF
  touch /opt/.planted
fi

# Agente de estado (sólo lectura) para el validador: manifiesto de /srv/media.
python3 - <<'PY' &
import subprocess
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        out = subprocess.run(["python3", "/opt/node/manifest.py", "/srv/media"],
                             capture_output=True, text=True).stdout if self.path == "/manifest" else "uso: GET /manifest\n"
        b = out.encode()
        self.send_response(200); self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def log_message(self, *a):
        pass
ThreadingHTTPServer(("0.0.0.0", 9100), H).serve_forever()
PY
mkdir -p /run/sshd
exec /usr/sbin/sshd -D -e
