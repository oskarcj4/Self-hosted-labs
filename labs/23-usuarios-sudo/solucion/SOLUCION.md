# Solución — Lab 23

## 1. Quitar el permiso excesivo de devops

```bash
sudo grep -r '' /etc/sudoers.d/
# /etc/sudoers.d/devops:  devops ALL=(ALL) NOPASSWD:ALL
sudo rm -f /etc/sudoers.d/devops
```

(Si quieres, elimina también la cuenta: `sudo userdel -r devops`.)

## 2. Crear el usuario deploy

```bash
sudo useradd -m -s /bin/bash deploy
```

## 3. sudo limitado a un solo comando

```bash
echo 'deploy ALL=(ALL) NOPASSWD: /usr/bin/apt-get update' | sudo tee /etc/sudoers.d/deploy
sudo chmod 440 /etc/sudoers.d/deploy
```

Ahora `deploy` sólo puede `sudo apt-get update`, nada más.

## 4. Validar

```bash
sudo visudo -c
bash /opt/lab/check.sh
```

## Lecciones

- Mínimo privilegio: cada cuenta sólo con lo que necesita. `NOPASSWD:ALL` convierte
  cualquier compromiso de esa cuenta en root inmediato.
- Limita la lista de comandos en sudoers; evita `ALL` y ojo con comandos que
  permiten escapar a una shell (`vi`, `less`, `find -exec`…).
- Edita siempre con `visudo`/`visudo -f` (valida antes de guardar); un sudoers
  roto puede dejarte sin sudo.
