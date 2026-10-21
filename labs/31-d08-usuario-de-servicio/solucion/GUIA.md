# Resolución guiada · Día 08

:::piensa Antes de tocar nada
Cambiar el usuario de un servicio es fácil (una línea). Lo difícil es que **siga funcionando**, porque todo lo que tocaba como root ahora puede estar fuera de su alcance. El método: **hacer inventario de qué usa el servicio** antes de cambiar su identidad.
:::

## Paso 1 · ¿Qué usa hoy?

**Pregúntate:** ¿qué ficheros y carpetas lee y escribe el servicio? Mira la unidad, su configuración y lo que el enunciado te dice.

:::pista Cómo comprobarlo
```bash
systemctl cat reportd
ps -o user,pid,cmd -C reportd
ls -ld /var/lib/reportd/reports /var/log/reportd
ls -l /etc/reportd/reportd.conf
```
Haz una lista: **escribe en** … / **lee** …
:::

## Paso 2 · Crea la identidad

**Pregúntate:** ¿qué distingue a un usuario de servicio de uno de persona? UID de sistema (< 1000), sin shell de login, sin contraseña, sin grupos extra.

:::pista Cómo hacerlo
```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin reportd
id reportd
```
:::

## Paso 3 · Dale sólo lo que necesita

**Pregúntate:** ¿lo que escribe debe ser **suyo**? Sí. ¿Lo que sólo lee (configuración) debe ser suyo? No: basta con que pueda leerlo, así no puede modificarlo.

:::pista Cómo hacerlo
```bash
sudo chown -R reportd:reportd /var/lib/reportd /var/log/reportd
sudo chown root:reportd /etc/reportd/reportd.conf
sudo chmod 0640 /etc/reportd/reportd.conf
```
:::

## Paso 4 · Cambia la unidad con un drop-in

**Pregúntate:** ¿por qué no editar la unidad original? Porque una actualización del paquete la sobrescribiría. Un drop-in (`.service.d/*.conf`) se suma a la original y sobrevive.

:::pista Cómo hacerlo
```bash
sudo mkdir -p /etc/systemd/system/reportd.service.d
printf '[Service]\nUser=reportd\nGroup=reportd\n' | sudo tee /etc/systemd/system/reportd.service.d/user.conf
sudo systemctl daemon-reload
sudo systemctl restart reportd
```
:::

## Paso 5 · Verifica y, si falla, lee el log

```bash
ps -o user,pid,cmd -C reportd
curl -s http://127.0.0.1:8400/health
bash /opt/lab/check.sh
```
Si no arranca: `journalctl -u reportd -n 20 --no-pager` te dirá la ruta exacta del `PermissionError`.

## Cómo actuar en una situación así

- **Inventario antes que cambio**: lista lo que lee y lo que escribe.
- **Propiedad para lo que escribe, lectura para lo que lee.**
- **Drop-ins** en lugar de editar unidades de paquete.
- Siguiente nivel: `NoNewPrivileges=yes`, `ProtectSystem=strict`, `ReadWritePaths=`.

## Si te atascas

- El servicio cae con `PermissionError`: el journal te da la ruta. Esa ruta falta en tu lista del paso 1.
