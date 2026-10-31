# Revisión de sudo: el comando de madrugada

> Defensa del host · sudoers · auth.log · mínimo privilegio

## Escenario

El SIEM marca un `sudo` de madrugada en `app-117` que nadie del equipo
reconoce, y hay una regla `NOPASSWD` que no está en el repositorio de
configuración (`~/ticket/INC-117.txt`). No basta con borrar la regla: si no
entiendes **cómo** llegó ahí, vuelve mañana.

## Objetivos

1. Encuentra en `auth.log` los comandos ejecutados con sudo y separa lo
   normal de lo de madrugada.
2. Revisa `/etc/sudoers.d/` y los permisos efectivos de cada usuario.
3. Explica cómo se creó la regla nueva (pista: lee con lupa la regla que
   ya tenía `deploy`).
4. Corrige:
   - fuera la regla nueva; `soporte` sin sudo y con la cuenta bloqueada;
   - `deploy` puede seguir reiniciando la app y editando
     `/etc/app/app.conf`, pero **sin comodines** (ruta exacta o `sudoedit`);
   - `visudo -c` limpio.
5. Escribe la cadena completa en `~/informe-sudo.txt`: quién entró, desde qué
   IP, a qué hora, qué comandos y qué fichero creó.

## Comandos que te pueden servir

```bash
grep COMMAND= /var/log/auth.log
grep -E 'Accepted|COMMAND=' /var/log/auth.log
ls -la /etc/sudoers.d/ ; sudo cat /etc/sudoers.d/*
sudo -l -U deploy ; sudo -l -U soporte
sudo visudo -c ; sudo visudo -f /etc/sudoers.d/10-deploy
last ; lastlog          # en un contenedor wtmp suele estar vacío
sudo passwd -l soporte
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
