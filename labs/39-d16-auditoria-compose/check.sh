#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 39 (Día 16). La verdad sale de `docker inspect` del stack
# en ejecución, no de compose.yaml ni del README.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
F=/home/analista/audit/handoff.txt
PROJ=handoff

echo "== Lab 39 · Día 16 — comprobación =="

cid(){ docker ps -q --filter "label=com.docker.compose.project=$PROJ" \
         --filter "label=com.docker.compose.service=$1" | head -1; }
# lista ordenada y separada por comas, sin el prefijo "handoff_"
norm(){ tr 'A-Z' 'a-z' | tr -d ' \r' | tr ',' '\n' | sed "s/^${PROJ}[_-]//" | grep -v '^$' | sort -u | paste -sd, -; }
val(){ grep -iE "^$1=" "$F" 2>/dev/null | tail -1 | cut -d= -f2- | norm; }

running=1
for s in web api worker db; do [ -n "$(cid $s)" ] || running=0; done
if [ "$running" -eq 1 ] && docker port "$(cid web)" 8080/tcp 2>/dev/null | grep -q ':8443$'; then
  ok "El stack sigue tal como lo encontraste (auditar no es modificar)."
else
  no "El stack cambió (faltan servicios o 'web' ya no publica 8443). Pulsa Reiniciar: una auditoría no toca nada."
fi

if [ ! -s "$F" ]; then
  no "No existe $F."
  echo "Resultado: $pass superados, $fail pendientes."; exit 1
fi
ok "Existe el informe $F."

# --- Entrada publicada
truth_svc=""; truth_port=""
for s in web api worker db; do
  c=$(cid "$s"); [ -n "$c" ] || continue
  hp=$(docker inspect -f '{{range $p, $b := .NetworkSettings.Ports}}{{range $b}}{{.HostPort}} {{end}}{{end}}' "$c" | awk '{print $1}')
  [ -n "$hp" ] && { truth_svc=$s; truth_port=$hp; }
done
if [ "$(val entrypoint_servicio)" = "$truth_svc" ] && [ "$(val entrypoint_puerto)" = "$truth_port" ]; then
  ok "Entrada publicada correcta ($truth_svc en el puerto $truth_port del host)."
else
  no "entrypoint_servicio / entrypoint_puerto no coinciden con lo que publica el stack en ejecución."
fi

# --- Redes de cada servicio
bad=0
for s in web api worker db; do
  c=$(cid "$s"); [ -n "$c" ] || { bad=1; continue; }
  t=$(docker inspect -f '{{range $k, $v := .NetworkSettings.Networks}}{{$k}},{{end}}' "$c" | norm)
  [ "$(val "redes_$s")" = "$t" ] || { bad=1; no "redes_$s no coincide con las redes reales del contenedor."; }
done
[ "$bad" -eq 0 ] && ok "Redes de cada servicio correctas."

# --- Volumen compartido
vols=""
for s in web api worker db; do
  c=$(cid "$s"); [ -n "$c" ] || continue
  for v in $(docker inspect -f '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}} {{end}}{{end}}' "$c"); do
    vols="$vols $v:$s"
  done
done
shared=$(echo "$vols" | tr ' ' '\n' | grep . | cut -d: -f1 | sort | uniq -d | head -1)
users=$(echo "$vols" | tr ' ' '\n' | grep "^$shared:" | cut -d: -f2 | paste -sd, - | norm)
if [ -n "$shared" ] && [ "$(val volumen_compartido)" = "$(echo "$shared" | norm)" ] \
   && [ "$(val volumen_montado_en)" = "$users" ]; then
  ok "Volumen compartido y servicios que lo montan correctos."
else
  no "volumen_compartido / volumen_montado_en no coinciden con los montajes reales."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Línea base del stack registrada. ¡Día 16 resuelto!"; exit 0; } || exit 1
