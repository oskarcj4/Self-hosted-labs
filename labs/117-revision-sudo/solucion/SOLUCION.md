# Solución — Revisión de sudo: comodines peligrosos

## Qué pasaba

- `deploy` tenía `NOPASSWD: /usr/bin/tee /etc/app/*`.
- A las 03:09 ejecutó `sudo tee /etc/app/../sudoers.d/99-mantenimiento` (el
  comodín casa con `..`) y escribió `soporte ALL=(ALL) NOPASSWD: ALL`.
- `soporte` entró desde la misma IP y abrió una shell de root con sudo.

## Arreglo

```bash
sudo grep COMMAND= /var/log/auth.log
sudo mkdir -p /root/evidencia && sudo cp -a /etc/sudoers.d/99-mantenimiento /root/evidencia/
sudo rm /etc/sudoers.d/99-mantenimiento
echo 'deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart app, sudoedit /etc/app/app.conf' \
  | sudo tee /etc/sudoers.d/10-deploy
sudo chmod 0440 /etc/sudoers.d/10-deploy
sudo visudo -c
sudo passwd -l soporte
nano ~/informe-sudo.txt
bash /opt/lab/check.sh
```

## Más allá del lab

- Rota las contraseñas de `deploy` y `soporte`; revisa qué hizo la shell de root.
- `Defaults use_pty, log_output` graba la sesión de cada comando sudo.
- Revisa todas las reglas con GTFOBins en la mano: `less`, `find`, `tar`,
  `awk`… todos dan shell.
