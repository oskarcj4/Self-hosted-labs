#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 136.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
H=/home/analista
val(){ grep -E "^$1=" $H/inventario.txt 2>/dev/null | head -1 | cut -d= -f2- | tr -d ' \r'; }

echo "== Lab 136 · Parches y versiones — comprobación =="
[ "$(val php)" = "$(php -r 'echo PHP_VERSION;')" ] && ok "Versión de PHP correcta." || no "inventario.txt: php= no es la versión exacta instalada."
[ "$(val nginx)" = "$(nginx -v 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')" ] && ok "Versión de nginx correcta." || no "inventario.txt: nginx= no es la versión exacta instalada."
if ls /var/lib/apt/lists/*_Packages >/dev/null 2>&1 || ls /var/lib/apt/lists/*_Packages.* >/dev/null 2>&1; then
  n=$(apt list --upgradable 2>/dev/null | grep -c 'upgradable from')
  [ "$(val actualizables)" = "$n" ] && ok "Recuento de paquetes actualizables correcto ($n)." || no "inventario.txt: actualizables= no coincide con apt list --upgradable ($n ahora)."
else
  no "No hay índices de apt: ejecuta apt update antes de contar actualizaciones."
fi

T=$H/trivy-app.json
if jq -e '.Results' $T >/dev/null 2>&1 && jq -e '[.Results[]?.Vulnerabilities[]?.PkgName] | index("phpmailer/phpmailer")' $T >/dev/null 2>&1; then
  ok "trivy-app.json contiene el análisis de /srv/app."
  c=$(val cve_critica)
  if [ -n "$c" ] && jq -e --arg c "$c" '[.Results[]?.Vulnerabilities[]? | select(.VulnerabilityID==$c and .Severity=="CRITICAL")] | length > 0' $T >/dev/null 2>&1; then
    ok "cve_critica=$c es CRITICAL según trivy."
  else
    no "inventario.txt: cve_critica= no es un CVE CRITICAL de tu informe."
  fi
else
  no "~/trivy-app.json no es un informe JSON de trivy sobre /srv/app."; no "Sin informe no se puede comprobar cve_critica."
fi

Hd=$(curl -s -D - -o /tmp/.b136 --max-time 5 http://127.0.0.1/ | tr -d '\r')
grep -q 'Hola desde PHP' /tmp/.b136 2>/dev/null && ok "La aplicación PHP sigue funcionando." || no "http://127.0.0.1/ ya no ejecuta PHP."
rm -f /tmp/.b136
echo "$Hd" | grep -qi '^x-powered-by' && no "Sigue saliendo X-Powered-By (expose_php)." || ok "Sin X-Powered-By."
echo "$Hd" | grep -qiE '^server: nginx/[0-9]' && no "Server sigue mostrando la versión de nginx." || ok "Server sin versión."
c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1/info.php)
[ "$c" = 404 ] && [ ! -e /srv/app/public/info.php ] && ok "info.php retirado." || no "info.php sigue publicado (código $c)."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Inventario hecho y superficie de versiones reducida."; exit 0; } || exit 1
