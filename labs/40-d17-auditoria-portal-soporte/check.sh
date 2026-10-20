#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 40 (Día 17). La verdad sale de `docker inspect`.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
F=/home/analista/audit/support-portal.txt
C=support-portal

echo "== Lab 40 · Día 17 — comprobación =="

norm(){ tr 'A-Z' 'a-z' | tr -d ' \r"' ; }
val(){ grep -iE "^$1=" "$F" 2>/dev/null | tail -1 | cut -d= -f2- | norm; }
nlist(){ tr ',' '\n' | grep -v '^$' | sort -u | paste -sd, -; }

if [ "$(docker inspect -f '{{.Id}}' $C 2>/dev/null)" = "$($SUDO cat /root/.tclab-portal.id 2>/dev/null)" ] \
   && [ "$(docker inspect -f '{{.State.Running}}' $C)" = "true" ]; then
  ok "El contenedor original sigue corriendo (auditar no es recrear)."
else
  no "El contenedor support-portal ya no es el original o está parado. Pulsa Reiniciar."
fi

[ -s "$F" ] || { no "No existe $F."; echo "Resultado: $pass superados, $fail pendientes."; exit 1; }
ok "Existe el informe $F."

img=$(docker inspect -f '{{.Config.Image}}' $C | norm)
[ "$(val imagen)" = "$img" ] && ok "imagen correcta ($img)." || no "imagen no coincide con la del contenedor."

hp=$(docker inspect -f '{{range $p,$b := .NetworkSettings.Ports}}{{range $b}}{{.HostPort}}{{"\n"}}{{end}}{{end}}' $C | grep . | head -1)
cp=$(docker inspect -f '{{range $p,$b := .NetworkSettings.Ports}}{{if $b}}{{$p}}{{end}}{{end}}' $C | cut -d/ -f1)
if [ "$(val puerto_host)" = "$hp" ] && [ "$(val puerto_contenedor | cut -d/ -f1)" = "$cp" ]; then
  ok "Puertos correctos (host $hp -> contenedor $cp)."
else
  no "puerto_host / puerto_contenedor no coinciden con la publicación real."
fi

src=$(docker inspect -f '{{range .Mounts}}{{.Source}}{{end}}' $C)
dst=$(docker inspect -f '{{range .Mounts}}{{.Destination}}{{end}}' $C)
rw=$(docker inspect -f '{{range .Mounts}}{{if .RW}}rw{{else}}ro{{end}}{{end}}' $C)
if [ "$(val montaje_origen | sed 's#/$##')" = "$src" ] && [ "$(val montaje_destino | sed 's#/$##')" = "$dst" ] \
   && [ "$(val montaje_modo)" = "$rw" ]; then
  ok "Montaje correcto ($src -> $dst, $rw)."
else
  no "montaje_origen / montaje_destino / montaje_modo no coinciden con el montaje real."
fi

u=$(docker inspect -f '{{.Config.User}}' $C); [ -z "$u" ] && u=root
uv=$(val usuario)
if [ "$uv" = "$u" ] || { [ "$u" = "root" ] && [ "$uv" = "0" ]; }; then
  ok "usuario correcto ($u)."
else
  no "usuario no coincide con el usuario efectivo del contenedor."
fi

sec=$(echo "SUPPORT_SMTP_PASSWORD,ZENDESK_API_TOKEN" | norm | nlist)
if [ "$(val secretos_env | nlist)" = "$sec" ]; then
  ok "Variables con secretos identificadas (las de 'docker run -e' y las horneadas en la imagen)."
else
  no "secretos_env no recoge exactamente las variables que contienen credenciales."
fi

if grep -qF 'smtp-Supp0rt-2026' "$F" || grep -qF 'zd_8Hq2LmX4' "$F"; then
  no "El informe contiene el VALOR de un secreto: anota sólo el nombre de la variable."
else
  ok "El informe no copia valores de secretos."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Contenedor auditado desde el runtime. ¡Día 17 resuelto!"; exit 0; } || exit 1
