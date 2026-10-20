# 04 · Usuarios, grupos y permisos

> Qué es una cuenta para el kernel (un número, no un nombre), cómo leer `rwx` y los permisos en octal, los bits especiales SUID, SGID y sticky, y los atributos que ni root puede saltarse sin quitarlos antes.

## 1. Una cuenta es un número

Para el kernel no existen "root" ni "analista": existen **UIDs** (identificador de usuario) y **GIDs** (identificador de grupo). El nombre es una etiqueta que traduce `/etc/passwd`.

| UID | Quién suele ser |
|---|---|
| `0` | root. Todo proceso con UID 0 se salta las comprobaciones de permisos |
| `1` a `999` | Cuentas de sistema y de servicio (`www-data`, `sshd`, `nobody`…) |
| `1000` en adelante | Personas |

La consecuencia importante: **cualquier** línea de `/etc/passwd` con un `0` en el tercer campo es root, se llame como se llame. Dos cuentas con UID 0 son dos llaves de la misma puerta.

```bash
id                     # tu uid, gid y grupos
id www-data            # los de otra cuenta
getent passwd analista # la línea de passwd (también ve cuentas de LDAP, etc.)
```

### Los ficheros de cuentas

| Fichero | Contiene | Quién lo lee |
|---|---|---|
| `/etc/passwd` | Usuario, UID, GID, home, shell (7 campos con `:`) | Todos |
| `/etc/shadow` | Hash de la contraseña, caducidad | Sólo root |
| `/etc/group` | Grupos y sus miembros | Todos |
| `/etc/gshadow` | Contraseñas de grupo (casi nunca se usan) | Sólo root |

Leer la línea de `shadow`: `usuario:HASH:...`. En el campo del hash, `!` o `*` significa "no se puede entrar con contraseña". Un hash que empieza por `$6$` es SHA-512, `$y$` es yescrypt. Un campo **vacío** significa "sin contraseña": peligroso.

### Crear, modificar y borrar cuentas

```bash
sudo useradd -m -s /bin/bash nombre   # -m crea el home, -s fija la shell
sudo passwd nombre                    # pone contraseña
sudo usermod -aG grupo nombre         # AÑADE a un grupo (-a es vital: sin él, reemplaza todos)
sudo usermod -L nombre                # bloquea la contraseña (añade ! al hash)
sudo usermod -s /usr/sbin/nologin nombre   # sin shell interactiva
sudo userdel nombre                   # borra la cuenta (deja el home)
sudo userdel -r nombre                # y también el home y el buzón
```

`userdel` edita a la vez `passwd`, `shadow`, `group` y `gshadow`, y comprueba que el fichero queda consistente. Editar `/etc/passwd` a mano con un editor funciona, pero puedes dejar la entrada de `shadow` huérfana. Si tienes que editarlo a mano, usa `sudo vipw` y `sudo vipw -s`, que bloquean el fichero mientras editas.

> Trampa: `userdel` se niega a borrar una cuenta que tiene procesos corriendo, y si dos cuentas comparten UID 0 puede confundir a cuál te refieres por el nombre. Lee el mensaje de error: suele decirte exactamente qué pasa. Comprueba después con `getent passwd` y `grep` en `shadow` que no queda rastro.

## 2. Permisos: leer `ls -l`

```
-rwxr-x---  1 root  backup  8120 Oct 20 03:14 script.sh
│└┬┘└┬┘└┬┘     └┬─┘  └─┬──┘
│ │  │  │       │      └ grupo dueño
│ │  │  │       └ usuario dueño
│ │  │  └ otros (o): ---  nada
│ │  └ grupo (g):    r-x  leer y ejecutar
│ └ usuario (u):     rwx  todo
└ tipo: - fichero, d carpeta, l enlace simbólico
```

El kernel comprueba **una sola** clase, en este orden: si eres el dueño, aplica `u`; si no, si estás en el grupo, aplica `g`; si no, `o`. No se suman.

### Qué significa cada letra

| Letra | En un fichero | En una carpeta |
|---|---|---|
| `r` | Leer el contenido | Listar los nombres que contiene |
| `w` | Modificar el contenido | Crear, borrar y renombrar entradas dentro |
| `x` | Ejecutarlo | Entrar (`cd`) y acceder a lo que hay dentro |

Dos consecuencias que sorprenden:

