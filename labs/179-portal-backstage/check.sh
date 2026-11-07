#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
R=/home/analista/plataforma/catalogo
api(){ curl -s --max-time 5 "http://127.0.0.1:7007/api/$1"; }
j(){ python3 -c "import json,sys; d=json.load(sys.stdin); print($1)" 2>/dev/null; }

echo "== Lab 179 · Portal interno (catálogo) — comprobación =="

OUT=$(runuser -u analista -- catalogo validar $R 2>&1); rc=$?
if [ $rc = 0 ]; then
  ok "catalogo validar: $(echo "$OUT" | tail -1)."
else
  no "catalogo validar: $(echo "$OUT" | tail -1). Primero: $(echo "$OUT" | head -1)"
fi

E=$(api entities/component/envios); P=$(api entities/component/pagos); A=$(api entities/api/pagos-api)
DB=$(api entities/resource/postgres-pagos); G=$(api entities/group/equipo-logistica)
if [ "$(echo "$G" | j "d['spec'].get('parent')")" = ingenieria ] \
   && [ "$(echo "$E" | j "d['relaciones']['owner'][0]")" = "group:default/equipo-logistica" ] \
   && [ "$(echo "$A" | j "d['spec']['type'] + ' ' + str('\$text' in d['spec']['definition'])")" = "openapi True" ] \
   && [ "$(echo "$A" | j "d['spec']['owner']")" = equipo-pagos ] \
   && [ "$(echo "$DB" | j "d['spec']['type'] + ' ' + d['spec']['owner']")" = "database equipo-pagos" ]; then
  ok "Referencias arregladas: equipo-logistica, API pagos-api (openapi desde fichero) y Resource postgres-pagos."
else
  no "Faltan o están mal: Group equipo-logistica (parent ingenieria), API pagos-api (openapi, \$text, equipo-pagos) o Resource postgres-pagos (database)."
fi

CF=$(api entities | j "[e['ref'] for e in d if e['fichero']=='servicios/catalogo/catalog-info.yaml'][0]")
if [[ "$CF" == component:* ]]; then
  ok "El componente del catálogo de productos tiene apiVersion y nombre válidos."
else
  no "El componente 'Catalogo de productos' sigue sin cargarse (apiVersion y metadata.name)."
fi

N=$(api entities/component/notificaciones)
if [ "$(echo "$N" | j "' '.join([d['spec']['owner'], d['spec']['system'], d['spec']['lifecycle'], d['spec']['type']])")" = "plataforma tienda production service" ] \
   && [ "$(echo "$N" | j "d['relaciones']['dependsOn'][0]")" = "component:default/envios" ] \
   && [ "$(echo "$N" | j "d['metadata']['annotations']['backstage.io/techdocs-ref']")" != "" ] \
   && [ -s $R/servicios/notificaciones/docs/index.md ] \
   && [ "$(echo "$E" | j "[x['desde'] for x in d['referenciadoPor'] if x['campo']=='dependsOn'][0]")" = "component:default/notificaciones" ]; then
  ok "notificaciones en el portal: plataforma, tienda, production, depende de envios y con TechDocs."
else
  no "notificaciones: Component con owner plataforma, system tienda, lifecycle production, type service, dependsOn component:envios y techdocs-ref (con docs/index.md)."
fi

if [ -z "$(git -C $R status --porcelain)" ] && [ "$(git -C $R rev-list --count HEAD)" -ge 2 ]; then
  ok "Cambios del catálogo con commit en git."
else
  no "Haz commit de los cambios en ~/plataforma/catalogo (git status debe quedar limpio)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Un catálogo del que la gente se puede fiar."; exit 0; } || exit 1
