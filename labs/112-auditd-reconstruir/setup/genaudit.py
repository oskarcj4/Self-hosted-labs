#!/usr/bin/env python3
"""Genera /var/log/audit/audit.log con el formato real del kernel.

El subsistema audit no está disponible dentro de Docker Desktop (el kernel lo
reserva al espacio de nombres inicial), así que el lab trae la captura que
dejó auditd en el servidor real: mismas líneas que escribiría el kernel, para
que ausearch/aureport las interpreten igual.
"""
import pwd
import sys
import time

out = sys.argv[1]
t = time.time() - 3 * 3600  # hace unas 3 horas
serial = 4100
pid = 23000
lines = []


def uid(name):
    return pwd.getpwnam(name).pw_uid


def ts():
    return f"{t:.3f}"


def ev(records):
    global serial
    serial += 1
    for r in records:
        lines.append(r.replace("@", f"audit({ts()}:{serial})"))


def login(user, addr, ses):
    global pid, t
    pid += 7
    ev([f"type=USER_LOGIN msg=@: pid={pid} uid=0 auid={uid(user)} ses={ses} subj=unconfined "
        f"msg='op=login id={uid(user)} exe=\"/usr/sbin/sshd\" hostname={addr} addr={addr} terminal=/dev/pts/{ses} res=success'"])
    t += 1
    ev([f"type=USER_START msg=@: pid={pid} uid=0 auid={uid(user)} ses={ses} subj=unconfined "
        f"msg='op=PAM:session_open grantors=pam_selinux,pam_loginuid,pam_keyinit,pam_permit,pam_umask,pam_unix,pam_systemd,pam_mail,pam_limits,pam_env "
        f"acct=\"{user}\" exe=\"/usr/sbin/sshd\" hostname={addr} addr={addr} terminal=ssh res=success'"])


def write(user, ses, comm, exe, argv, path, key, inode):
    """Una escritura vigilada (open O_WRONLY|O_CREAT) hecha como root tras sudo."""
    global pid, t
    pid += 11
    title = "\0".join(argv).encode().hex().upper()
    parent = path.rsplit("/", 1)[0] + "/"
    ev([
        f"type=SYSCALL msg=@: arch=c000003e syscall=257 success=yes exit=3 a0=ffffff9c a1=55d0c0a1b2c0 a2=241 a3=1b6 items=2 "
        f"ppid={pid - 3} pid={pid} auid={uid(user)} uid=0 gid=0 euid=0 suid=0 fsuid=0 egid=0 sgid=0 fsgid=0 "
        f"tty=pts{ses} ses={ses} comm=\"{comm}\" exe=\"{exe}\" subj=unconfined key=\"{key}\"",
        f"type=CWD msg=@: cwd=\"/home/{user}\"",
        f"type=PATH msg=@: item=0 name=\"{parent}\" inode=131073 dev=08:01 mode=040755 ouid=0 ogid=0 rdev=00:00 "
        f"nametype=PARENT cap_fp=0 cap_fi=0 cap_fe=0 cap_fver=0 cap_frootid=0",
        f"type=PATH msg=@: item=1 name=\"{path}\" inode={inode} dev=08:01 mode=0100640 ouid=0 ogid=42 rdev=00:00 "
        f"nametype=NORMAL cap_fp=0 cap_fi=0 cap_fe=0 cap_fver=0 cap_frootid=0",
        f"type=PROCTITLE msg=@: proctitle={title}",
    ])


def sudo(user, ses, cmd):
    global pid
    pid += 5
    ev([f"type=USER_CMD msg=@: pid={pid} uid={uid(user)} auid={uid(user)} ses={ses} subj=unconfined "
        f"msg='cwd=\"/home/{user}\" cmd={cmd.encode().hex().upper()} exe=\"/usr/bin/sudo\" terminal=pts/{ses} res=success'"])


# Ruido de fondo: cron cada hora.
for _ in range(2):
    ev([f"type=USER_START msg=@: pid={pid} uid=0 auid=0 ses=1 subj=unconfined msg='op=PAM:session_open "
        f"grantors=pam_loginuid,pam_env,pam_permit,pam_unix,pam_limits acct=\"root\" exe=\"/usr/sbin/cron\" hostname=? addr=? terminal=cron res=success'"])
    t += 600

# 1) El operador hace su tarea trimestral: caducidad de contraseñas (legítimo).
login("operador", "10.20.0.15", 3)
t += 40
sudo("operador", 3, "chage -M 90 analista")
write("operador", 3, "chage", "/usr/bin/chage", ["chage", "-M", "90", "analista"], "/etc/shadow", "claves", 2101)
t += 25
sudo("operador", 3, "chage -M 90 operador")
write("operador", 3, "chage", "/usr/bin/chage", ["chage", "-M", "90", "operador"], "/etc/shadow", "claves", 2102)
t += 1900

# 2) El intruso entra con la cuenta del becario desde fuera de la red interna.
login("becario", "203.0.113.45", 7)
t += 95
sudo("becario", 7, "usermod -p $6$xyz$Qe2b0Jm2dGQ1 -s /bin/bash backup")
write("becario", 7, "usermod", "/usr/sbin/usermod",
      ["usermod", "-p", "$6$xyz$Qe2b0Jm2dGQ1", "-s", "/bin/bash", "backup"], "/etc/shadow", "claves", 2103)
t += 37
sudo("becario", 7, "tee -a /etc/sudoers")
write("becario", 7, "tee", "/usr/bin/tee", ["tee", "-a", "/etc/sudoers"], "/etc/sudoers", "sudoers", 2210)
t += 600
ev([f"type=USER_START msg=@: pid={pid} uid=0 auid=0 ses=1 subj=unconfined msg='op=PAM:session_open "
    f"grantors=pam_loginuid,pam_env,pam_permit,pam_unix,pam_limits acct=\"root\" exe=\"/usr/sbin/cron\" hostname=? addr=? terminal=cron res=success'"])

with open(out, "w") as f:
    f.write("\n".join(lines) + "\n")