- **Borrar un fichero depende de la carpeta, no del fichero.** Si tienes `w` en la carpeta, puedes borrar un fichero de root que esté dentro (salvo sticky bit, ver abajo).
- Para leer `/a/b/c.txt` necesitas `x` en `/a` y en `/a/b`, además de `r` en el fichero. `namei -l /a/b/c.txt` muestra los permisos de cada tramo de la ruta.

### Octal: la notación de los números

Cada clase es un número de 0 a 7, suma de `r=4`, `w=2`, `x=1`.

| Octal | Letras | Uso típico |
|---|---|---|
| `755` | `rwxr-xr-x` | Programas y carpetas públicas |
| `644` | `rw-r--r--` | Ficheros de configuración normales |
| `640` | `rw-r-----` | Config legible por un grupo de servicio |
| `600` | `rw-------` | Secretos, claves privadas |
| `700` | `rwx------` | Carpetas privadas (`~/.ssh`) |
| `440` | `r--r-----` | Ficheros de `sudoers.d` |
| `777` | `rwxrwxrwx` | Casi nunca es la respuesta correcta |

```bash
chmod 640 fichero            # octal
chmod u+x,g-w,o= fichero     # simbólico: añade x al dueño, quita w al grupo, deja otros vacío
chown usuario:grupo fichero  # cambia dueño y grupo
chgrp grupo fichero          # sólo el grupo
chmod -R ...                 # recursivo: cuidado, aplica lo mismo a ficheros y carpetas
stat -c '%a %U:%G %n' fichero   # permisos en octal, dueño y nombre
```

### umask: los permisos de lo que se crea

`umask` resta permisos a los ficheros nuevos. Con `umask 022` un fichero nuevo sale `644` y una carpeta `755`. Con `umask 077` salen `600` y `700`. Es la razón de que un servicio cree ficheros legibles por todos aunque nadie lo pidiera.

## 3. Los bits especiales

Hay un cuarto dígito octal delante: `4` SUID, `2` SGID, `1` sticky.

| Bit | Se ve como | En un fichero ejecutable | En una carpeta |
|---|---|---|---|
| SUID (`4000`) | `s` en la x del dueño: `-rwsr-xr-x` | Se ejecuta con el UID del **dueño**, no de quien lo lanza | Sin efecto en Linux |
| SGID (`2000`) | `s` en la x del grupo: `-rwxr-sr-x` | Se ejecuta con el GID del grupo dueño | Lo creado dentro hereda el grupo de la carpeta |
| Sticky (`1000`) | `t` en la x de otros: `drwxrwxrwt` | Sin efecto | Sólo el dueño de un fichero puede borrarlo, aunque otros tengan `w` en la carpeta |

Una `S` o `T` mayúscula significa "el bit está puesto pero falta la `x` debajo": normalmente un error de configuración.

### Por qué SUID es tan delicado

`passwd` necesita escribir en `/etc/shadow`, que es de root. Por eso `/usr/bin/passwd` es SUID root: cualquiera lo ejecuta y, durante esa ejecución, el proceso es root. Es seguro sólo porque `passwd` está escrito para hacer **una** cosa concreta.

Ahora imagina un programa SUID root que acepte comandos arbitrarios: una shell, un intérprete, un editor. Quien lo ejecute obtiene root sin contraseña. Por eso:

- La lista de SUID legítimos en un Debian es corta y conocida: `sudo`, `su`, `passwd`, `chsh`, `chfn`, `newgrp`, `gpasswd`, `mount`, `umount`, algún helper de `dbus` o `ssh`.
- Un SUID fuera de `/usr/bin`, `/usr/sbin` o `/usr/lib`, con nombre que empieza por punto, o que `file` identifica como una shell, es una alarma.
- `dpkg -S /ruta` te dice si un paquete instaló ese fichero. Si no lo reconoce, nadie lo instaló de forma legítima.

```bash
find / -xdev -perm -4000 -type f 2>/dev/null    # inventario de SUID
find / -xdev -perm -2000 -type f 2>/dev/null    # inventario de SGID
```

Cómo leer ese `find`: `-perm -4000` significa "tiene **al menos** el bit 4000 puesto", `-type f` sólo ficheros, `-xdev` no salta a otros sistemas de ficheros (evita recorrer `/proc`), y `2>/dev/null` tira los "Permission denied". Para cada resultado que no conozcas: `ls -l`, `file`, `dpkg -S`.

Neutralizar un SUID tiene dos variantes: quitar el bit (`chmod u-s`) o borrar el fichero. Si el binario es legítimo pero no lo necesitas, quitar el bit es reversible. Si es una copia plantada, bórralo.

