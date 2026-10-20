# Lab 23 — Mínimo privilegio: usuarios y sudo

## Escenario (tarea de hardening)

En `ops-23` alguien, "para ir rápido", le dio a la cuenta `devops` **sudo total
sin contraseña** (`ALL=(ALL) NOPASSWD:ALL`). Eso es una bomba: cualquier
compromiso de esa cuenta es root instantáneo. Aplica el principio de **mínimo
privilegio**: quita ese permiso excesivo y crea una cuenta de despliegue que sólo
pueda ejecutar **un** comando concreto con sudo.

## Objetivos

1. **Quita el permiso excesivo** de `devops` (su regla en `/etc/sudoers.d/`).
2. **Crea el usuario** `deploy`.
3. **Da a `deploy` sudo SÓLO para un comando**: `/usr/bin/apt-get update`
   (sin contraseña). Nada más.
4. La configuración de sudo debe seguir siendo válida (`visudo -c`).

## Comandos que te pueden servir

```bash
sudo grep -r '' /etc/sudoers.d/            # mira las reglas actuales
sudo rm -f /etc/sudoers.d/devops           # quita el permiso excesivo
sudo useradd -m -s /bin/bash deploy
echo 'deploy ALL=(ALL) NOPASSWD: /usr/bin/apt-get update' | \
  sudo tee /etc/sudoers.d/deploy
sudo chmod 440 /etc/sudoers.d/deploy
sudo visudo -c                              # valida TODA la config de sudo
```

> Regla de sudo = `usuario host=(runas) comandos`. Limita siempre la lista de
> comandos; `ALL` al final es "cualquier cosa" y rara vez es necesario.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
