# Resolución guiada · Lab 14

:::piensa Antes de tocar nada
Cualquier SSH expuesto a internet recibe intentos fallidos a diario: eso es **ruido**. Lo que convierte el ruido en incidente es un **éxito**. El triage consiste en no perderse en miles de fallos y encontrar la línea que importa.
:::

## Paso 1 · Mide el ataque

**Pregúntate:** ¿cuántos intentos y desde cuántas IPs? Necesitas una foto general.

:::pista Cómo comprobarlo
```bash
grep -c 'Failed password' /var/log/auth.log
grep 'Failed password' /var/log/auth.log | grep -oE 'from [0-9.]+' \
  | awk '{print $2}' | sort | uniq -c | sort -rn | head
```
:::

## Paso 2 · ¿Alguien ganó?

**Pregúntate:** ¿qué línea deja SSH cuando un login **funciona**?

**Por qué importa:** es la única que cambia tu prioridad de "molestia" a "brecha".

:::pista Cómo comprobarlo
```bash
grep 'Accepted' /var/log/auth.log
```
Cruza la IP de esa línea con la tabla del paso 1. ¿Es una de las que más falló? Eso es una fuerza bruta **con éxito**. ¿Con qué usuario entró?
:::

## Paso 3 · Contén

**Pregúntate:** ¿qué hago primero, bloquear o investigar? Primero contener (bloquear), después investigar qué hizo.

:::pista Cómo hacerlo
```bash
echo "sshd: <IP>" | sudo tee -a /etc/hosts.deny
echo "IP de la brecha: <IP> (fuerza bruta -> Accepted)" > ~/hallazgos.txt
bash /opt/lab/check.sh
```
:::

## Cómo actuar en una situación así

- **Ruido vs. brecha**: prioriza siempre `Accepted` después de muchos `Failed`.
- **Tras una brecha, asume compromiso**: revisa qué hizo la sesión (procesos, cron, claves, usuarios nuevos — labs 01, 02, 05).
- **Arregla la causa**: si entró por contraseña, desactiva la autenticación por contraseña (lab 17) y pon fail2ban (lab 20).
- Bloquear sólo la IP ganadora es contención, no solución: el atacante puede cambiar de IP.

## Si te atascas

- La tabla sale vacía: revisa el patrón `Failed password` (mayúsculas).
