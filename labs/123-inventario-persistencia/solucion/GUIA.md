# Resolución guiada · Lab 123

:::piensa Antes de tocar nada
Hay cinco formas de volver. Si quitas cuatro, el atacante vuelve por la quinta.
Primero haz el inventario completo; después límpialo todo de una vez.
:::

## Paso 1 · Servicios

**Pregúntate:** ¿qué unidades habilitadas no vienen de un paquete?

:::pista Cómo comprobarlo
```bash
systemctl list-unit-files --state=enabled --type=service
ls -la /etc/systemd/system/
dpkg -S /usr/lib/systemd/systemd-netlinkd    # ningún paquete
```
`dpkg -S <fichero>` dice qué paquete instaló ese fichero. Un binario con
nombre de sistema (`systemd-*`) que no pertenece a ningún paquete lo puso
alguien a mano. Lee la unidad para ver qué ejecuta: `systemctl cat
systemd-netlinkd`.
:::

## Paso 2 · Cron de usuarios y de sistema

:::pista Cómo comprobarlo
```bash
for u in $(cut -d: -f1 /etc/passwd); do sudo crontab -l -u $u 2>/dev/null | sed "s/^/$u: /"; done
ls -la /etc/cron.d/; cat /etc/cron.d/*
```
`crontab -l -u <usuario>` muestra el cron de cada usuario; el bucle recorre
todos los de `/etc/passwd` (`cut -d: -f1` toma el primer campo, el nombre) y
`sed` antepone el nombre a cada línea. Los cron de usuario no están en
`/etc/cron.d/`: viven aparte, por eso hay que preguntar uno a uno.
`www-data` (el usuario del servidor web) no debería tener crontab.
:::

## Paso 3 · Ficheros de inicio de sesión

**Pregúntate:** ¿qué se ejecuta cada vez que `deploy` abre una shell?

:::pista Cómo comprobarlo
```bash
sudo grep -n base64 /home/*/.bashrc /root/.bashrc
echo '<cadena>' | base64 -d          # decodifica, NO lo ejecutes
```
Una línea tipo `eval "$(echo … | base64 -d)"` ejecuta, en cada sesión, un
comando escondido en base64. `base64 -d` lo descodifica y lo muestra; sin
`eval` ni `| sh`, no se ejecuta.
:::

## Paso 4 · Llaves SSH

:::pista Cómo comprobarlo
```bash
sudo cat /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys
```
Una llave con comentario `backup@infra` que nadie reconoce.
:::

## Paso 5 · IOCs y limpieza

**Pregúntate:** ¿qué datos sirven para buscar lo mismo en otros servidores? Rutas, dominios, comentarios de llave.

:::pista Cómo hacerlo
Primero documenta: en `~/iocs.txt` una línea por punto de persistencia (la
unidad, el crontab de `www-data`, el fichero de `/etc/cron.d/`, el `.bashrc`
de `deploy`, la llave de `authorized_keys`) y los dominios que aparecen
(`cdn-update.example.net`, y el que sale al descodificar el base64).
```bash
nano ~/iocs.txt
```
Después guarda copia de lo que vas a borrar y limpia:
```bash
sudo mkdir -p /root/evidencia
sudo cp -a /etc/systemd/system/systemd-netlinkd.service /usr/lib/systemd/systemd-netlinkd \
  /etc/cron.d/apt-compat-check /var/lib/apt/.cache/update /root/evidencia/
sudo crontab -l -u www-data | sudo tee /root/evidencia/crontab-www-data >/dev/null
sudo systemctl disable --now systemd-netlinkd.service
sudo rm -f /etc/systemd/system/systemd-netlinkd.service /usr/lib/systemd/systemd-netlinkd
sudo systemctl daemon-reload
sudo crontab -r -u www-data
sudo rm -f /etc/cron.d/apt-compat-check; sudo rm -rf /var/lib/apt/.cache
sudo sed -i '/base64 -d/d' /home/deploy/.bashrc
sudo sed -i '/backup@infra/d' /root/.ssh/authorized_keys
```
No borres el `.bashrc` entero ni las llaves legítimas.
:::

## Cómo actuar en una situación así

- **Lista de comprobación**: systemd (unidades y timers), cron (todos los sitios), ficheros de shell, `authorized_keys`, `/etc/rc.local`, `ld.so.preload`, usuarios nuevos.
- **Nombres que imitan al sistema** (`systemd-*`, `apt-*`): verifica con `dpkg -S`.
- Comparte los IOCs para buscar en toda la flota.

## Si te atascas

- El check sigue viendo un punto: revisa la lista de nuevo; probablemente falta `crontab -l -u www-data`.
- `base64 -d` da basura: copia sólo la cadena, sin comillas.
