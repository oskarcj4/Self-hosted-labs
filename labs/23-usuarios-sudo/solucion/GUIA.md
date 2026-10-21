# Resolución guiada · Lab 23

:::piensa Antes de tocar nada
Mínimo privilegio significa preguntar, para cada cuenta: **¿qué necesita hacer exactamente?** y darle eso y nada más. `NOPASSWD:ALL` responde "todo, sin preguntar": cualquiera que robe esa cuenta es root en un segundo.
:::

## Paso 1 · Inventario de sudo

**Pregúntate:** ¿dónde se definen permisos de sudo? En `/etc/sudoers` y en cada fichero de `/etc/sudoers.d/`.

:::pista Cómo comprobarlo
```bash
sudo grep -r '' /etc/sudoers.d/
sudo -l -U devops
```
`sudo -l -U usuario` te dice qué puede hacer ese usuario, junte de donde junte los permisos.
:::

## Paso 2 · Quita el exceso

**Pregúntate:** ¿borro la regla o la cuenta? Lo pedido es quitar el permiso; borrar la cuenta es una decisión aparte.

:::pista Cómo hacerlo
```bash
sudo rm -f /etc/sudoers.d/devops
```
:::

## Paso 3 · Crea la cuenta nueva con lo justo

**Pregúntate:** ¿cómo se lee una regla de sudo? `usuario host=(como_quién) comandos`. ¿Qué pongo en cada hueco para que sólo pueda ejecutar un comando?

:::pista Cómo hacerlo
```bash
sudo useradd -m -s /bin/bash deploy
echo 'deploy ALL=(ALL) NOPASSWD: /usr/bin/apt-get update' | sudo tee /etc/sudoers.d/deploy
sudo chmod 440 /etc/sudoers.d/deploy
```
- Ruta **absoluta** del comando (si no, `deploy` podría crear su propio `apt-get`).
- `0440`: sudo ignora ficheros con permisos laxos.
:::

## Paso 4 · Valida siempre

```bash
sudo visudo -c
sudo -l -U deploy
bash /opt/lab/check.sh
```

:::ojo Un sudoers roto te deja sin sudo
Por eso existe `visudo`. Si escribes con `tee`, valida justo después con `visudo -c`. Mejor todavía: valida un fichero temporal con `visudo -cf` antes de ponerlo en su sitio (lo verás en el lab 36).
:::

## Cómo actuar en una situación así

- **Pregunta "qué necesita"** antes de dar permisos, y deja constancia del motivo (ticket, fecha).
- **Comandos exactos**, con ruta absoluta. Evita los que permiten escapar a una shell (`vi`, `less`, `find`, `tar`…).
- **Audita periódicamente** `sudo -l -U <cuenta>` para cada cuenta de servicio.

## Si te atascas

- `visudo -c` da error: mira la línea que indica. Un espacio de más tras `NOPASSWD:` no importa; una coma o dos puntos de menos sí.
