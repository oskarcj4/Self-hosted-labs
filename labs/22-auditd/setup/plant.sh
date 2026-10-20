#!/usr/bin/env bash
# Lab 22: arranca el demonio auditd (si el host lo permite). La regla la añade
# el analista. No hay nada malicioso que plantar.
set -e
mkdir -p /etc/audit/rules.d /var/log/audit
# Intenta arrancar auditd; en algunos hosts no estará disponible el audit kernel.
auditd 2>/dev/null || service auditd start 2>/dev/null || true
echo "Lab 22 listo. Lee /RETO.md"
