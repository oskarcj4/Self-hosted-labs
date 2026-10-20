#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 24 (Día 01). Compara tu inventario con el estado REAL de
# los sockets (ss), no con la documentación.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
F=/home/analista/audit/listeners.csv
SS="ss"; [ "$(id -u)" -eq 0 ] || SS="sudo -n ss"

echo "== Lab 24 · Día 01 — comprobación =="

# Verdad de referencia: puertos TCP en escucha (sin la terminal del lab, 7681).
# Un puerto es "publico" si algún socket suyo escucha fuera de loopback.
TRUTH=$($SS -H -tlnp 2>/dev/null | awk '
  { addr=$4; port=addr; sub(/.*:/,"",port); host=addr; sub(/:[0-9]+$/,"",host)
    proc=$0; sub(/.*users:\(\("/,"",proc); sub(/".*/,"",proc)
    if (port=="7681" || host=="127.0.0.11") next
    ex = (host ~ /^127\./ || host=="[::1]") ? "local" : "publico"
    if (!(port in e) || ex=="publico") e[port]=ex
    p[port]=proc }
  END { for (k in e) print k "," e[k] "," p[k] }' | sort -n)

missing=""
for port in 22 80 6379 8081 8873 9100; do
  echo "$TRUTH" | grep -q "^$port," || missing="$missing $port"
done
if [ -z "$missing" ]; then
  ok "Los servicios del host siguen en marcha (una auditoría no cambia el sistema)."
else
  no "Faltan servicios que estaban escuchando:$missing. No pares nada: sólo audita (o pulsa Reiniciar)."
fi

if [ ! -s "$F" ]; then
  no "No existe $F (o está vacío)."
else
  ok "Existe el inventario $F."
  # normaliza: minúsculas, sin espacios ni CR, 'público' -> 'publico', sin cabecera
  BODY=$(tr 'A-Z' 'a-z' < "$F" | tr -d ' \r' | sed 's/ú/u/g' | grep -E '^[0-9]+,')
  bad=0
  while IFS=, read -r port exp proc; do
    [ -n "$port" ] || continue
    line=$(echo "$BODY" | grep -m1 "^$port,")
    if [ -z "$line" ]; then
      no "Falta el puerto $port en el inventario."; bad=1; continue
    fi
    uexp=$(echo "$line" | cut -d, -f2); uproc=$(echo "$line" | cut -d, -f3)
    if [ "$uexp" != "$exp" ]; then
      no "Puerto $port: lo marcaste '$uexp' pero en tiempo de ejecución es '$exp'."; bad=1
    fi
    if [ -z "$uproc" ] || { [[ "$proc" != *"$uproc"* ]] && [[ "$uproc" != *"$proc"* ]]; }; then
      no "Puerto $port: el proceso no coincide con el que tiene el socket."; bad=1
    fi
  done <<< "$TRUTH"
  extra=""
  for port in $(echo "$BODY" | cut -d, -f1); do
    echo "$TRUTH" | grep -q "^$port," || extra="$extra $port"
  done
  if [ -n "$extra" ]; then
    no "Listaste puertos que no están en escucha:$extra."; bad=1
  fi
  [ "$bad" -eq 0 ] && ok "Inventario correcto: cada listener con su exposición y proceso reales."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Exposición real auditada. ¡Día 01 resuelto!"; exit 0; } || exit 1
