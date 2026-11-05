# Resolución guiada · Lab 148

:::piensa La verdad la tiene RRHH
No decides tú quién debe tener acceso: lo dice `altas-bajas.txt`. Tu trabajo es
que el sistema coincida con esa lista. Todo lo que sobra, fuera.
:::

## Paso 1 · Cruza personas

:::pista Cómo comprobarlo
```bash
cat /etc/iam/altas-bajas.txt
cut -d: -f1,7 /etc/passwd | grep -vE 'nologin|/false'
```
`tyrell` y `scripted` están de BAJA pero tienen shell. Bloquéalos.
:::

## Paso 2 · Cruza llaves

**Pregúntate:** ¿qué llave de los `authorized_keys` no está en la lista aprobada?

:::pista Cómo comprobarlo
```bash
cat /etc/iam/llaves-aprobadas.txt
sudo find /home /root -name authorized_keys -exec grep -H '' {} +
sudo sed -i '/darkarmy@exfil/d' /home/*/.ssh/authorized_keys
```
No borres `ops@allsafe`.
:::

## Paso 3 · Cruza sudo

:::pista Cómo comprobarlo
```bash
sudo ls -l /etc/sudoers.d/
sudo rm /etc/sudoers.d/tyrell && sudo visudo -c
```
:::

## Paso 4 · Documenta

:::pista Cómo hacerlo
`~/revocados.txt` con una línea por cosa revocada: las 2 cuentas, la llave y el
sudoers. El informe es parte del control.
:::

## Cómo actuar en una situación así

- Revocar = cuenta + llaves + sudo + grupos + tokens. Olvidar una vía es dejar
  la puerta entornada.
- Lo barato es automatizarlo (joiner/mover/leaver); lo caro es el acceso que
  nadie quitó.

## Si te atascas

- El validador sigue viendo la llave: ¿la quitaste de *todos* los
  `authorized_keys` (deploy *y* tyrell)?
- No borres `deploy`: es cuenta de servicio activa (ALTA).
