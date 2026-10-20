#!/usr/bin/env python3
"""Genera un auth.log de ataque de fuerza bruta SSH. Varias IPs fallan; la IP
203.0.113.66 falla mucho y al final entra (Accepted password)."""
import random
import time

OUT = "/var/log/auth.log"
NOISE_IPS = ["45.142.120.10", "193.32.162.5", "61.177.173.9",
             "222.186.30.112", "141.98.11.27"]
BREACH_IP = "203.0.113.66"
USERS = ["root", "admin", "test", "oracle", "postgres", "ubuntu", "git"]

random.seed(14)
rows = []
t = time.time() - 7200


def line(ts, msg):
    return f"{time.strftime('%b %e %H:%M:%S', time.localtime(ts))} bastion-14 {msg}"


# ruido: fallos de varias IPs
for _ in range(500):
    t += random.uniform(0.2, 2)
    ip = random.choice(NOISE_IPS)
    u = random.choice(USERS)
    rows.append(line(t, f"sshd[{random.randint(1000,9999)}]: Failed password for {u} from {ip} port {random.randint(1024,65000)} ssh2"))

# la IP de la brecha: muchos fallos...
for _ in range(220):
    t += random.uniform(0.1, 1)
    rows.append(line(t, f"sshd[2201]: Failed password for root from {BREACH_IP} port {random.randint(1024,65000)} ssh2"))

# ...y finalmente entra
t += 1
rows.append(line(t, f"sshd[2201]: Accepted password for root from {BREACH_IP} port 50122 ssh2"))
rows.append(line(t, "sshd[2201]: pam_unix(sshd:session): session opened for user root by (uid=0)"))

with open(OUT, "w") as f:
    f.write("\n".join(rows) + "\n")
