# Lab 14 — Triage: ¿quién reventó el SSH a fuerza bruta?

## Escenario

`bastion-14` recibió un ataque de fuerza bruta contra SSH durante la noche. El
`auth.log` está lleno de intentos fallidos desde muchas IPs, pero **una** de
ellas, tras cientos de fallos, **acabó entrando** (`Accepted password`). Ésa es
la que importa: ya no es ruido, es una brecha. Haz el triage, identifícala y
bloquéala.

## Objetivos

1. **Cuenta los intentos fallidos por IP** y hazte una idea del ataque.
2. **Encuentra la IP que logró entrar** (`Accepted password` tras muchos fallos).
3. **Bloquéala** en `/etc/hosts.deny` con la sintaxis de TCP wrappers
   (`sshd: <IP>`).
4. **Documenta en `~/hallazgos.txt`** la IP que logró la brecha.

## Comandos que te pueden servir

```bash
grep 'Failed password' /var/log/auth.log | grep -oE 'from [0-9.]+' \
  | awk '{print $2}' | sort | uniq -c | sort -rn | head
grep 'Accepted password' /var/log/auth.log       # ¿quién entró?
echo "sshd: <IP>" | sudo tee -a /etc/hosts.deny
```

> El pico de fallos te dice quién hizo ruido; `Accepted password` te dice quién
> ganó. Bloquea al que ganó (y revisa qué hizo después).

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
