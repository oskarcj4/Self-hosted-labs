# Resolución guiada · Lab 117

:::piensa Antes de tocar nada
Una regla sudo con comodín no autoriza "ficheros dentro de /etc/app": autoriza
cualquier texto que case con el patrón. Y `..` es texto.
:::

## Paso 1 · ¿Qué se ejecutó con sudo?

**Pregúntate:** ¿qué deja sudo en el log cada vez que alguien lo usa?

:::pista Cómo comprobarlo
```bash
sudo grep -E 'sudo:|sshd.*Accepted' /var/log/auth.log
```
Cada línea `COMMAND=` dice quién, desde qué TTY y qué comando exacto.
:::

## Paso 2 · ¿Cómo lo permitió la regla?

**Pregúntate:** la regla de `deploy` dice `/usr/bin/tee /etc/app/*`. ¿Casa `/etc/app/../sudoers.d/99-mantenimiento`?

:::pista Cómo comprobarlo
```bash
sudo cat /etc/sudoers.d/*
sudo -l -U deploy
sudo -l -U soporte
```
:::

## Paso 3 · Cierra la puerta

**Pregúntate:** ¿qué permiso necesita `deploy` de verdad? Reiniciar la app y editar su configuración. ¿Hay forma de editar un fichero como root sin dar un editor de root?

:::pista Cómo hacerlo
```bash
sudo mkdir -p /root/evidencia && sudo cp -a /etc/sudoers.d/99-mantenimiento /root/evidencia/
sudo rm /etc/sudoers.d/99-mantenimiento
sudo visudo -f /etc/sudoers.d/10-deploy
#   deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart app, sudoedit /etc/app/app.conf
sudo chmod 0440 /etc/sudoers.d/10-deploy
sudo visudo -c
sudo passwd -l soporte
```
`sudoedit` copia el fichero, lo abre con tu editor como **tu** usuario y lo vuelve a escribir.
:::

## Paso 4 · Cuéntalo

:::pista Qué anotar en ~/informe-sudo.txt
Hora de entrada de `deploy` e IP, el comando `tee` con `..`, la regla creada para
`soporte`, la shell de root y las acciones tomadas.
:::

## Cómo actuar en una situación así

- **Nunca comodines en rutas** de sudo, y nunca `tee`, `cp`, editores o intérpretes como root.
- **`sudoedit`** para editar; rutas absolutas y argumentos fijos para comandos.
- `sudoers.d` con permisos `0440` y validado con `visudo -c`.

## Si te atascas

- `visudo -c` da "bad permissions": `chmod 0440` al fichero.
- `sudo -l -U soporte` sigue mostrando ALL: queda otro fichero en `sudoers.d`.
