# Lab 01 — Hay un intruso en tu servidor SSH

Inspirado en los videos de @terminalcero *"Cómo expulsarlo en 60s"* y *"03:14 AM: el hacker seguía dentro"*.

## Escenario

Eres el analista de guardia de `prod-web-01`. Alguien consiguió acceso SSH a la
cuenta `analista` y, aunque crees que ya cambiaste la contraseña, el atacante
**sigue pudiendo volver a entrar**. Sabes que la gente que entra a un servidor
deja mecanismos de persistencia: llaves, trampas en los archivos de arranque de
la shell, etc.

## Objetivos

1. **Averigua desde qué IP entró el intruso.** (Pista: los accesos SSH quedan registrados.)
2. **Encuentra y elimina la llave del atacante** que le permite entrar sin contraseña.
3. **Encuentra y neutraliza la trampa** que dejó en los archivos de arranque de tu shell,
   y borra el payload que esa trampa ejecuta.
4. **Bloquea la IP del atacante** para que no pueda ni intentar reconectar
   (usa `/etc/hosts.deny` con la sintaxis de TCP wrappers: `sshd: <IP>`).

## Comandos que te pueden servir

```bash
cat /var/log/auth.log            # ¿quién entró y desde dónde?
cat ~/.ssh/authorized_keys       # ¿qué llaves tienen acceso?
cat ~/.bashrc                    # ¿hay algo raro al final?
grep -r source ~/.bashrc /etc/bash.bashrc
ls -la /dev/shm                  # los atacantes esconden cosas en memoria
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```

El validador revisa los 4 objetivos y te dice qué falta.
