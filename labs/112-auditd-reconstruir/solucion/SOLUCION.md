# Solución — Reconstruir una intrusión con auditd

## Qué pasaba

- `becario` entró por SSH desde `203.0.113.45`, subió a root y:
  - dio contraseña y shell a la cuenta de servicio `backup` (`usermod`), que
    escribe en `/etc/shadow` (clave `claves`);
  - añadió `backup ALL=(ALL) NOPASSWD:ALL` a `/etc/sudoers` (clave `sudoers`).
- El operador legítimo sólo ejecutó `chage -M 90`: también toca `shadow`, pero
  su `auid` es otro. Es ruido, no incidente.

## Arreglo

```bash
sudo ausearch -k claves -i  | grep -E 'auid=|proctitle'
sudo ausearch -k sudoers -i | grep -E 'auid=|proctitle'
nano ~/hallazgos.txt

sudo sed -i '/^backup .*NOPASSWD/d' /etc/sudoers && sudo visudo -c
sudo usermod -s /usr/sbin/nologin -p '*' backup

sudo tee /etc/audit/rules.d/50-claves.rules <<'R'
-w /etc/shadow -p wa -k claves
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers
R
sudo augenrules --load; sudo augenrules --check
bash /opt/lab/check.sh
```

## Más allá del lab

- Envía `audit.log` a un servidor central (audisp-remote, SIEM): el intruso
  con root puede borrar el local.
- Añade `-a always,exit -F arch=b64 -S execve -F euid=0 -k root-cmd` para
  registrar cada comando ejecutado como root.
- Bloquea `becario` y rota las contraseñas que pudo leer.
