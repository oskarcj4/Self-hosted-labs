# Resolución guiada · Lab 05

:::piensa Antes de tocar nada
Para el kernel, el nombre de usuario no existe: sólo existen números. Ser root es tener **UID 0**. Si alguien quiere ser root sin llamarse root, le basta con crear otra cuenta con UID 0. Y si quiere un plan B, una regla de `sudo` sin contraseña con un nombre aburrido.
:::

## Paso 1 · ¿Quién es root de verdad?

**Pregúntate:** ¿dónde está el UID de cada cuenta? En `/etc/passwd`, campos separados por `:`; el tercero es el UID.

**Por qué importa:** cualquier cuenta con UID 0 que no sea `root` es, casi siempre, una puerta trasera.

:::pista Cómo comprobarlo
```bash
awk -F: '$3==0 {print $1, $3, $7}' /etc/passwd
```
Si sale más de una línea, ya tienes al sospechoso. Fíjate en el nombre: suele imitar una cuenta de servicio.
:::

## Paso 2 · Elimínala sin romper nada

**Pregúntate:** ¿qué ficheros guardan rastro de una cuenta? `/etc/passwd` (identidad) y `/etc/shadow` (contraseña).

**Por qué importa:** si quitas sólo una de las dos, queda basura o la cuenta sigue activa a medias.

:::pista Cómo hacerlo
```bash
sudo userdel <cuenta>
grep <cuenta> /etc/passwd /etc/shadow || echo "sin rastro"
```
Si `userdel` falla, edita con `sudo vipw` y `sudo vipw -s` (bloquean el fichero mientras editas).
:::

:::ojo No borres root
Comprueba dos veces el nombre antes de pulsar Enter. `userdel root` te deja sin sistema.
:::

## Paso 3 · El plan B: sudo

**Pregúntate:** ¿dónde puede esconderse una regla de sudo? En `/etc/sudoers` y en **cada fichero** de `/etc/sudoers.d/`.

**Por qué importa:** `NOPASSWD:ALL` para una cuenta cualquiera equivale a otra cuenta root.

:::pista Cómo comprobarlo
```bash
sudo ls -la /etc/sudoers.d/
sudo grep -r '' /etc/sudoers.d/
```
Tu cuenta (`analista`) tiene una regla legítima. Busca la que da `ALL` sin contraseña a otra cuenta que no sea de administración. Bórrala y valida:
```bash
sudo rm -f /etc/sudoers.d/<fichero>
sudo visudo -c
bash /opt/lab/check.sh
```
:::

## Cómo actuar en una situación así

- **Audita por UID, no por nombre**: `awk -F: '$3==0'` en cada revisión.
- **sudoers.d es un sitio clásico para esconder persistencia**: un fichero más entre varios legítimos pasa desapercibido.
- Después de tocar sudo, **siempre** `visudo -c`.
- En un caso real, revisa también qué hizo esa cuenta: `last`, `lastlog`, su home y sus claves SSH.

## Si te atascas

- `awk` sólo muestra root: mira también `getent passwd | sort -t: -k3 -n | head`.
- No sabes cuál de las reglas de sudo es la mala: la tuya es la de `analista`; la otra no debería existir.