## 4. Atributos del sistema de ficheros: más allá de rwx

ext4 (y otros) guarda **atributos** aparte de los permisos. `ls -l` no los muestra. Los dos que importan en seguridad:

| Atributo | Efecto |
|---|---|
| `i` (immutable) | Nadie puede modificar, borrar, renombrar ni crear enlaces al fichero. **Ni root**, mientras el atributo esté puesto |
| `a` (append only) | Sólo se puede añadir al final. Útil para logs; molesto si lo pone un atacante |

```bash
lsattr fichero            # muestra atributos: ----i---------e------- fichero
lsattr -d carpeta         # los de la carpeta en sí, no de su contenido
sudo chattr -i fichero    # quita inmutable
sudo chattr +i fichero    # lo pone
```

Root **puede** quitar el atributo; lo que no puede es saltárselo sin quitarlo. Por eso el síntoma clásico es: eres root, `rm -f` dice `Operation not permitted`, y los permisos `rwx` parecen correctos. Ese mensaje (distinto de `Permission denied`) es la pista: busca atributos.

> Diferencia de mensajes: `Permission denied` (EACCES) = los permisos rwx no te dejan. `Operation not permitted` (EPERM) = algo por encima de los permisos lo impide: atributos, capacidades, un sistema de ficheros de sólo lectura. Aprende a distinguirlos: te ahorran media hora.

Un atacante puede marcar como inmutables también la **carpeta** que contiene su payload, o el fichero de persistencia (un cron, un `authorized_keys`). Revisa con `lsattr` todo lo que se niegue a cambiar.

## 5. Grupos: compartir sin abrir a todos

La forma correcta de que dos cuentas compartan un fichero no es `777`, es un grupo:

```bash
sudo groupadd equipo
sudo usermod -aG equipo ana
sudo chgrp equipo /srv/compartido
sudo chmod 2770 /srv/compartido      # SGID: lo nuevo hereda el grupo 'equipo'
```

Un usuario recién añadido a un grupo **no** lo tiene en las sesiones ya abiertas: hay que volver a entrar (o `newgrp equipo`). Mira `id` para confirmarlo.

Grupos con poder especial que conviene vigilar: `sudo`, `adm` (lee logs), `docker` (equivale a root), `shadow`, `disk`.

## 6. Leer la salida: auditoría rápida de cuentas

```bash
awk -F: '$3 == 0 {print $1}' /etc/passwd                 # cuentas con UID 0
awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd   # personas
awk -F: '$7 !~ /(nologin|false)$/ {print $1, $7}' /etc/passwd   # cuentas con shell real
sudo awk -F: '$2 == "" {print $1}' /etc/shadow           # cuentas SIN contraseña
getent group sudo adm docker                              # quién está en grupos sensibles
```

Lo que buscas: UID 0 que no sea `root`, cuentas de servicio con shell real, cuentas sin contraseña, alguien inesperado en `sudo` o `docker`, una cuenta creada hace poco (compara con `ls -lt /home` o con la fecha de cambio de `shadow`).

## 7. Ejercicios

1. Un fichero tiene `-rw-r----- root:adm`. ¿Puede leerlo `analista` si está en el grupo `adm`? ¿Y si no?
2. Tienes `w` en una carpeta y dentro hay un fichero `-r-------- root root`. ¿Puedes borrarlo?
3. ¿Qué octal corresponde a `rwsr-xr-x`?
4. `rm` falla como root con `Operation not permitted`. Nombra dos causas posibles y el comando para comprobar cada una.

:::solucion Ver respuestas
1. Si está en `adm`, sí: aplica la clase de grupo (`r--`). Si no, aplica "otros" (`---`) y no puede.
2. Sí, salvo que la carpeta tenga sticky bit. Borrar es una operación sobre la carpeta.
3. `4755`.
4. Atributo inmutable o append (`lsattr fichero`, y `lsattr -d` en la carpeta). Sistema de ficheros montado en sólo lectura (`findmnt -T fichero` o `mount`, busca `ro`).
:::

## Chuleta

```bash
id; getent passwd u; getent group g
awk -F: '$3==0' /etc/passwd
useradd -m -s /bin/bash u; usermod -aG g u; userdel -r u
ls -l; stat -c '%a %U:%G %n' f; namei -l /ruta/completa
chmod 640 f; chmod u+x f; chown u:g f
find / -xdev -perm -4000 -type f 2>/dev/null; dpkg -S /ruta
lsattr f; chattr -i f
```
