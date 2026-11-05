#!/usr/bin/env bash
# Lab 144 (Mr. Robot M2): triage en el SOC de Allsafe.
# Un feed de alertas del "SIEM" lleno de ruido esconde 3 incidentes reales.
# El alumno separa señal de ruido, nombra al atacante y silencia la regla ruidosa.
set -e
export HOME=/root
H=/home/analista

install -d -m 0755 /var/log/soc /etc/soc /etc/soc/reglas.d

# --- feed de alertas (JSONL) --------------------------------------------------
python3 - <<'PY' > /var/log/soc/alertas.jsonl
import json, random
random.seed(59)
out = []
nid = 7000
def add(regla, nivel, src, msg):
    global nid
    out.append({"id": nid, "regla": regla, "nivel": nivel, "src_ip": src, "msg": msg})
    nid += 1

# Ruido de fondo: health checks del balanceador interno (regla ruidosa).
for i in range(18):
    add("healthcheck_http", 2, f"10.143.0.{20+i%4}", "GET /health 200")
# Inicios de sesión normales de oficina.
for u in ["angela","gideon","ollie","angela","gideon"]:
    add("auth_session_opened", 3, "10.143.0.31", f"sesión abierta para {u}")
# Escáner de vulnerabilidades AUTORIZADO del equipo de pentest (benigno).
for i in range(6):
    add("vuln_scan", 4, "10.0.5.5", "escaneo autorizado (ventana aprobada CHG-2271)")
# Rotaciones de log y cron rutinario.
add("cron_run", 1, "127.0.0.1", "logrotate ejecutado")
add("tls_cert_ok", 2, "127.0.0.1", "certificado válido 83 días")

# --- INCIDENTES REALES (nivel alto, mismo origen externo) ---------------------
add("ssh_bruteforce_success", 12, "203.0.113.7", "login SSH correcto para 'elliot' tras 240 fallos")  # 7031
add("web_shell_upload",       13, "203.0.113.7", "subida de 0.php a /var/www/uploads (webshell)")      # 7032
add("privesc_sudo",           12, "203.0.113.7", "www-data ejecutó /bin/bash por sudo sin tty")        # 7033

random.shuffle(out)
for a in out:
    print(json.dumps(a, ensure_ascii=False))
PY

# IDs reales deterministas (los calculamos y los dejamos en el "ground truth" interno).
REALES=$(python3 -c "import json;print(','.join(str(a['id']) for a in sorted((json.loads(l) for l in open('/var/log/soc/alertas.jsonl')), key=lambda x:x['id']) if a['nivel']>=10))")
echo "$REALES" > /etc/soc/.ground_truth   # sólo para referencia del validador
chmod 0640 /etc/soc/.ground_truth

# --- herramienta de apoyo -----------------------------------------------------
cat > /usr/local/bin/soc-stats <<'SH'
#!/usr/bin/env bash
# Resumen del feed de alertas: cuenta por regla y por nivel.
F=/var/log/soc/alertas.jsonl
echo "== por regla =="; jq -r .regla "$F" | sort | uniq -c | sort -rn
echo "== por nivel =="; jq -r .nivel "$F" | sort -n | uniq -c
echo "== nivel >= 10 (candidatos a incidente real) =="; jq -c 'select(.nivel>=10)' "$F"
SH
chmod 0755 /usr/local/bin/soc-stats

# --- ticket -------------------------------------------------------------------
mkdir -p $H/ticket
cat > $H/ticket/SOC-144.txt <<'TXT'
SOC-144 · turno de noche · demasiadas alertas
El SIEM dispara cientos de alertas y el equipo está "ciego por ruido".
Separa señal de ruido antes de escalar nada.

Feed: /var/log/soc/alertas.jsonl   (ayuda: soc-stats)

1. ~/triage.txt:
     ip_atacante=<IP del origen de los incidentes reales>
     alertas_reales=<ids separados por coma>
     regla_ruidosa=<la regla de bajo nivel que hay que silenciar>
2. Silencia esa regla ruidosa: añádela a /etc/soc/supresiones.txt (una por línea).

Pista: un incidente real suele ser nivel alto, de un origen externo y encadenado
(acceso -> webshell -> escalada). Un escáner autorizado NO es un incidente.
TXT
chown -R analista:analista $H/ticket
echo "Lab 144 plantado."
