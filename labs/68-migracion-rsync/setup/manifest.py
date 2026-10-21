#!/usr/bin/env python3
"""Manifiesto de un árbol de ficheros (lab 68): una línea por entrada con
tipo, permisos, dueño y grupo POR NOMBRE, tamaño, mtime, sha256, destino de
los enlaces y grupo de hardlinks. Se genera igual en old-srv y en new-srv
para comparar la migración."""
import grp
import hashlib
import os
import pwd
import stat
import sys


def name(fn, i):
    try:
        return fn(i)[0]
    except KeyError:
        return str(i)


root = sys.argv[1].rstrip("/") or "/"
rows, first = [], {}
entries = ["."]
for dp, dns, fns in os.walk(root):
    dns.sort()
    entries += [os.path.relpath(os.path.join(dp, n), root) for n in dns + sorted(fns)]
for rel in entries:
    p = os.path.join(root, rel)
    st = os.lstat(p)
    if stat.S_ISLNK(st.st_mode):
        rows.append(f"{rel}\tl\t{os.readlink(p)}")
        continue
    mode = format(stat.S_IMODE(st.st_mode), "04o")
    own = f"{name(pwd.getpwuid, st.st_uid)}:{name(grp.getgrgid, st.st_gid)}"
    if stat.S_ISDIR(st.st_mode):
        rows.append(f"{rel}\td\t{mode}\t{own}")
        continue
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 16), b""):
            h.update(b)
    hl = first.setdefault((st.st_dev, st.st_ino), rel) if st.st_nlink > 1 else "-"
    rows.append(f"{rel}\tf\t{mode}\t{own}\t{st.st_size}\t{int(st.st_mtime)}\t{h.hexdigest()[:16]}\thl={hl}")
print("\n".join(sorted(rows)))
