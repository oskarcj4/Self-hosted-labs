#!/usr/bin/env bash
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
P=/home/analista/seccomp
PROF="$P/profiles/api.json"
c=$(docker ps -q --filter label=com.docker.compose.project=seccomp --filter label=com.docker.compose.service=api | head -1)

echo "== Lab 95 · seccomp — comprobación =="

[ -n "$c" ] || { no "La api no está corriendo."; echo "Resultado: $pass superados, $fail pendientes."; exit 1; }

# ---------- configuración ----------
if grep -qi unconfined "$P/compose.yaml"; then
  no "compose.yaml todavía pide unconfined."
elif docker inspect -f '{{join .HostConfig.SecurityOpt " "}}' "$c" | grep -qi 'unconfined'; then
  no "El contenedor sigue unconfined (¿docker compose up -d --force-recreate?)."
else
  ok "Sin unconfined en compose.yaml ni en el contenedor."
fi

if ! jq -e . "$PROF" >/dev/null 2>&1; then
  no "No hay un JSON válido en profiles/api.json."
else
  case "$(jq -r .defaultAction "$PROF")" in
    SCMP_ACT_ERRNO|SCMP_ACT_KILL|SCMP_ACT_KILL_PROCESS|SCMP_ACT_KILL_THREAD|SCMP_ACT_TRAP)
      ok "profiles/api.json es lista blanca (defaultAction deniega)." ;;
    *) no "profiles/api.json no es lista blanca: defaultAction=$(jq -r .defaultAction "$PROF")." ;;
  esac
  left=$(jq -r '[.syscalls[] | select(.action == "SCMP_ACT_ALLOW") | .names[]
                 | select(IN("ptrace", "process_vm_readv", "process_vm_writev"))] | unique | join(" ")' "$PROF")
  [ -z "$left" ] && ok "El perfil no permite ptrace ni process_vm_*." \
    || no "El perfil todavía permite: $left"
fi

# ---------- runtime ----------
out=$(docker exec -i "$c" python - <<'EOF' 2>&1
import ctypes, os
libc = ctypes.CDLL(None, use_errno=True)
st = dict(l.split(":", 1) for l in open("/proc/self/status").read().splitlines() if ":" in l)
print("filters", st.get("Seccomp_filters", "-1").strip())
r = libc.ptrace(0, 0, 0, 0); print("ptrace", r, ctypes.get_errno())
class iovec(ctypes.Structure):
    _fields_ = [("base", ctypes.c_void_p), ("len", ctypes.c_size_t)]
d, s = ctypes.create_string_buffer(8), ctypes.create_string_buffer(8)
l = iovec(ctypes.cast(d, ctypes.c_void_p), 8); m = iovec(ctypes.cast(s, ctypes.c_void_p), 8)
libc.process_vm_readv.restype = ctypes.c_ssize_t
r = libc.process_vm_readv(os.getpid(), ctypes.byref(l), 1, ctypes.byref(m), 1, 0)
print("pvr", r, ctypes.get_errno())
EOF
)
# Docker Desktop y algunos hosts ya aplican un filtro a todo: cuenta los filtros
# del contenedor contra los del propio host del lab.
base=$(awk '/^Seccomp_filters:/{print $2}' /proc/1/status)
inner=$(awk '/^filters/{print $2}' <<<"$out")
if [ -n "$base" ] && [ "${inner:--1}" -gt "$base" ]; then
  ok "Docker aplica su filtro seccomp al contenedor ($inner filtros; host del lab: $base)."
else
  no "Docker no añade filtro seccomp al contenedor (filtros: ${inner:-?}; host del lab: ${base:-?})."
fi
grep -q '^ptrace -1 1$' <<<"$out" && ok "ptrace → EPERM dentro del contenedor." \
  || no "ptrace sigue permitido dentro del contenedor."
grep -q '^pvr -1 1$' <<<"$out" && ok "process_vm_readv → EPERM dentro del contenedor." \
  || no "process_vm_readv sigue permitido dentro del contenedor."

if curl -sf --max-time 3 http://127.0.0.1:8080/ | grep -q 'api ok'; then
  ok "La api responde."
else
  no "curl :8080 no devuelve api ok."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Perfil seccomp a medida. ¡Lab 95 resuelto!"; exit 0; } || exit 1
