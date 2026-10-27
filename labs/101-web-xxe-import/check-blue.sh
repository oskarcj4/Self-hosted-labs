#!/usr/bin/env bash
# BLUE: ¿desactivaste las entidades externas sin romper el import normal?
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
U=http://127.0.0.1:8080/import
post(){ curl -s --data-binary "$1" -H 'Content-Type: application/xml' "$U"; }
real=$(cat /opt/lab/.flag 2>/dev/null)

echo "== Lab 101 · BLUE (arreglo) =="

# 1) Import legítimo sigue funcionando.
post '<user><name>ana</name></user>' | grep -q 'hola ana' \
  && ok "El import normal (<name>ana</name>) sigue devolviendo 'hola ana'." \
  || no "El import normal se rompió."

# 2) XXE de fichero: no se expande, no filtra la flag.
x='<?xml version="1.0"?><!DOCTYPE u [<!ENTITY xxe SYSTEM "file:///srv/app/flag.txt">]><user><name>&xxe;</name></user>'
r=$(post "$x")
[ -n "$real" ] && grep -qF "$real" <<<"$r" \
  && no "La entidad externa todavía lee /srv/app/flag.txt (XXE abierto)." \
  || ok "La entidad externa a fichero ya no se resuelve."

# 3) XXE a /etc/hostname (otra ruta) tampoco.
x2='<?xml version="1.0"?><!DOCTYPE u [<!ENTITY e SYSTEM "file:///etc/hostname">]><user><name>&e;</name></user>'
r2=$(post "$x2")
grep -qiE 'importer-101|[a-f0-9]{12}' <<<"$r2" \
  && no "Todavía se puede leer /etc/hostname por XXE." \
  || ok "No se filtran otros ficheros del host por XXE."

echo "Resultado BLUE: $pass ok, $fail pend."
[ "$fail" -eq 0 ]
