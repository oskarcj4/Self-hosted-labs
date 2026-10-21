#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 71. La verdad sale de 'docker inspect' de los contenedores
# en marcha y del compose del proyecto.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
P=/srv/pedidos
bytes(){ # 10m -> 10485760 (k/m/g, mayúsculas o minúsculas)
  awk -v s="$1" 'BEGIN{n=s+0; u=tolower(substr(s,length(s))); m=(u=="k")?1024:(u=="m")?1048576:(u=="g")?1073741824:1; print int(n*m)}'; }

echo "== Lab 71 · Logs de Docker llenan el disco — comprobación =="

use=$(df -P /var/lib/docker | awk 'NR==2 {print $5+0}')
[ "$use" -lt 50 ] && ok "Disco de Docker al ${use}%." || no "El disco de Docker sigue al ${use}% (df -h /var/lib/docker)."

held=$($SUDO lsof -nP +L1 2>/dev/null | grep -c -- '-json.log')
[ "$held" -eq 0 ] && ok "Ningún log borrado sigue ocupando espacio." \
  || no "Hay $held logs borrados que dockerd mantiene abiertos: borrar con rm no libera el espacio."

cfg=$(cd $P && docker compose config --format json 2>/dev/null)
if [ -z "$cfg" ]; then
  no "docker compose config falla en $P."
else
  for s in api worker; do
    ms=$(echo "$cfg" | jq -r ".services.$s.logging.options[\"max-size\"] // empty")
    mf=$(echo "$cfg" | jq -r ".services.$s.logging.options[\"max-file\"] // empty")
    if [ -n "$ms" ] && [ "$(bytes "$ms")" -le 10485760 ] && [ -n "$mf" ] && [ "$mf" -le 3 ] 2>/dev/null; then
      ok "compose.yaml: $s rota sus logs (max-size=$ms, max-file=$mf)."
    else
      no "compose.yaml: $s no tiene logging con max-size ≤ 10m y max-file ≤ 3."
    fi
  done
  lvl=$(echo "$cfg" | jq -r '.services.worker.environment.LOG_LEVEL // empty')
  [ "$lvl" = INFO ] && ok "compose.yaml: el worker vuelve a LOG_LEVEL=INFO." \
    || no "compose.yaml: el worker tiene LOG_LEVEL='${lvl}' (debe ser INFO)."
fi

for s in api worker; do
  c=$(docker ps -q --filter label=com.docker.compose.project=pedidos --filter label=com.docker.compose.service=$s | head -1)
  if [ -z "$c" ]; then no "El servicio $s no está en marcha."; continue; fi
  ms=$(docker inspect -f '{{index .HostConfig.LogConfig.Config "max-size"}}' "$c")
  if [ -n "$ms" ] && [ "$ms" != "<no value>" ] && [ "$(bytes "$ms")" -le 10485760 ]; then
    ok "El contenedor de $s en marcha ya aplica max-size=$ms."
  else
    no "El contenedor de $s en marcha no tiene max-size: la config de logs sólo se aplica al RECREAR el contenedor."
  fi
  if [ $s = worker ]; then
    docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$c" | grep -qx 'LOG_LEVEL=INFO' \
      && ok "El worker en marcha está en INFO." || no "El worker en marcha no está en LOG_LEVEL=INFO."
    sz=$($SUDO stat -c %s "$(docker inspect -f '{{.LogPath}}' "$c")" 2>/dev/null || echo 0)
    [ "$sz" -lt 20971520 ] && ok "El log del worker ocupa $((sz / 1024)) KB." \
      || no "El log del worker ocupa $((sz / 1048576)) MB."
  fi
done

curl -fs --max-time 3 http://127.0.0.1:8000/ | grep -q '"ok"' && ok "La API responde." || no "La API (127.0.0.1:8000) no responde."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Espacio recuperado y logs con rotación."; exit 0; } || exit 1
