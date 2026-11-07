#!/usr/bin/env bash
# Lab 22: deja listo auditd. La regla la añade el analista.
# El audit del kernel sólo se puede configurar desde el PID namespace inicial
# del host: dentro de un contenedor (Docker Desktop/WSL2 incluido) auditctl
# recibe "Operation not permitted". Si es así, se instalan en /usr/local/sbin
# versiones emuladas de auditctl/ausearch/augenrules (inotify + audit.log con
# el formato de auditd) que aceptan los mismos comandos del lab.
mkdir -p /etc/audit/rules.d /var/log/audit
if auditctl -s >/dev/null 2>&1; then
  auditd 2>/dev/null || service auditd start 2>/dev/null || true
  echo "Lab 22: audit del kernel disponible."
else
  install -m 0755 /opt/lab/audit-emulado/auditctl /opt/lab/audit-emulado/ausearch \
                  /opt/lab/audit-emulado/augenrules /opt/lab/audit-emulado/tclab-audit-watch /usr/local/sbin/
  touch /var/log/audit/audit.log; chmod 0600 /var/log/audit/audit.log
  # Reglas persistentes que ya existieran
  ls /etc/audit/rules.d/*.rules >/dev/null 2>&1 && /usr/local/sbin/augenrules --load >/dev/null
  echo "Lab 22: audit del kernel no disponible en este contenedor; usando auditctl/ausearch emulados."
fi
echo "Lab 22 listo. Lee /RETO.md"
