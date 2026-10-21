#!/usr/bin/env bash
# Solución automática para log-01 (sirve para probar el lab). Corre como root en log-01.
set -e
cat > /etc/rsyslog.d/10-colector.conf <<'EOF'
# Colector central: recibe por TCP 514 y guarda un fichero por máquina y programa.
module(load="imtcp")
template(name="PorHost" type="string" string="/var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log")
ruleset(name="remoto") {
    action(type="omfile" dynaFile="PorHost" createDirs="on")
    stop
}
input(type="imtcp" port="514" ruleset="remoto")
EOF
rsyslogd -N1 2>&1 | tail -1
systemctl restart rsyslog
