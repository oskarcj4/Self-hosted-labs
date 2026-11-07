#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
A=/home/analista/app
cd $A || exit 1
dc(){ docker compose "$@"; }

echo "== Lab 181 · Apagado limpio — comprobación =="

if grep -qE '^\s*(CMD|ENTRYPOINT)\s*\[' Dockerfile && ! grep -qE '^\s*(CMD|ENTRYPOINT)\s+[^[ ]' Dockerfile; then
  ok "Dockerfile: CMD/ENTRYPOINT en forma exec."
else
  no "Dockerfile: usa la forma exec, p. ej. CMD [\"python\", \"app.py\"] (la forma shell mete /bin/sh como PID 1)."
fi

echo "  ... construyendo y arrancando"
dc down -t 1 >/dev/null 2>&1
if ! dc up -d --build >/tmp/c181.log 2>&1; then
  no "docker compose up falla: $(tail -1 /tmp/c181.log)"
else
  for _ in $(seq 1 30); do curl -s -o /dev/null --max-time 1 localhost:8000/ && break; sleep 0.5; done
  C=$(dc ps -q app)

  for _ in $(seq 1 20); do curl -s -o /dev/null --max-time 3 localhost:8000/tarea; done
  sleep 1.5
  Z=$(docker top "$C" -o pid,stat,comm 2>/dev/null | awk 'NR>1 && $2 ~ /^Z/' | wc -l)
  if [ "$Z" -eq 0 ]; then
    ok "Sin procesos zombis tras 20 tareas en segundo plano."
  else
    no "$Z procesos zombis (<defunct>) en el contenedor: PID 1 no recoge huérfanos."
  fi

  rm -f /tmp/c181.resp
  ( curl -s -o /tmp/c181.resp -w '%{http_code}' --max-time 15 localhost:8000/lento > /tmp/c181.code ) &
  sleep 0.5
  T0=$(date +%s.%N); dc stop >/dev/null 2>&1; T1=$(date +%s.%N)
  wait
  DT=$(python3 -c "print(round($T1 - $T0, 1))")
  EC=$(docker inspect -f '{{.State.ExitCode}}' "$C")
  if python3 -c "import sys; sys.exit(0 if $DT < 5 else 1)" && [ "$EC" = 0 ]; then
    ok "docker compose stop en ${DT} s y código de salida 0."
  else
    no "docker compose stop tardó ${DT} s y el contenedor salió con código $EC (137 = SIGKILL)."
  fi
  if [ "$(cat /tmp/c181.code 2>/dev/null)" = 200 ] && grep -q 'informe listo' /tmp/c181.resp 2>/dev/null; then
    ok "La petición en curso durante la parada terminó con 200."
  else
    no "La petición en curso durante la parada se cortó (código $(cat /tmp/c181.code 2>/dev/null))."
  fi
  if docker logs "$C" 2>&1 | tail -5 | grep -qi 'apagado limpio'; then
    ok "La app registra 'apagado limpio' al salir."
  else
    no "No aparece 'apagado limpio' al final del log de la app."
  fi
  dc up -d >/dev/null 2>&1
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Despliegues sin cortar a nadie."; exit 0; } || exit 1
