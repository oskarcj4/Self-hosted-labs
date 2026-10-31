#!/bin/sh
# Publica los paquetes del lab en el registro interno (una sola vez).
set -e
R=http://registry:4873
until wget -q -O /dev/null $R/-/ping; do sleep 1; done
TOKEN=$(node -e '
fetch(process.argv[1] + "/-/user/org.couchdb.user:publicador", {
  method: "PUT", headers: {"content-type": "application/json"},
  body: JSON.stringify({name: "publicador", password: "Publica-135!"})
}).then(r => r.json()).then(j => console.log(j.token || ""))' $R)
[ -n "$TOKEN" ] || { echo "sin token (¿ya publicado?)"; exit 0; }
echo "//registry:4873/:_authToken=$TOKEN" > ~/.npmrc
for d in /paquetes/*/; do
  rm -rf /tmp/p && cp -r "$d" /tmp/p
  (cd /tmp/p && npm publish --registry $R/ --ignore-scripts) || true
done
echo "publicación terminada"
