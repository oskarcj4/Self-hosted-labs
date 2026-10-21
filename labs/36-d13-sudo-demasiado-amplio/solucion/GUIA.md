# Resolución guiada · Día 13

:::piensa Antes de tocar nada
Para reducir privilegios no basta con mirar la regla obvia. Pregúntate: **¿por cuántos caminos puede `deploy` llegar a root?** Una regla de sudoers, un grupo administrativo, un script que puede editar y que ejecuta como root… Cada uno es una puerta. Cierra todas menos la que necesita.
:::

## Paso 1 · Inventario de caminos

**Pregúntate:** ¿qué me dice sudo de este usuario, juntando todas las fuentes?

:::pista Cómo comprobarlo
```bash
sudo -l -U deploy
id deploy
ls -l /etc/sudoers.d/
ls -l /usr/local/sbin/rotate-app-logs
```
Cuenta las vías: ¿una regla propia? ¿un grupo (`sudo`, `admin`, `wheel`)? ¿el script es de `deploy` o escribible por él?
:::

## Paso 2 · La regla mínima

**Pregúntate:** ¿cómo restrinjo cada parte de la regla?

- **Como quién**: `(root)` en vez de `(ALL)`.
- **Qué**: ruta absoluta exacta.
- **Argumentos**: `""` al final = ninguno permitido.
- **Sin contraseña**: el pipeline no es interactivo.

:::pista Cómo hacerlo (validando antes de activar)
```bash
echo 'deploy ALL=(root) NOPASSWD: /usr/local/sbin/rotate-app-logs ""' \
  | sudo tee /etc/sudoers.d/40-deploy.tmp >/dev/null
sudo visudo -cf /etc/sudoers.d/40-deploy.tmp \
  && sudo install -m 0440 /etc/sudoers.d/40-deploy.tmp /etc/sudoers.d/40-deploy \
  && sudo rm /etc/sudoers.d/40-deploy.tmp /etc/sudoers.d/40-deploy-temp
```
Validar **antes** de dejarlo en su sitio evita romper sudo para todos.
:::

## Paso 3 · Fuera del grupo

:::pista Cómo hacerlo
```bash
sudo gpasswd -d deploy sudo
```
:::

## Paso 4 · La trampa del script

**Pregúntate:** si `deploy` puede editar el script que ejecuta como root, ¿qué impide que escriba "dame una shell" dentro? Nada. Ese script tiene que ser **de root** y no escribible por otros.

:::pista Cómo hacerlo
```bash
sudo chown root:root /usr/local/sbin/rotate-app-logs
sudo chmod 0755 /usr/local/sbin/rotate-app-logs
```
:::

## Paso 5 · Prueba como `deploy`

```bash
sudo visudo -c
sudo -l -U deploy
sudo runuser -u deploy -- sudo -n /usr/local/sbin/rotate-app-logs    # funciona
sudo runuser -u deploy -- sudo -n cat /etc/shadow                    # denegado
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Enumera todos los caminos a root**: reglas, grupos, ficheros editables que root ejecuta.
- **Regla mínima** = usuario + como quién + comando exacto + argumentos.
- **Lo "temporal" lleva fecha y ticket**; si no, es permanente.
- Comandos que abren un editor, `less`, `find -exec`… equivalen a `ALL`. Consulta GTFOBins.

## Si te atascas

- `sudo -l -U deploy` sigue mostrando `(ALL : ALL) ALL`: viene del grupo `sudo`.
- La prueba como `deploy` pide contraseña: falta `NOPASSWD:` o la ruta no coincide exactamente.
