# Resolución guiada · Día 09

:::piensa Antes de tocar nada
La pregunta del enunciado es la clave de todo el reto: **¿quién abre realmente el `EnvironmentFile`?** Si crees que es el servicio, le darás permisos al usuario del servicio (de más). Si sabes que es systemd, verás que basta con mucho menos.
:::

## Paso 1 · ¿Qué está expuesto?

**Pregúntate:** ¿qué ficheros hay en la carpeta y quién puede leerlos? No te quedes con el fichero "oficial": busca copias.

:::pista Cómo comprobarlo
```bash
ls -la /etc/notifier/
cat /etc/notifier/notifier.env      # como analista: ¿lo lees?
sudo grep -rl 'SMTP_PASSWORD' /etc /opt /home /tmp 2>/dev/null
```
:::

## Paso 2 · ¿Quién lee el env file?

**Pregúntate:** `EnvironmentFile=` está en la unidad. ¿Quién procesa la unidad? systemd, que corre como root (PID 1). Lee el fichero **antes** de lanzar el proceso y le pasa las variables ya cargadas.

**Por qué importa:** el servicio nunca abre el fichero. Así que basta con que lo lea root: `0600 root:root`.

:::pista Cómo comprobarlo
```bash
systemctl show notifier -p User -p EnvironmentFiles
```
:::

## Paso 3 · Cierra el fichero y elimina la copia

:::pista Cómo hacerlo
```bash
sudo chown root:root /etc/notifier/notifier.env
sudo chmod 0600 /etc/notifier/notifier.env
sudo rm /etc/notifier/notifier.env.bak
```
Si hubiera que conservar la copia: `0600` y fuera de `/etc/notifier`.
:::

## Paso 4 · Demuestra que sigue funcionando

**Pregúntate:** el servicio ya estaba corriendo con las variables cargadas. ¿Eso demuestra algo? No: **reinícialo** para que systemd vuelva a leer el fichero con los permisos nuevos.

```bash
sudo systemctl restart notifier
curl -s http://127.0.0.1:8500/
cat /etc/notifier/notifier.env      # como analista: denegado
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Busca copias**: `.bak`, `.orig`, `~`, `.swp`, `.old` son la fuga de secretos más común.
- **No muevas los secretos a la unidad** (`Environment=`): las unidades son legibles por todos (`systemctl cat`).
- **Reinicia para probar**: un servicio que ya corre no demuestra que el arreglo funcione.
- Si estuvo expuesto: **rotar** las credenciales.

## Si te atascas

- El servicio no arranca tras el cambio: `journalctl -u notifier -n 20`. ¿Escribiste bien la ruta?
