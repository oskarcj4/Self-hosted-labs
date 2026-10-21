#!/usr/bin/env bash
# Solución automática para pg-01 (sirve para probar el lab). Corre como root en pg-01.
set -e
C=/etc/postgresql/15/main
cat > $C/conf.d/90-hardening.conf <<'EOF'
# Hardening CIS 3.1 (SEC-118): sólo loopback + red interna (excepción INC-6707: app-04).
listen_addresses = 'localhost,10.76.67.20'
EOF
python3 - $C/pg_hba.conf <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
mark = "# Hardening CIS (SEC-118)"
s = s.replace(mark, "# INC-6707: informe diario desde app-04\n"
              "host    ventas          informes        10.76.67.10/32          scram-sha-256\n\n" + mark, 1)
open(p, "w").write(s)
PY
systemctl restart postgresql
