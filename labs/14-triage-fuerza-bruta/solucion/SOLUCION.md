# Solución — Lab 14

## 1. Contar fallos por IP

```bash
grep 'Failed password' /var/log/auth.log | grep -oE 'from [0-9.]+' \
  | awk '{print $2}' | sort | uniq -c | sort -rn | head
```

Verás varias IPs ruidosas y `203.0.113.66` con ~220 fallos.

## 2. ¿Quién entró?

```bash
grep 'Accepted password' /var/log/auth.log
# Accepted password for root from 203.0.113.66 port 50122 ssh2
```

`203.0.113.66` falló cientos de veces y acabó entrando: ésa es la brecha.

## 3. Bloquearla

```bash
echo "sshd: 203.0.113.66" | sudo tee -a /etc/hosts.deny
```

## 4. Documentar

```bash
echo "IP de la brecha: 203.0.113.66 (fuerza bruta -> Accepted password root)" > ~/hallazgos.txt
bash /opt/lab/check.sh
```

## Lecciones

- Distingue ruido (fallos) de brecha (`Accepted` tras muchos fallos). El triage
  prioriza la segunda.
- Defensa real: `fail2ban` (lab 20), deshabilitar password auth (lab 17), claves
  SSH, MFA, y limitar exposición del puerto 22.
- Tras una brecha por fuerza bruta, asume compromiso: revisa qué hizo esa sesión
  (procesos, cron, llaves, usuarios nuevos — labs 01, 02, 05).
