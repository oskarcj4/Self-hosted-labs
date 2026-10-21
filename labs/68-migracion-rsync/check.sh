#!/usr/bin/env bash
# Validador del Lab 68. Compara el manifiesto de /srv/media en old-srv (lo da
# su agente de estado) con el de /srv/media aquí: contenido, permisos, dueños
# por nombre, mtimes, enlaces y hardlinks.
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap 'rc=$?; rm -rf "$T"; [ $rc -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
M=/srv/media
T=$(mktemp -d)

echo "== Lab 68 · Migración con rsync — comprobación =="

if ! curl -fs --max-time 10 http://old-srv:9100/manifest > "$T/src" || [ ! -s "$T/src" ]; then
  no "No se pudo leer el manifiesto de old-srv."
  echo "Resultado: $pass superados, $fail pendientes."; exit 1
fi
python3 /usr/local/lib/tclab-manifest.py $M > "$T/dst"
if [ ! -s "$T/dst" ]; then
  no "No se pudo generar el manifiesto local de /srv/media."
  echo "Resultado: $pass superados, $fail pendientes."; exit 1
fi
cut -f1 "$T/src" | sort > "$T/src.p"; cut -f1 "$T/dst" | sort > "$T/dst.p"

[ -d $M/media ] && no "Existe /srv/media/media: la barra final del origen importa (old-srv:/srv/media/ vs /srv/media)." \
  || ok "Sin anidamiento /srv/media/media."

miss=$(comm -23 "$T/src.p" "$T/dst.p"); extra=$(comm -13 "$T/src.p" "$T/dst.p")
[ -z "$miss" ] && ok "Están las $(wc -l < "$T/src.p") entradas del origen." \
  || no "Faltan $(echo "$miss" | wc -l) entradas, p.ej.: $(echo "$miss" | head -3 | tr '\n' ' ')"
[ -z "$extra" ] && ok "No sobra nada en el destino (restos del intento anterior borrados)." \
  || no "Sobran $(echo "$extra" | wc -l) entradas, p.ej.: $(echo "$extra" | head -3 | tr '\n' ' ')"

python3 - "$T/src" "$T/dst" > "$T/why" <<'PY'
import sys
def load(p):
    d = {}
    for line in open(p):
        f = line.rstrip("\n").split("\t")
        d[f[0]] = f[1:]
    return d
s, t = load(sys.argv[1]), load(sys.argv[2])
for k in sorted(set(s) & set(t)):
    a, b = s[k], t[k]
    if a == b:
        continue
    if a[0] != b[0]:
        why = "tipo"
    elif a[0] == "l":
        why = "enlace"
    elif a[1] != b[1]:
        why = "permisos"
    elif a[2] != b[2]:
        why = "dueño"
    elif a[0] == "f" and a[5] != b[5]:
        why = "contenido"
    elif a[0] == "f" and a[4] != b[4]:
        why = "mtime"
    elif a[0] == "f" and a[6] != b[6]:
        why = "hardlink"
    else:
        why = "otro"
    print(f"{why}\t{k}\t{'/'.join(a)}\t{'/'.join(b)}")
PY
show(){ awk -F'\t' -v w="$1" '$1==w {print $2; n++} n==3 {exit}' "$T/why" | tr '\n' ' '; }
cnt(){ awk -F'\t' -v w="$1" '$1==w' "$T/why" | wc -l; }

[ "$(cnt contenido)" -eq 0 ] && ok "El contenido de los ficheros coincide (sha256)." \
  || no "$(cnt contenido) ficheros con contenido distinto: $(show contenido)"
[ "$(cnt permisos)" -eq 0 ] && ok "Los permisos coinciden." \
  || no "$(cnt permisos) entradas con permisos distintos: $(show permisos)"
if [ "$(cnt dueño)" -eq 0 ]; then
  ok "Dueños y grupos coinciden por nombre (media = UID $(id -u media) aquí)."
else
  ex=$(awk -F'\t' '$1=="dueño" {split($4,a,"/"); print a[3]; exit}' "$T/why")
  no "$(cnt dueño) entradas con otro dueño (aquí: $ex): $(show dueño). ¿--numeric-ids o rsync sin root?"
fi
[ "$(cnt mtime)" -eq 0 ] && ok "Las fechas de modificación se conservan." \
  || no "$(cnt mtime) ficheros con otra mtime: $(show mtime)"
[ "$(cnt tipo)$(cnt enlace)" = 00 ] && ok "Los enlaces simbólicos se copiaron como enlaces, con el mismo destino." \
  || no "Enlaces convertidos o cambiados: $(show tipo) $(show enlace)"
if [ "$(stat -c %i $M/fotos/destacadas/portada.jpg 2>/dev/null)" = "$(stat -c %i $M/fotos/2026/img-007.jpg 2>/dev/null)" ] \
   && [ "$(stat -c %i $M/fotos/destacadas/banner.jpg 2>/dev/null)" = "$(stat -c %i $M/fotos/2026/img-012.jpg 2>/dev/null)" ] \
   && [ "$(cnt hardlink)" -eq 0 ]; then
  ok "Los hardlinks siguen siendo hardlinks (mismo inodo, sin duplicar)."
else
  no "fotos/destacadas/*.jpg ya no comparten inodo con su original: falta -H."
fi
[ "$(cnt otro)" -eq 0 ] || no "Otras diferencias: $(show otro)"

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 /srv/media es idéntico al origen: old-srv ya se puede apagar."; exit 0; } || exit 1
