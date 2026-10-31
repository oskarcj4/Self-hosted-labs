#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Ejecuta como root; trabaja como analista.
set -e
R=/srv/repos/pagos
H=/home/analista
sudo -u analista bash -s <<'S'
set -e
R=/srv/repos/pagos; H=/home/analista
cd $R
git log --oneline --all
gitleaks detect --source . --report-format json --report-path $H/gitleaks.json --exit-code 0
trufflehog git file://$R --no-verification --no-update --json 2>/dev/null | head -3 || true
jq -r '.[] | "\(.RuleID) \(.Commit[0:7]) \(.File)"' $H/gitleaks.json | sort -u > $H/secretos.txt
sed -i 's/^aws-access-token/AWS aws-access-token/; s/^github-pat/GitHub github-pat/; s/^stripe-access-token/Stripe stripe-access-token/' $H/secretos.txt
cat $H/secretos.txt
for v in $(jq -r '.[] | select(.RuleID=="aws-access-token" or .RuleID=="github-pat" or .RuleID=="stripe-access-token") | .Secret' $H/gitleaks.json | sort -u); do
  rotar-secreto "$v"
done
sed -i 's/^GITHUB_TOKEN=.*/: "${GITHUB_TOKEN:?define GITHUB_TOKEN en el entorno}"/' deploy.sh
git add deploy.sh && git commit -qm "deploy.sh: el token sale del entorno"
cat > .git/hooks/pre-commit <<'HK'
#!/bin/sh
# Bloquea commits con secretos.
exec gitleaks protect --staged --redact -v
HK
chmod +x .git/hooks/pre-commit
S
