# Solución — Lab 79

## 1. Identificar al atacante (no al que más pide)

```bash
# Top por IP: 10.0.0.50 lidera, pero es el health check (legítimo).
awk '{print $1}' /var/log/apache2/access.log | sort | uniq -c | sort -rn | head

# Top por /24: 203.0.113 y 198.51.100 dominan, repartido entre decenas de hosts.
awk '{print $1}' /var/log/apache2/access.log | cut -d. -f1-3 | sort | uniq -c | sort -rn | head

# Evidencia de malicia en esos rangos:
grep '^203.0.113.' /var/log/apache2/access.log | head
#  -> misma ruta /buscar, UA python-requests/2.31.0, sin Referer, muchos 503
```

## 2. Escribir el triage

```bash
cat > /home/analista/triage.txt <<'EOF'
Flood HTTP distribuido contra /buscar.
Atacantes: 203.0.113.0/24 y 198.51.100.0/24 (decenas de IPs por red).
Evidencia: mismo User-Agent python-requests, sin Referer, ruta cara repetida, 503.
No bloquear: 10.0.0.50 (health check) ni 66.249.66.1 (Googlebot): alto volumen pero legítimo.
EOF
```

## 3. Rellenar la blocklist

```bash
cat >> /etc/ddos/blocklist.txt <<'EOF'
203.0.113.0/24
198.51.100.0/24
EOF
```

Comprobar:

```bash
bash /opt/lab/check.sh
```

## Lecciones

- **Volumen ≠ ataque.** El top de peticiones era tu propio health check.
- La firma de un flood distribuido: muchas IPs de pocas redes, misma ruta, mismo
  User-Agent, sin `Referer`, picos de `5xx`.
- Antes de bloquear, protege a los legítimos de alto volumen (monitorización,
  balanceadores, crawlers, NAT corporativo) con una lista blanca.
- Bloquear por `/24`/ASN frena mejor un flood que ir IP a IP, pero verifica que
  no arrastras legítimos.
