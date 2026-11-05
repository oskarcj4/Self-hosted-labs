#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
H=/home/analista
git config --global --add safe.directory /etc 2>/dev/null || true

# 1) Ver qué cambió
git -C /etc status
git -C /etc --no-pager diff -- ssh/sshd_config || true

# 2) Revertir lo no autorizado
git -C /etc checkout -- ssh/sshd_config      # vuelve sshd_config a la base
rm -f /etc/cron.d/stage2                      # fichero añadido sin ticket (untracked)

# 3) Dejar constancia en el historial (si etckeeper quiere commitear el borrado)
etckeeper commit "revert: cambios sin ticket (PermitRootLogin, cron.d/stage2)" >/dev/null 2>&1 || true

# 4) Documentar
cat > $H/cambios.txt <<'C'
Cambios no autorizados (sin ticket CHG) encontrados en /etc:
- /etc/ssh/sshd_config: se cambió a 'PermitRootLogin yes' (root abierto por SSH). Revertido.
- /etc/cron.d/stage2: cron oculto que ejecutaba /usr/local/bin/.stage2. Eliminado.
C
chown analista:analista $H/cambios.txt
echo "solve.sh completado."
git -C /etc status --porcelain
