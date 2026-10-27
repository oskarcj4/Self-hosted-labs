#!/usr/bin/env bash
# Solución BLUE: parser sin DTD ni entidades externas. (RED se deja al alumno.)
set -e
A=/srv/app
python3 - <<'PY'
import pathlib
p = pathlib.Path("/srv/app/app.py")
s = p.read_text()
vuln = '''def parse_profile(xml_bytes):
    # --- VULNERABLE: carga DTD y resuelve entidades externas ---
    parser = etree.XMLParser(resolve_entities=True, load_dtd=True, no_network=False)
    root = etree.fromstring(xml_bytes, parser)
    return root.findtext("name")'''
fix = '''def parse_profile(xml_bytes):
    # sin DTD, sin entidades, sin red: no hay XXE posible
    parser = etree.XMLParser(resolve_entities=False, load_dtd=False,
                             no_network=True)
    root = etree.fromstring(xml_bytes, parser)
    return root.findtext("name")'''
assert vuln in s, "bloque vulnerable no encontrado"
p.write_text(s.replace(vuln, fix))
PY
chown analista:analista "$A/app.py"
touch "$A/reload"; sleep 3
echo "Arreglo aplicado y app recargada."
