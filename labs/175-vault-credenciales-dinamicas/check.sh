#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
export VAULT_ADDR=http://127.0.0.1:8200
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
R=/home/analista/api
RV(){ VAULT_TOKEN=root vault "$@"; }

echo "== Lab 175 · Vault: credenciales dinámicas — comprobación =="

LEAK=$(cat /opt/lab/.leaked)
if PGPASSWORD="$LEAK" psql -h 127.0.0.1 -U tienda_app -d tienda -tAc 'select 1' >/dev/null 2>&1; then
  no "La contraseña filtrada de tienda_app todavía permite entrar en PostgreSQL."
else
  ok "La contraseña filtrada ya no sirve."
fi

TRACKED=$(runuser -u analista -- git -C $R ls-files .env 2>/dev/null)
if [ -z "$TRACKED" ] && [ ! -e $R/.env ] && grep -qxE '/?\.env' $R/.gitignore 2>/dev/null \
   && [ -z "$(runuser -u analista -- git -C $R status --porcelain)" ] \
   && gitleaks dir --no-banner --exit-code 1 $R >/dev/null 2>&1; then
  ok "El repo ya no contiene el secreto (.env fuera, en .gitignore, gitleaks dir limpio)."
else
  no "Repo: .env sigue en el árbol o en git, falta en .gitignore, hay cambios sin commit o gitleaks dir encuentra algo."
fi

ROLE=$(RV read -format=json database/roles/tienda 2>/dev/null)
DT=$(echo "$ROLE" | jq -r '.data.default_ttl // 0'); MT=$(echo "$ROLE" | jq -r '.data.max_ttl // 0')
CR=$(RV read -format=json database/creds/tienda 2>/dev/null)
CU=$(echo "$CR" | jq -r '.data.username // empty'); CP=$(echo "$CR" | jq -r '.data.password // empty')
if [ "$DT" = 3600 ] && [ "$MT" = 86400 ] && [ -n "$CU" ] \
   && PGPASSWORD="$CP" psql -h 127.0.0.1 -U "$CU" -d tienda -tAc 'select count(*) from productos' >/dev/null 2>&1; then
  ok "Rol database/roles/tienda: credenciales que funcionan, TTL 1h / máx. 24h."
else
  no "database/roles/tienda: no genera credenciales válidas o TTL ($DT/$MT) distinto de 1h/24h."
fi
[ -n "$CR" ] && RV lease revoke "$(echo "$CR" | jq -r .lease_id)" >/dev/null 2>&1

TK=$(cat /etc/tienda/vault-token 2>/dev/null)
if [ -n "$TK" ] && [ "$TK" != root ]; then
  POL=$(VAULT_TOKEN="$TK" vault token lookup -format=json 2>/dev/null | jq -r '.data.policies | sort | join(",")')
  C1=$(RV token capabilities "$TK" database/creds/tienda 2>/dev/null)
  C2=$(RV token capabilities "$TK" database/config/postgresql 2>/dev/null)
  C3=$(RV token capabilities "$TK" sys/policies/acl/tienda 2>/dev/null)
  if echo "$POL" | grep -q tienda && ! echo "$POL" | grep -q root && echo "$C1" | grep -q read \
     && [ "$C2" = deny ] && [ "$C3" = deny ]; then
    ok "Token de la app con política 'tienda': sólo lee database/creds/tienda."
  else
    no "Token de /etc/tienda/vault-token: políticas '$POL'; creds=$C1 config=$C2 sys=$C3."
  fi
else
  no "Falta /etc/tienda/vault-token con un token que no sea root."
fi

OUT=$(curl -s --max-time 5 http://127.0.0.1:8080/)
U=$(echo "$OUT" | sed -n 's/.*usuario=\(.*\)$/\1/p')
if echo "$OUT" | grep -q '^stock=' && echo "$U" | grep -q '^v-'; then
  ok "La tienda funciona con un usuario dinámico de Vault ($U)."
else
  no "La tienda responde '$OUT' (debe usar un usuario v-... de Vault)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Sin contraseñas fijas: cada arranque, credenciales nuevas que caducan."; exit 0; } || exit 1
