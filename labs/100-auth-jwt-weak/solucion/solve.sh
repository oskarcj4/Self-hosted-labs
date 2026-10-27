#!/usr/bin/env bash
# Solución BLUE: exigir HS256 y firma válida. (RED se deja al alumno.)
set -e
A=/srv/app
python3 - <<'PY'
import pathlib
p = pathlib.Path("/srv/app/app.py")
s = p.read_text()
vuln = '''    alg = header.get("alg")
    # --- VULNERABLE: si el token dice "none", se acepta sin firma ---
    if alg == "none":
        return payload
    expected = b64u(hmac.new(SECRET, (h_b + "." + p_b).encode(), hashlib.sha256).digest()).decode()
    if hmac.compare_digest(expected, s_b):
        return payload
    return None'''
fix = '''    # el servidor fija el algoritmo; nunca se fia del "alg" del token
    if header.get("alg") != "HS256":
        return None
    expected = b64u(hmac.new(SECRET, (h_b + "." + p_b).encode(), hashlib.sha256).digest()).decode()
    if hmac.compare_digest(expected, s_b):
        return payload
    return None'''
assert vuln in s, "bloque vulnerable no encontrado"
p.write_text(s.replace(vuln, fix))
PY
chown analista:analista "$A/app.py"
touch "$A/reload"; sleep 3
echo "Arreglo aplicado y app recargada."
