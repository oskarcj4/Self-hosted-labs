#!/usr/bin/env bash
# Lab 76 (dns-01): el DNS de la oficina reenvía todo al proveedor, sin log ni
# lista de bloqueo. Un puesto (pc-02, 10.76.76.22) está infectado y hace beacon.
set -e
cat > /etc/dnsmasq.d/10-base.conf <<'EOF'
# DNS de la oficina: reenvía a los DNS del proveedor.
no-resolv
server=10.76.76.2
listen-address=127.0.0.1,10.76.76.53
bind-interfaces
domain-needed
bogus-priv
cache-size=1000
EOF
systemctl enable dnsmasq >/dev/null 2>&1
systemctl restart dnsmasq

# El feed de amenazas: formato hosts, tal y como lo publica el CERT (con sus manías).
mkdir -p /srv/threat-intel
python3 - <<'PY'
import random
r = random.Random(7676)
a = ["cdn", "update", "secure", "login", "track", "pixel", "stat", "mail", "cloud", "api",
     "sync", "push", "verify", "account", "wallet", "promo", "files", "drive", "auth", "data"]
b = ["service", "check", "panel", "zone", "hub", "box", "net", "point", "link", "base",
     "gate", "flow", "spot", "core", "lab", "port", "line", "mart", "dock", "grid"]
tld = ["xyz", "top", "click", "icu", "work", "buzz", "monster", "cyou", "rest", "quest"]
doms = set()
while len(doms) < 160:
    doms.add(f"{r.choice(a)}-{r.choice(b)}{r.randint(1, 99)}.{r.choice(tld)}")
doms = sorted(doms) + ["malsrv.top", "cdn-telemetria.xyz", "analytics.proveedor.example"]
r.shuffle(doms)
out = ["# Feed de dominios maliciosos · CERT TerminalCero · 2026-10-20",
       "# Formato hosts. Uso: bloquear en el DNS.",
       "127.0.0.1 localhost", "::1 localhost", "0.0.0.0 0.0.0.0", ""]
for i, d in enumerate(doms):
    ip = "127.0.0.1" if i % 7 == 0 else "0.0.0.0"
    name = d.upper() if i % 11 == 0 else d
    line = f"{ip} {name}"
    if i % 13 == 0:
        line += "    # botnet"
    if i % 29 == 0:
        out.append(f"# --- lote {i // 29 + 1} ---")
    out.append(line + ("\r" if i % 5 == 0 else ""))
    if i % 17 == 0:
        out.append(f"0.0.0.0 {d}")          # duplicados, como en los feeds reales
with open("/srv/threat-intel/feed-2026-10-20.txt", "w", newline="\n") as f:
    f.write("\n".join(out) + "\n")
PY
cat > /srv/threat-intel/allowlist.txt <<'EOF'
# Dominios que el negocio NECESITA aunque aparezcan en algún feed (falsos positivos
# confirmados por seguridad). Nunca se bloquean.
analytics.proveedor.example
EOF
chmod 0644 /srv/threat-intel/*

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/SEC-7610.txt <<'EOF'
SEC-7610 · dns-01 · "algo en la oficina habla con un C2"
- El proveedor nos avisa: desde nuestra IP pública salen consultas DNS a
  dominios de una botnet. No sabemos qué puesto es: todos los PCs usan
  este servidor (dns-01, dnsmasq) como DNS.
- El CERT publica un feed: /srv/threat-intel/feed-2026-10-20.txt
  Falsos positivos confirmados: /srv/threat-intel/allowlist.txt
- Necesitamos:
  1. Que dns-01 registre las consultas (quién pregunta qué).
  2. Sinkhole: todos los dominios del feed (y sus subdominios) responden
     0.0.0.0 o NXDOMAIN. Lo de la allowlist sigue funcionando.
  3. La IP del puesto infectado en ~/infectado.txt (una IP por línea),
     para que soporte lo aísle.
- Que sobreviva a un reinicio del servicio.
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 76 plantado."
