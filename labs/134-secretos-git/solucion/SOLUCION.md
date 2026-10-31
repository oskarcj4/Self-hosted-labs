# Solución — Secretos en el historial de git

## Qué pasaba

El repo `/srv/repos/pagos` tenía tres credenciales en su historial (AWS
access key, GitHub PAT, Stripe live key). Dos se "borraron" en commits
posteriores; el token de GitHub seguía en `deploy.sh` en HEAD.

## Arreglo

```bash
cd /srv/repos/pagos
gitleaks detect --source . --report-format json --report-path ~/gitleaks.json --exit-code 0
trufflehog git file:///srv/repos/pagos --no-verification --no-update | head
jq -r '.[] | "\(.RuleID) \(.Commit[0:7]) \(.File)"' ~/gitleaks.json | sort -u > ~/secretos.txt
sed -i 's/^aws-access-token/AWS &/; s/^github-pat/GitHub &/; s/^stripe-access-token/Stripe &/' ~/secretos.txt

for v in $(jq -r '.[] | select(.RuleID=="aws-access-token" or .RuleID=="github-pat" or .RuleID=="stripe-access-token") | .Secret' ~/gitleaks.json | sort -u); do
  rotar-secreto "$v"
done

sed -i 's/^GITHUB_TOKEN=.*/: "${GITHUB_TOKEN:?define GITHUB_TOKEN en el entorno}"/' deploy.sh
git add deploy.sh && git commit -m "deploy.sh: el token sale del entorno"
printf '#!/bin/sh\nexec gitleaks protect --staged --redact -v\n' > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
bash /opt/lab/check.sh
```

## Más allá del lab

- Reescribe el historial con `git filter-repo --replace-text` cuando ya estén rotados.
- Usa `pre-commit` (framework) para versionar el hook con el repo.
- Credenciales de corta duración (OIDC en CI) reducen el daño de una fuga.
