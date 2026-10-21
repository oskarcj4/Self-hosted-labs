#!/usr/bin/env bash
# Validador del Lab 77. Ejecuta tu instalador contra el mirror real y contra
# dos mirrors locales manipulados, y comprueba que sólo acepta lo auténtico.
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
BIN=/usr/local/bin/kvtool
INS=/usr/local/bin/install-tool.sh
LEGIT=$(cat /var/lib/tclab/legit-1.4.1.sha 2>/dev/null)
sha(){ sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }
end(){ echo "---------------------------------------"; echo "Resultado: $pass superados, $fail pendientes."; }

echo "== Lab 77 · Verificar paquetes — comprobación =="

# El instalador tiene que existir antes de nada: las pruebas lo usan.
if [ ! -x "$INS" ]; then
  no "Falta el instalador $INS (ejecutable)."
  end; exit 1
fi

# Monta un mirror local a partir del real, para poder manipularlo.
M=$(mktemp -d); curl -fs http://artifacts.interno/kvtool/KEYS.asc > "$M/KEYS.asc"
for v in 1.4.1 1.4.2; do
  mkdir -p "$M/$v"
  for f in kvtool-$v-linux-amd64.tar.gz SHA256SUMS SHA256SUMS.asc; do
    curl -fs "http://artifacts.interno/kvtool/$v/$f" > "$M/$v/$f"
  done
done
run_ins(){ ARTIFACTS_URL="$1" "$INS" "$2" >/tmp/ins.out 2>&1; }

# 1) Versión auténtica contra el mirror real: debe instalar el 1.4.1 bueno.
if run_ins http://artifacts.interno/kvtool 1.4.1 && [ "$(sha $BIN)" = "$LEGIT" ]; then
  ok "El instalador coloca el kvtool 1.4.1 auténtico."
else
  no "install-tool.sh 1.4.1 no deja el binario auténtico en $BIN ($(tail -1 /tmp/ins.out))."
fi

# 2) El 1.4.2 del mirror real (firmado por el atacante): debe rechazarse.
before=$(sha $BIN)
if run_ins http://artifacts.interno/kvtool 1.4.2; then
  no "install-tool.sh 1.4.2 instaló algo: la firma es de OTRA clave, no la del fabricante."
elif [ "$(sha $BIN)" != "$before" ]; then
  no "El 1.4.2 falló pero cambió $BIN: no debe tocar lo instalado si la verificación falla."
else
  ok "Rechaza el 1.4.2 (firmado con una clave distinta a la del fabricante)."
fi

# 3) Mirror con el tar.gz manipulado pero la firma buena del fabricante (1.4.1):
#    la firma valida, pero el SHA-256 no cuadra -> rechazar.
printf 'x' >> "$M/1.4.1/kvtool-1.4.1-linux-amd64.tar.gz"
before=$(sha $BIN)
if run_ins "file://$M" 1.4.1; then
  no "Aceptó un tar.gz que no cuadra con su SHA256SUMS (aunque la firma del fichero fuera válida)."
elif [ "$(sha $BIN)" != "$before" ]; then
  no "El hash no cuadraba pero cambió $BIN."
else
  ok "Rechaza el tar.gz cuyo SHA-256 no coincide con SHA256SUMS."
fi

# 4) Estado final: lo instalado es el 1.4.1 auténtico, no el 1.4.2 con marcador.
if [ "$(sha $BIN)" = "$LEGIT" ]; then
  ok "$BIN es el kvtool 1.4.1 auténtico."
elif grep -q 'TAMPERED-BUILD' "$BIN" 2>/dev/null; then
  no "$BIN es el 1.4.2 manipulado del mirror. Reinstala el 1.4.1 auténtico."
else
  no "$BIN no es el kvtool 1.4.1 auténtico ($($BIN --version 2>/dev/null || echo 'no existe'))."
fi
rm -rf "$M"

end
[ "$fail" -eq 0 ] && { echo "🎉 Sólo instalas lo que firma el fabricante. Así se para un ataque de cadena de suministro."; exit 0; } || exit 1
