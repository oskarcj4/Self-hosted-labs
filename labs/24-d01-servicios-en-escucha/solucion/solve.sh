#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
ss -H -tlnp | awk '{port=$4; sub(/.*:/,"",port); host=$4; sub(/:[0-9]+$/,"",host);
  proc=$0; sub(/.*users:\(\("/,"",proc); sub(/".*/,"",proc);
  if (port!=7681 && host!="127.0.0.11") print port "," (host ~ /^127\./ ? "local" : "publico") "," proc}' \
  | sort -un | { echo "puerto,exposicion,proceso"; cat; } > /home/analista/audit/listeners.csv
chown analista: /home/analista/audit/listeners.csv
