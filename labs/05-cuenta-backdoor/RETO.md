# Lab 05 — La cuenta que no debería existir

## Escenario

Durante una auditoría de `auth-prod-05` notas que hay **dos** cuentas con
privilegios de root. En Linux, "ser root" no es llamarse `root`: es tener
**UID 0**. Un atacante clásico se crea una segunda cuenta con UID 0 (así entra
como root aunque le quites la contraseña a `root`) y, por si acaso, se deja una
regla de `sudo` sin contraseña con otro nombre inocente.

## Objetivos

1. **Encuentra toda cuenta con UID 0** además de `root`. Pista: el tercer campo
   de `/etc/passwd` es el UID.
2. **Elimina la cuenta backdoor** (y su entrada en `/etc/shadow`). No borres `root`.
3. **Encuentra y elimina la regla de `sudo` sin contraseña** que el atacante dejó
   en `/etc/sudoers.d/` para una cuenta que no es de administración.

## Comandos que te pueden servir

```bash
awk -F: '$3==0 {print $1, $3}' /etc/passwd    # ¿quién tiene UID 0?
getent passwd | sort -t: -k3 -n
sudo userdel <cuenta>                          # borra usuario (deja su home)
ls -la /etc/sudoers.d/ ; cat /etc/sudoers.d/*
sudo visudo -c                                 # valida la sintaxis de sudo
```

> La cuenta `analista` (la tuya) tiene su propia regla legítima en
> `/etc/sudoers.d/analista`. **No la toques.** Busca la que sobra.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
