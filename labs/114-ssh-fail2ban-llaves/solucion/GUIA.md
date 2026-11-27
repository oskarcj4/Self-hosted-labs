# Resolución guiada · Lab 114

:::piensa Dos defensas, y el orden importa
fail2ban **lee los logs** y banea la IP que falla demasiadas veces: para
funcionar necesita ver líneas `Failed password`. Quitar las contraseñas cierra
la puerta del todo. Si cierras primero, el bot deja de generar esas líneas y
no puedes comprobar que fail2ban funciona. Y antes de quitar las contraseñas,
asegúrate de que **tú** entras con llave, o te quedas fuera.
:::

**El plan:** (1) medir el ataque de ayer, (2) activar fail2ban y ver caer al
bot, (3) preparar tu llave, (4) desactivar las contraseñas y (5) comprobar.

## Paso 1 · ¿Cuánto ataque hubo ayer?

**Objetivo:** cuántos intentos fallidos hubo y qué IP insistió más. Son los
datos de `~/respuestas.txt`.

**Pregúntate:** ¿qué palabra aparece en cada intento fallido? ¿En qué parte
de la línea está la IP?

:::pista Cómo hacerlo
```bash
grep -m3 "Failed password" /var/log/auth.log.1
```
Hay dos formas de línea (`analista` está en el grupo `adm`, que puede leer
los logs, por eso no hace falta `sudo`):
```
… sshd[…]: Failed password for root from 185.220.101.7 port 51234 ssh2
… sshd[…]: Failed password for invalid user oracle from 185.220.101.7 port 40211 ssh2
```
Contando desde el principio, la IP no está siempre en la misma columna (la
segunda forma tiene dos palabras más). Pero contando **desde el final** sí:
`ssh2` es la última, `51234` la penúltima, `port` la antepenúltima y la IP,
la cuarta empezando por atrás.

```bash
grep -c "Failed password" /var/log/auth.log.1
grep "Failed password" /var/log/auth.log.1 | awk '{print $(NF-3)}' | sort | uniq -c | sort -rn | head
```

| Parte | Qué hace |
|---|---|
| `grep -c` | En vez de mostrar las líneas, **cuenta** cuántas coinciden. |
| `awk '{print $(NF-3)}'` | `NF` es el número de campos de la línea, así que `$NF` es el último y `$(NF-3)` el cuarto empezando por el final: la IP, sea cual sea la forma de la línea. |
| `sort \| uniq -c \| sort -rn` | Agrupa las IP iguales, las cuenta y las ordena de más a menos. |

**Qué deberías ver:** un total de varios cientos y, arriba del todo, la IP
con más intentos. Escríbelos:
```bash
nano ~/respuestas.txt
```
```
intentos=<el número de grep -c>
top=<la IP de arriba>
```
:::

## Paso 2 · fail2ban

**Objetivo:** que una IP que falla 3 veces quede bloqueada en el firewall,
automáticamente, y que fail2ban arranque solo tras un reinicio.

**Pregúntate:** fail2ban trae su configuración en `/etc/fail2ban/jail.conf`.
¿Por qué no se edita ese fichero?

:::pista Cómo hacerlo
Porque una actualización del paquete lo sobrescribe. Tus cambios van en
`jail.local`, que fail2ban lee **después** y que tiene prioridad:
```bash
sudo tee /etc/fail2ban/jail.local <<'J'
[sshd]
enabled  = true
backend  = auto
logpath  = /var/log/auth.log
maxretry = 3
findtime = 10m
bantime  = 1h
J
```

| Opción | Qué significa |
|---|---|
| `[sshd]` | La *jail* (vigilancia) de SSH. fail2ban ya trae el filtro que reconoce las líneas `Failed password` de sshd. |
| `enabled = true` | Actívala. |
| `backend = auto` + `logpath` | Lee los intentos del **fichero** `/var/log/auth.log`. En Debian 12 la alternativa, `backend = systemd`, busca la unidad `sshd.service`, pero aquí se llama `ssh.service` y fail2ban no vería nada. |
| `maxretry = 3` | Fallos permitidos… |
| `findtime = 10m` | …dentro de esta ventana de tiempo. 3 fallos en 10 minutos, baneo. |
| `bantime = 1h` | Cuánto dura el baneo. |

```bash
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban
sudo fail2ban-client status sshd
```
`enable` lo activa para los próximos arranques; `restart` lo (re)lanza ya con
la configuración nueva. `fail2ban-client status sshd` muestra el estado de la
jail.

**Qué deberías ver:** `File list: /var/log/auth.log`, `Total failed`
subiendo y, en unos segundos, la IP del bot en `Banned IP list`. Si `Total
failed` se queda en 0, fail2ban no está leyendo el log correcto.
:::

## Paso 3 · Tu llave, antes de cerrar

