# 05 · sudo y mínimo privilegio

> Cómo lee sudo sus reglas, qué significa cada parte de `usuario host=(runas) comandos`, por qué `NOPASSWD: ALL` equivale a regalar root y cómo editar sudoers sin quedarte fuera.

## 1. Qué hace sudo

`sudo` es un programa SUID root (módulo [04](#curso/04)). Cuando lo ejecutas, consulta su política y decide si te deja lanzar **ese** comando como **ese** usuario. Si te deja, ejecuta el comando como root (o como quien diga la regla) y registra el uso en el log de autenticación.

`su` es distinto: te convierte en otro usuario pidiendo la contraseña **de ese usuario**. `sudo` pide **tu** contraseña (o ninguna) y controla qué puedes hacer. Eso permite dar permisos concretos sin repartir la contraseña de root.

```bash
sudo -l              # ¿qué me deja hacer sudo a mí? (lo primero que mira un atacante)
sudo -l -U deploy    # ¿qué le deja a otro usuario? (como root)
sudo -u www-data id  # ejecutar como otro usuario que no es root
sudo -i              # shell de login de root
sudo -k              # olvida la contraseña cacheada
```

## 2. Dónde vive la política

| Fichero | Papel |
|---|---|
| `/etc/sudoers` | Fichero principal. Suele terminar con `@includedir /etc/sudoers.d` |
| `/etc/sudoers.d/*` | Un fichero por regla o por cuenta. Es donde se añaden cosas |

Reglas del directorio `sudoers.d` que conviene saber:

- Los ficheros cuyo nombre contiene un `.` o termina en `~` se **ignoran**. `deploy.conf` no se carga; `deploy` sí.
- Deben ser de root y no escribibles por otros. Lo normal es `0440`. Si los permisos están mal, sudo se queja y puede negarse a funcionar.
- Se leen en orden alfabético, y si varias reglas coinciden **gana la última**. Un `NOPASSWD` en un fichero posterior anula un `PASSWD` anterior.

## 3. Anatomía de una regla

```
deploy   ALL=(root)   NOPASSWD: /usr/bin/systemctl restart app
└─┬──┘   └┬┘ └─┬──┘   └───┬───┘  └──────────────┬──────────────┘
quién   en qué  como    etiqueta          qué comando (ruta absoluta
        host    quién                     y, opcionalmente, argumentos)
```

| Parte | Significa | Ejemplos |
|---|---|---|
| Quién | Usuario, o `%grupo` | `ana`, `%sudo`, `%admins` |
| Host | En qué máquinas aplica (para sudoers compartidos) | Casi siempre `ALL` |
| `(runas)` | Como qué usuario o grupo puede ejecutar | `(ALL)`, `(root)`, `(www-data)`, `(ALL:ALL)` |
| Etiqueta | Modificadores | `NOPASSWD:`, `PASSWD:`, `NOEXEC:` |
| Comandos | Lista separada por comas | `ALL`, `/usr/bin/apt-get update` |

### Cómo casan los argumentos

Esto es lo que más errores provoca:

| Escribes en la regla | Permite |
|---|---|
| `/usr/bin/apt-get` | `apt-get` con **cualquier** argumento |
| `/usr/bin/apt-get update` | Sólo exactamente `apt-get update` |
| `/usr/bin/apt-get ""` | Sólo `apt-get` **sin** argumentos |
| `/usr/bin/systemctl restart app*` | Comodín: también casaría `restart app otra-cosa` |

Por eso una regla sin argumentos es mucho más amplia de lo que parece. Y los comodines en argumentos son peligrosos: el `*` de sudo casa espacios, así que puede colar argumentos extra.

### Alias: dar nombre a listas

```
Cmnd_Alias DEPLOY = /usr/bin/systemctl restart app, /usr/bin/systemctl status app
deploy ALL=(root) NOPASSWD: DEPLOY
```

## 4. Por qué "sólo un comando" a veces es root completo

Muchos programas permiten ejecutar otros comandos desde dentro. Si sudo te deja lanzarlos como root, te deja lanzar **cualquier** cosa como root:

| Programa | Por qué escapa |
|---|---|
| `vi`, `vim`, `less`, `more`, `man` | Tienen `:!comando` o `!comando` |
| `find` | `-exec` |
| `awk`, `python`, `perl`, `ruby` | Son intérpretes completos |
| `tar`, `zip`, `rsync` | Opciones que ejecutan programas auxiliares |
| `cp`, `tee`, `dd` | Pueden sobrescribir `/etc/sudoers` o `/etc/passwd` |
| `bash`, `sh`, `env` | Evidente |
| `systemctl` sin argumentos fijos | `systemctl edit` abre un editor; un pager también escapa |

El proyecto GTFOBins documenta estos escapes, y lo usan atacantes y defensores. La lección para el defensor: **fija los argumentos** y prefiere comandos que no abran editores, pagers ni intérpretes. Para editar ficheros como root sin dar un editor root, existe `sudoedit`: copia el fichero, abre **tu** editor como tú, y al guardar lo vuelve a copiar.

## 5. NOPASSWD: ALL, la bomba de relojería

`usuario ALL=(ALL) NOPASSWD: ALL` significa: cualquier proceso que corra con esa cuenta es root, sin preguntar nada. Si alguien roba una llave SSH de esa cuenta, o explota una app que corre con ella, tiene root inmediato.

Es frecuente en cuentas de automatización "para ir rápido". El arreglo de mínimo privilegio:

1. Lista lo que la cuenta **realmente** necesita (mira el historial, los scripts de despliegue, los logs de sudo).
2. Escribe una regla con esas rutas absolutas y esos argumentos exactos.
3. Quita la regla amplia.
4. Prueba como esa cuenta: lo permitido funciona, lo demás falla.

```bash
sudo -l -U cuenta                      # qué tiene ahora
sudo -u cuenta sudo -n /ruta/comando   # -n: falla en vez de pedir contraseña (ideal para probar)
```

## 6. Editar sin quedarte fuera

Un error de sintaxis en sudoers puede romper sudo **para todos**. Si sudo es tu única forma de ser root, te quedas fuera del servidor.

```bash
sudo visudo                          # edita /etc/sudoers y valida antes de guardar
sudo visudo -f /etc/sudoers.d/app    # edita un fichero concreto, también validado
sudo visudo -c                       # valida TODA la configuración (principal + includes)
sudo visudo -cf /tmp/nueva-regla     # valida un fichero suelto antes de copiarlo
```

Flujo seguro para crear una regla con un comando de una línea:

```bash
echo 'deploy ALL=(root) NOPASSWD: /usr/bin/systemctl restart app' > /tmp/deploy
sudo visudo -cf /tmp/deploy && sudo install -m 0440 -o root -g root /tmp/deploy /etc/sudoers.d/deploy
```

`install` copia y fija permisos y dueño en un paso. Si `visudo -cf` falla, el `&&` impide la copia.

> Mantén abierta una shell de root (`sudo -i`) en otra pestaña mientras tocas sudoers. Si rompes algo, la arreglas desde ahí.

## 7. Auditar sudo: qué buscar

```bash
sudo cat /etc/sudoers | grep -vE '^\s*(#|$)'   # reglas activas del principal
sudo grep -r '' /etc/sudoers.d/                 # todas las reglas con su fichero delante
ls -l /etc/sudoers.d/                           # nombres y permisos
getent group sudo                               # miembros del grupo que suele tener ALL
grep -h sudo /var/log/auth.log | tail           # uso reciente
```

Señales de alarma:

- `NOPASSWD: ALL` para cualquier cuenta, sobre todo de servicio.
- Una regla para una cuenta que no administra nada (una cuenta "de pruebas", de backups, de monitorización).
- Comandos de la tabla de escapes sin argumentos fijos.
- Un fichero en `sudoers.d` con fecha reciente o nombre que imita a uno del sistema.
- Rutas a scripts que el usuario puede **escribir**: si puede editar el script, puede hacer que root ejecute lo que quiera. Comprueba con `ls -l` y `namei -l`.

> Antes de borrar una regla, mira de quién es. En un servidor hay reglas legítimas (la del administrador, la tuya). El objetivo es quitar la que sobra, no dejarte sin acceso.

## 8. Ejercicios

1. ¿Qué diferencia hay entre `ana ALL=(ALL) /usr/bin/less` y `ana ALL=(ALL) /usr/bin/less /var/log/syslog`? ¿Es segura alguna?
2. Creaste `/etc/sudoers.d/backup.conf` y la regla no funciona. ¿Por qué?
3. Escribe una regla para que `monitor` pueda ejecutar como root sólo `ss -tulpn`, sin contraseña.
4. ¿Por qué `sudo -n` es útil para probar reglas?

:::solucion Ver respuestas
1. La primera deja leer cualquier fichero como root. La segunda fija el argumento. Ninguna es segura: `less` permite `!comando` y ejecuta una shell como root. Para leer un log, mejor añadir la cuenta al grupo `adm`.
2. El nombre contiene un punto: sudo ignora ese fichero. Renómbralo a `backup`.
3. `monitor ALL=(root) NOPASSWD: /usr/bin/ss -tulpn` (comprueba la ruta real con `command -v ss`).
4. Hace que sudo falle en lugar de pedir contraseña. Así ves al instante si la regla `NOPASSWD` casa, sin quedarte esperando un prompt.
:::

## Chuleta

```bash
sudo -l; sudo -l -U u; sudo -u u -n cmd
sudo grep -r '' /etc/sudoers.d/; ls -l /etc/sudoers.d/
usuario ALL=(root) NOPASSWD: /ruta/abs arg1 arg2
visudo -c; visudo -cf fichero; visudo -f /etc/sudoers.d/x
install -m 0440 -o root -g root origen /etc/sudoers.d/x
```
