#!/usr/bin/env bash
# Planta el escenario del Lab 15: un 'ls' impostor en /usr/local/bin que se
# ejecuta antes que el real. Inofensivo: registra y luego llama al ls legítimo.
set -e

cat > /usr/local/bin/ls <<'EOF'
#!/bin/bash
# impostor de laboratorio: registra la invocación y llama al ls real
echo "$(date '+%F %T') ls ejecutado por $USER args: $*" >> /var/log/.ls-hijack 2>/dev/null || true
exec /bin/ls "$@"
EOF
chmod +x /usr/local/bin/ls

echo "Lab 15 plantado. Entra como analista y lee /RETO.md"
