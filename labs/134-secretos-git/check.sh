#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 134.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista
R=/srv/repos/pagos
G(){ git -c safe.directory='*' -C $R "$@"; }

echo "== Lab 134 · Secretos en el historial de git — comprobación =="
J=$H/gitleaks.json
if jq -e 'type=="array" and length>=3' $J >/dev/null 2>&1; then
  rules=$(jq -r '.[].RuleID' $J | sort -u | tr '\n' ' ')
  miss=""; for r in aws-access-token github-pat stripe-access-token; do echo " $rules" | grep -q " $r " || miss="$miss $r"; done
  [ -z "$miss" ] && ok "gitleaks.json recoge las 3 credenciales del historial." || no "A gitleaks.json le faltan hallazgos:$miss (¿escaneaste todo el historial?)."
else
  no "~/gitleaks.json no es un informe de gitleaks en JSON con hallazgos."
fi

miss=0
while read -r c; do grep -q "${c:0:7}" $H/secretos.txt 2>/dev/null || miss=$((miss+1)); done < <($SUDO cat /opt/lab/.ref-commits)
[ "$miss" -eq 0 ] && ok "secretos.txt señala los 3 commits que introdujeron credenciales." || no "secretos.txt: faltan $miss commits de origen (hash corto)."
grep -qi aws $H/secretos.txt 2>/dev/null && grep -qi github $H/secretos.txt && grep -qi stripe $H/secretos.txt \
  && ok "secretos.txt indica el tipo de cada credencial." || no "secretos.txt debe indicar el tipo (AWS, GitHub, Stripe)."

n=$(grep -cxFf /var/lib/boveda/emitidas /var/lib/boveda/revocadas 2>/dev/null)
[ "${n:-0}" -ge 3 ] && ok "Las 3 credenciales están rotadas." || no "Credenciales rotadas: ${n:-0}/3 (usa rotar-secreto)."

if G grep -qE 'ghp_[A-Za-z0-9]{36}|AKIA[A-Z0-9]{16}|sk_live_[A-Za-z0-9]{24}' HEAD -- 2>/dev/null; then
  no "El último commit todavía contiene una credencial."
elif grep -rqsE 'ghp_[A-Za-z0-9]{36}|AKIA[A-Z0-9]{16}|sk_live_[A-Za-z0-9]{24}' --exclude-dir=.git $R; then
  no "El directorio de trabajo todavía contiene una credencial."
else
  ok "Ni el último commit ni el directorio de trabajo contienen credenciales."
fi
[ -z "$(G status --porcelain --untracked-files=no)" ] && ok "Los cambios están commiteados." || no "Hay cambios sin commitear en el repo."
grep -qxE '\.env|/\.env|\.env\*' $R/.gitignore 2>/dev/null && ok ".env sigue en .gitignore." || no ".gitignore debe ignorar .env."

HK=$R/.git/hooks/pre-commit
if [ -x $HK ] && grep -q gitleaks $HK; then
  ok "Hook pre-commit con gitleaks instalado."
  T=$R/prueba-hook-$$.txt
  printf 'token = "ghp_%s"\n' "$(head -c 200 /dev/urandom | tr -dc A-Za-z0-9 | head -c 36)" > $T
  G add -f "$(basename $T)" >/dev/null 2>&1
  if (cd $R && git -c safe.directory='*' -c core.hooksPath=.git/hooks hook run pre-commit >/dev/null 2>&1 || ./.git/hooks/pre-commit >/dev/null 2>&1); then
    no "El hook deja pasar un token de GitHub recién añadido."
  else
    ok "El hook bloquea un commit con un token de GitHub."
  fi
  G rm -q --cached "$(basename $T)" >/dev/null 2>&1; rm -f $T
else
  no "Falta un .git/hooks/pre-commit ejecutable que llame a gitleaks."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Historial auditado, credenciales rotadas y repo protegido."; exit 0; } || exit 1
