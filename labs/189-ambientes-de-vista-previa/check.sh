#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
R=/home/analista/tienda
como(){ su - analista -c "$*" > /tmp/c189.out 2>&1; }
get(){ curl -s --max-time 3 "http://127.0.0.1:$((9000+$1))$2"; }
version(){ get "$1" / | python3 -c 'import json,sys;print(json.load(sys.stdin)["version"])' 2>/dev/null; }
espera(){ for _ in $(seq 1 20); do [ -n "$(version "$1")" ] && return 0; sleep 0.5; done; return 1; }
restos(){ # cuenta contenedores, volúmenes y redes del proyecto pr-N
  local f="label=com.docker.compose.project=pr-$1"
  echo $(( $(docker ps -aq --filter "$f" | wc -l) + $(docker volume ls -q --filter "$f" | wc -l) + $(docker network ls -q --filter "$f" | wc -l) ))
}

echo "== Lab 189 · Vistas previas por PR — comprobación =="

RAMA0=$(git -C $R rev-parse --abbrev-ref HEAD); ESTADO0=$(git -C $R status --porcelain | md5sum)
como preview up 11; como preview up 12
espera 11; espera 12
V11=$(version 11); V12=$(version 12)
if [ "$V11" = pr-11 ] && [ "$V12" = pr-12 ]; then
  ok "PR 11 en :9011 y PR 12 en :9012, cada uno con su rama, a la vez."
else
  no "Esperaba pr-11 en :9011 y pr-12 en :9012; responden '${V11:-nada}' y '${V12:-nada}' ($(tail -1 /tmp/c189.out))."
fi
if [ -n "$(docker ps -q --filter label=com.docker.compose.project=pr-11)" ] \
   && [ -n "$(docker ps -q --filter label=com.docker.compose.project=pr-12)" ]; then
  ok "Proyectos de Compose separados: pr-11 y pr-12."
else
  no "No encuentro contenedores de los proyectos pr-11 y pr-12 (docker compose -p pr-N)."
fi
if [ "$(git -C $R rev-parse --abbrev-ref HEAD)" = "$RAMA0" ] && [ "$(git -C $R status --porcelain | md5sum)" = "$ESTADO0" ]; then
  ok "La copia de trabajo de ~/tienda no se toca (misma rama, mismos ficheros)."
else
  no "preview cambia la rama o los ficheros de ~/tienda."
fi

C11=$(get 11 /clientes)
if echo "$C11" | grep -q 'demo1@ejemplo.test' && ! echo "$C11" | grep -q 'cliente-real'; then
  ok "Las vistas previas usan los datos ficticios de datos/semilla.sql, no los de producción."
else
  no "Datos de la vista previa: ${C11:-nada} (deben ser los de semilla.sql, sin datos de producción)."
fi
M="aislado$RANDOM@ejemplo.test"
curl -s -X POST "http://127.0.0.1:9011/clientes?email=$M" >/dev/null
if get 11 /clientes | grep -q "$M" && ! get 12 /clientes | grep -q "$M"; then
  ok "Cada vista previa tiene su propia base de datos."
else
  no "Un alta en el PR 11 aparece en el PR 12 (o no se guarda): comparten datos."
fi

# Actualizar: nuevo commit en la rama pr-12 y volver a lanzar
su - analista -c "cd /tmp && rm -rf c189 && git clone -q $R c189 && cd c189 && git checkout -q pr-12 && echo pr-12-v2 > VERSION && git commit -qam v2 && git push -q origin pr-12" >/dev/null 2>&1
como preview up 12; espera 12
V=$(version 12)
[ "$V" = pr-12-v2 ] && ok "Volver a lanzar 'preview up 12' actualiza con lo último de la rama." \
                   || no "Tras un commit nuevo en pr-12, 'preview up 12' sigue sirviendo '${V:-nada}'."
rm -rf /tmp/c189

como preview down 11; sleep 1
if [ "$(restos 11)" = 0 ] && ! docker image inspect tienda:pr-11 >/dev/null 2>&1; then
  ok "'preview down 11' borra contenedores, red, volumen e imagen."
else
  no "Tras 'preview down 11' quedan $(restos 11) contenedores/volúmenes/redes o la imagen tienda:pr-11."
fi
[ "$(version 12)" = pr-12-v2 ] && ok "El PR 12 sigue en pie tras quitar el 11." || no "Quitar el PR 11 se ha llevado también el 12."

como preview up 13; espera 13
cp /srv/prs-abiertos.txt /tmp/c189.prs; echo 12 > /srv/prs-abiertos.txt
como preview gc; sleep 1
if [ "$(restos 13)" = 0 ] && [ "$(version 12)" = pr-12-v2 ]; then
  ok "'preview gc' quita la del PR 13 (cerrado) y deja la del 12 (abierto)."
else
  no "'preview gc': PR 13 cerrado deja $(restos 13) recursos; PR 12 responde '$(version 12)'."
fi
cp /tmp/c189.prs /srv/prs-abiertos.txt
como preview down 12; como preview down 13
if [ "$(restos 12)" = 0 ] && [ -z "$(docker volume ls -q | grep -E '^tienda_datos$')" ]; then
  ok "Sin restos: ni proyectos pr-*, ni el volumen tienda_datos con datos de producción."
else
  no "Quedan restos: $(restos 12) del PR 12 o el volumen tienda_datos (con la copia de producción: bórralo)."
fi
git -C $R branch -f pr-12 pr-12~1 2>/dev/null; chown -R analista:analista $R

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Una vista previa por PR, aislada, desechable y sin datos reales."; exit 0; } || exit 1
