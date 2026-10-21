#!/usr/bin/env bash
# Arranque de dns-01 / pagos-01 (lab 61). ROLE=dns|api.
if [ "$ROLE" = dns ]; then
  cat > /etc/dnsmasq.d/interno.conf <<'EOF'
# Zona interna. Este servidor sólo responde por "interno" (no hay salida a internet).
no-resolv
no-hosts
domain-needed
local=/interno/
host-record=dns-01.interno,10.76.61.53
host-record=pagos.interno,10.76.61.30
host-record=app-03.interno,10.76.61.10
log-queries
log-facility=-
EOF
  exec dnsmasq -k --conf-dir=/etc/dnsmasq.d,*.conf
fi
exec python3 - <<'PY'
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        body = b"pagos-api ok\n"
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a):
        pass
ThreadingHTTPServer(("0.0.0.0", 8080), H).serve_forever()
PY
