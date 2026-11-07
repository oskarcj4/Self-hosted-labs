#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
K="kubectl -n lotes"
g(){ $K get "$1" -o jsonpath="{$2}" 2>/dev/null; }

echo "== Lab 198 · Jobs y CronJobs — comprobación =="

# 1) backup
CP=$(g cronjob/backup .spec.concurrencyPolicy)
AD=$(g cronjob/backup .spec.jobTemplate.spec.activeDeadlineSeconds)
SD=$(g cronjob/backup .spec.startingDeadlineSeconds)
HS=$(g cronjob/backup .spec.successfulJobsHistoryLimit)
HF=$(g cronjob/backup .spec.failedJobsHistoryLimit)
if [ "$CP" = Forbid ]; then ok "backup: concurrencyPolicy Forbid (nunca dos a la vez)."
else no "backup: concurrencyPolicy es '${CP:-Allow}', los backups se solapan."; fi
if [ -n "$AD" ] && [ "$AD" -ge 100 ] && [ "$AD" -le 300 ] && [ -n "$SD" ] && [ "$SD" -le 60 ]; then
  ok "backup: se mata a los ${AD}s y no recupera ejecuciones de más de ${SD}s."
else
  no "backup: activeDeadlineSeconds='$AD' (entre 100 y 300) y startingDeadlineSeconds='$SD' (≤60)."
fi
if [ -n "$HS" ] && [ -n "$HF" ] && [ "$HS" -le 3 ] && [ "$HF" -le 3 ]; then
  ok "backup: historial limitado ($HS correctos, $HF fallidos)."
else
  no "backup: falta limitar el historial (successfulJobsHistoryLimit y failedJobsHistoryLimit ≤3)."
fi
ACT=$($K get jobs -o json | python3 -c '
import json,sys
print(sum(1 for j in json.load(sys.stdin)["items"]
  if any(o.get("name")=="backup" for o in j["metadata"].get("ownerReferences") or []) and (j["status"].get("active") or 0)>0))')
[ "${ACT:-0}" -le 1 ] && ok "Ahora mismo hay $ACT backup en marcha (≤1)." \
                       || no "Hay $ACT backups en marcha a la vez: borra los Jobs solapados."

# 2) migracion
SUC=$(g job/migracion .status.succeeded)
BL=$(g job/migracion .spec.backoffLimit)
TTL=$(g job/migracion .spec.ttlSecondsAfterFinished)
LOG=$($K logs job/migracion 2>/dev/null | tail -1)
if [ "$SUC" = 1 ] && echo "$LOG" | grep -q 'migración 42 completada'; then
  ok "migracion completada ('$LOG')."
else
  no "migracion no se ha completado (succeeded='${SUC:-0}', último log: '${LOG:-ninguno}')."
fi
if [ -n "$BL" ] && [ "$BL" -le 3 ] && [ -n "$TTL" ] && [ "$TTL" -ge 3600 ]; then
  ok "migracion: backoffLimit $BL y se borra sola a los ${TTL}s."
else
  no "migracion: backoffLimit='$BL' (≤3) y ttlSecondsAfterFinished='$TTL' (≥3600)."
fi

# 3) limpieza
TZ_=$(g cronjob/limpieza .spec.timeZone); SC=$(g cronjob/limpieza .spec.schedule)
if [ "$TZ_" = Europe/Madrid ] && [ "$SC" = "0 3 * * *" ]; then
  ok "limpieza: '0 3 * * *' en Europe/Madrid (el horario de verano lo resuelve Kubernetes)."
else
  no "limpieza: schedule='$SC', timeZone='${TZ_:-UTC}'. Debe correr a las 03:00 de Madrid todo el año."
fi

# 4) informe: no suspendido y funciona de verdad (ejecución manual)
SUS=$(g cronjob/informe .spec.suspend)
$K delete job chk-informe --ignore-not-found >/dev/null 2>&1
if [ "$SUS" != true ] && $K create job chk-informe --from=cronjob/informe >/dev/null 2>&1 \
   && $K wait --for=condition=Complete job/chk-informe --timeout=60s >/dev/null 2>&1; then
  ok "informe: ya no está suspendido y una ejecución manual termina bien."
else
  no "informe: sigue suspendido (suspend='$SUS') o su Job no termina."
fi
$K delete job chk-informe --ignore-not-found >/dev/null 2>&1

DIF=""
for f in /home/analista/lotes/*.yaml; do
  kubectl diff -f "$f" >/dev/null 2>&1; [ $? -eq 1 ] && DIF="$DIF $(basename "$f")"
done
[ -z "$DIF" ] && ok "Lo aplicado coincide con ~/lotes." || no "El clúster no coincide con ~/lotes:$DIF (kubectl diff)."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Lotes que no se pisan, no reintentan sin fin y corren a su hora."; exit 0; } || exit 1
