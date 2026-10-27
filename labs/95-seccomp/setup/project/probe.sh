#!/usr/bin/env bash
# Prueba desde DENTRO del contenedor api qué syscalls sensibles están permitidas.
set -euo pipefail
cd "$(dirname "$0")"
base=$(awk '/^Seccomp_filters:/{print $2}' /proc/1/status)
docker compose exec -T -e BASE="$base" api python - <<'EOF'
import ctypes, os
libc = ctypes.CDLL(None, use_errno=True)

def show(name, r):
    e = ctypes.get_errno()
    print(f"  {name:<18} {'BLOQUEADO (' + os.strerror(e) + ')' if r < 0 else 'permitido'}")

st = dict(l.split(":", 1) for l in open("/proc/self/status").read().splitlines() if ":" in l)
n, base = st.get("Seccomp_filters", "?").strip(), os.environ.get("BASE", "?")
print(f"  filtros seccomp    {n}  (host del lab: {base}; uno más = Docker aplica perfil)")
show("ptrace", libc.ptrace(0, 0, 0, 0))

class iovec(ctypes.Structure):
    _fields_ = [("base", ctypes.c_void_p), ("len", ctypes.c_size_t)]
dst, src = ctypes.create_string_buffer(8), ctypes.create_string_buffer(b"secreto!")
l = iovec(ctypes.cast(dst, ctypes.c_void_p), 8)
r = iovec(ctypes.cast(src, ctypes.c_void_p), 8)
libc.process_vm_readv.restype = ctypes.c_ssize_t
show("process_vm_readv", libc.process_vm_readv(os.getpid(), ctypes.byref(l), 1, ctypes.byref(r), 1, 0))
show("unshare(NEWUSER)", libc.unshare(0x10000000))
EOF