**Objetivo:** poder entrar sin contraseña **antes** de quitar las contraseñas.

**Pregúntate:** si desactivas las contraseñas ahora, ¿cómo entras tú?

:::pista Cómo hacerlo
```bash
ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys
```

| Parte | Qué hace |
|---|---|
| `ssh-keygen -t ed25519` | Crea un par de llaves de tipo Ed25519 (moderno, corto y rápido). |
| `-N ''` | Sin *passphrase*. En el lab hace falta: el validador entra sin poder escribir nada. En un caso real, ponle una y usa `ssh-agent`. |
| `-f ~/.ssh/id_ed25519` | Dónde guardarla: la privada en ese fichero, la pública en `…id_ed25519.pub`. |
| `>> ~/.ssh/authorized_keys` | Añade tu llave **pública** a la lista de llaves que pueden entrar en esta cuenta. `>>` añade al final sin borrar lo que hubiera. |
| `chmod 700` / `chmod 600` | sshd **ignora** `authorized_keys` si otros usuarios pueden escribir en él o en `~/.ssh`: alguien podría añadir su propia llave. |

Pruébala forzando que no use contraseña:
```bash
ssh -o PasswordAuthentication=no analista@127.0.0.1 true && echo "la llave funciona"
```
`-o PasswordAuthentication=no` desactiva la contraseña sólo para esta
conexión: si entra, es con la llave. `true` es el comando que ejecuta al otro
lado (no hace nada y sale con éxito). La primera vez te pregunta si confías en
la huella del servidor: responde `yes`.
:::

## Paso 4 · Sólo llaves

**Objetivo:** que sshd deje de aceptar contraseñas por cualquier vía.

**Pregúntate:** ¿qué ficheros lee sshd, y cuál gana si una opción aparece en
dos sitios?

:::pista Cómo hacerlo
```bash
sudo tee /etc/ssh/sshd_config.d/10-solo-llave.conf <<'C'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
C
```

| Opción | Qué significa |
|---|---|
| `PasswordAuthentication no` | No acepta contraseñas. |
| `KbdInteractiveAuthentication no` | Cierra la **otra** vía de contraseña: el modo "teclado interactivo", donde el servidor hace preguntas (normalmente, "Password:"). Si sólo cierras la primera, se puede seguir entrando por esta. |
| `PermitRootLogin prohibit-password` | root sólo puede entrar con llave. Es lo que el bot estaba atacando. |

**Por qué un fichero en `sshd_config.d/`:** el `sshd_config` de Debian empieza
con `Include /etc/ssh/sshd_config.d/*.conf`, y en sshd **gana el primer valor
que lee** de cada opción. Así tus líneas se imponen a las
`PasswordAuthentication yes` y `PermitRootLogin yes` que hay más abajo en
`sshd_config`, sin tocar ese fichero.

```bash
sudo sshd -t && sudo systemctl reload ssh
sudo sshd -T | grep -E 'passwordauth|kbdinteractive|permitroot'
```
- `sshd -t` (minúscula) comprueba la sintaxis. Si hay un error, el `&&`
  impide recargar y no te quedas con un sshd roto.
- `reload` aplica la configuración sin cortar las sesiones abiertas.
- `sshd -T` (mayúscula) imprime la configuración **efectiva**, después de
  juntar todos los ficheros. Es la forma de saber qué valor ha ganado.

**Qué deberías ver:** `passwordauthentication no`,
`kbdinteractiveauthentication no` y `permitrootlogin prohibit-password`
(algunas versiones lo muestran con su nombre antiguo, `without-password`: es
lo mismo).
:::

## Paso 5 · Comprueba

```bash
ssh -o PasswordAuthentication=no analista@127.0.0.1 true && echo "sigo entrando"
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Primero la llave, luego cerrar contraseñas**, y con otra sesión abierta
  mientras pruebas, por si algo sale mal.
- **`sshd -t` antes de recargar**; `sshd -T` para ver la configuración real.
- fail2ban reduce el ruido; las llaves eliminan el riesgo de contraseñas
  débiles. Son complementarias.
- Más allá: `AllowUsers`/`AllowGroups`, llaves con passphrase y, mejor aún,
  certificados SSH firmados por una CA.

## Si te atascas

- **fail2ban no banea:** en `fail2ban-client status sshd`, si `File list` está
  vacío falta `logpath`; si `Total failed` no sube, el log no es el correcto.
- **`sshd -T` sigue diciendo `passwordauthentication yes`:** tu fichero no
  acaba en `.conf` (el `Include` sólo carga `*.conf`) o hay otro fichero en
  `sshd_config.d/` que se lee antes. Búscalo con
  `grep -r Authentication /etc/ssh/sshd_config.d/`.
- **El check dice que analista no entra con llave:** revisa los permisos del
  paso 3, y que la llave no tenga passphrase.
