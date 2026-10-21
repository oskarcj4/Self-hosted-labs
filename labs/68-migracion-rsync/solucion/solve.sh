#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root en new-srv.
# La contraseña de migra se pasa con SSH_ASKPASS sólo para poder automatizar.
set -e
printf '#!/bin/sh\necho Migra-2026\n' > /tmp/askpass.sh && chmod 755 /tmp/askpass.sh
export SSH_ASKPASS=/tmp/askpass.sh SSH_ASKPASS_REQUIRE=force DISPLAY=:0
rsync -aH --delete --rsync-path='sudo rsync' -e 'ssh -o StrictHostKeyChecking=accept-new' \
  migra@old-srv:/srv/media/ /srv/media/
rm -f /tmp/askpass.sh
