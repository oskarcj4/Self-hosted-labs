#!/usr/bin/env bash
# Solución BLUE: allowlist de host+puerto en el fetcher. (RED se deja al alumno.)
set -e
A=/srv/app
python3 - <<'PY'
import pathlib
p = pathlib.Path("/srv/app/app.py")
s = p.read_text()
vuln = '''def do_fetch(url):
    # --- VULNERABLE: se busca cualquier URL que pida el cliente ---
    req = urllib.request.Request(url, headers={"X-Internal-Auth": AUTH})
    with urllib.request.urlopen(req, timeout=4) as r:
        return r.read().decode(errors="replace")'''
fix = '''ALLOW = {("api.internal", 8090)}

def do_fetch(url):
    p = urlparse(url)
    port = p.port or (443 if p.scheme == "https" else 80)
    if p.scheme not in ("http", "https") or (p.hostname, port) not in ALLOW:
        raise ValueError("destino no permitido: %s" % url)
    req = urllib.request.Request(url, headers={"X-Internal-Auth": AUTH})
    with urllib.request.urlopen(req, timeout=4) as r:
        return r.read().decode(errors="replace")'''
assert vuln in s, "bloque vulnerable no encontrado"
p.write_text(s.replace(vuln, fix))
PY
chown analista:analista "$A/app.py"
touch "$A/reload"; sleep 3
echo "Arreglo aplicado y app recargada."
