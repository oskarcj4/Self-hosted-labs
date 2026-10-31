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
:::

## Paso 2 · Cron de usuarios y de sistema

:::pista Cómo comprobarlo
```bash
for u in $(cut -d: -f1 /etc/passwd); do sudo crontab -l -u $u 2>/dev/null | sed "s/^/$u: /"; done
ls -la /etc/cron.d/; cat /etc/cron.d/*
```
`www-data` no debería tener crontab.
:::

## Paso 3 · Ficheros de inicio de sesión

**Pregúntate:** ¿qué se ejecuta cada vez que `deploy` abre una shell?

:::pista Cómo comprobarlo
```bash
sudo grep -n base64 /home/*/.bashrc /root/.bashrc
echo '<cadena>' | base64 -d          # decodifica, NO lo ejecutes
```
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
```bash
nano ~/iocs.txt
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
