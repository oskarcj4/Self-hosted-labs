#!/usr/bin/env python3
"""Genera un log de consultas DNS realista: tráfico normal + un patrón claro de
exfiltración por DNS hacia cdn-sync.io (subdominios largos tipo base32)."""
import base64
import os
import random
import time

OUT = "/var/log/dnsquery.log"
NORMAL = ["www.google.com", "debian.org", "github.com", "cloudflare.com",
          "api.weather.com", "ntp.ubuntu.com", "mirror.debian.org"]
EXFIL_DOMAIN = "cdn-sync.io"

random.seed(12)
lines = []
t = time.time() - 3600
for _ in range(1200):
    t += random.uniform(0.1, 3)
    ts = time.strftime("%b %e %H:%M:%S", time.localtime(t))
    if random.random() < 0.65:
        q = random.choice(NORMAL)
    else:
        blob = base64.b32encode(os.urandom(random.randint(16, 28))).decode().strip("=").lower()
        q = f"{blob}.{EXFIL_DOMAIN}"
    lines.append(f"{ts} named[612]: query: {q} IN A")

with open(OUT, "w") as f:
    f.write("\n".join(lines) + "\n")
