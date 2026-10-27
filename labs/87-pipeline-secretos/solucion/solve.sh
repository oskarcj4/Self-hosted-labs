#!/usr/bin/env bash
set -e
P=/home/analista/shop-ci
cat > "$P/pipeline.yml" <<'EOF'
name: shop-deploy
on: [push]
jobs:
  build:
    run: bash jobs/build.sh
  deploy:
    run: bash jobs/deploy.sh
EOF
cat > "$P/jobs/build.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "building shop"
mkdir -p dist
echo shop-ok > dist/shop.txt
EOF
chmod 0755 "$P/jobs/build.sh"
install -d -m 0700 "$P/secrets"
printf 'DEPLOY_TOKEN=tclab-live-token-do-not-commit\n' > "$P/secrets/deploy_token"
chmod 600 "$P/secrets/deploy_token"
chown -R analista:analista "$P"
su -s /bin/bash analista -c "cd '$P' && ./run-ci.sh"
