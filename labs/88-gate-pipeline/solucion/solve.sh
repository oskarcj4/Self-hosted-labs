#!/usr/bin/env bash
set -e
P=/home/analista/gate-ci
cat > "$P/pipeline.yml" <<'EOF'
name: shop-gate
jobs:
  secret-scan:
    run: bash jobs/secret-scan.sh
  deploy:
    needs: [secret-scan]
    run: bash jobs/deploy.sh
EOF
cat > "$P/app/config.py" <<'EOF'
import os
PASSWORD = os.environ.get("APP_PASSWORD", "")
DEBUG = False
EOF
chown -R analista:analista "$P"
su -s /bin/bash analista -c "cd '$P' && ./run-ci.sh"
