# 02 · La shell por dentro: .bashrc, PATH e historial

> Qué ficheros ejecuta bash cada vez que abres una terminal, cómo decide qué programa corre cuando escribes `ls`, y qué queda (o no) en el historial. Tres sitios donde un atacante deja persistencia y tú encuentras evidencia.

## 1. Qué es `.bashrc` y por qué es peligroso

`~/.bashrc` es un **script** de bash que se ejecuta automáticamente cada vez que abres una shell interactiva. Sirve para personalizar: alias, colores del prompt, variables. Pero es código que corre **con tus permisos, sin preguntar, cada vez que entras**. Si alguien añade una línea al final, esa línea se ejecuta en cada login tuyo.

Por eso es uno de los primeros sitios donde un intruso deja persistencia: cambias la contraseña, cierras su sesión, y al día siguiente, cuando tú (o él) abre una terminal, su código vuelve a correr.

### La familia de ficheros de arranque

Bash no lee un solo fichero. Depende del **tipo** de shell:

| Tipo de shell | Cuándo ocurre | Qué lee (en orden) |
|---|---|---|
| Login | Entrar por SSH, `su - usuario`, `bash -l` | `/etc/profile` → `/etc/profile.d/*.sh` → el **primero** que exista de `~/.bash_profile`, `~/.bash_login`, `~/.profile` |
| Interactiva no-login | Abrir otra terminal dentro de una sesión, escribir `bash` | `/etc/bash.bashrc` (Debian) → `~/.bashrc` |
| No interactiva | Un script (`bash script.sh`), cron, systemd | Ninguno de los anteriores (salvo que `BASH_ENV` apunte a uno) |
| Al salir de una login | `exit`, cerrar SSH | `~/.bash_logout` |

En Debian/Ubuntu, `~/.profile` contiene un bloque que hace `. "$HOME/.bashrc"` si la shell es bash. Resultado práctico: **casi cualquier forma de entrar acaba ejecutando `~/.bashrc`**.

```bash
grep -n bashrc ~/.profile      # verás cómo .profile carga .bashrc
```

> En los labs la terminal web abre una sesión con `su - analista`: es una shell de **login**, así que pasa por `.profile` y de ahí por `.bashrc`.

### `source` y `.`: ejecutar un fichero dentro de tu shell

```bash
source fichero.sh
. fichero.sh            # exactamente lo mismo, versión POSIX
```

Ejecutar un script normal (`bash fichero.sh`) crea un **proceso hijo**: lo que haga con variables o con el directorio actual muere con él. `source` en cambio lee el fichero y ejecuta cada línea **en tu shell actual**, como si las teclearas. Por eso `.bashrc` usa `source` para cargar otros ficheros, y por eso un atacante también: una línea `source /ruta/escondida` en tu `.bashrc` ejecuta un fichero que vive en otro sitio, así el `.bashrc` parece casi limpio.

Patrón típico de trampa:

```bash
[ -f /ruta/oculta ] && source /ruta/oculta
```

Se lee: "si existe el fichero, ejecútalo en mi shell". Si el fichero no existe, no falla ni deja error visible. Silencioso.

## 2. Cómo auditar los ficheros de arranque

### Técnica 1: compararlos con la plantilla original

Cuando se crea un usuario con `useradd -m`, sus dotfiles se copian de `/etc/skel/`. Así que la diferencia entre `/etc/skel/.bashrc` y el `.bashrc` del usuario es **exactamente lo que alguien añadió después**:

```bash
diff /etc/skel/.bashrc ~/.bashrc
diff /etc/skel/.profile ~/.profile
```

Leer la salida de `diff`: las líneas con `>` existen sólo en el segundo fichero (lo añadido), las que tienen `<` sólo en el primero (lo borrado). `12a13,16` significa "después de la línea 12 del primero se añadieron las líneas 13 a 16 del segundo".

### Técnica 2: buscar patrones sospechosos

```bash
grep -nE 'source|^\s*\. |curl|wget|nc |bash -i|base64|eval|/tmp|/dev/shm|PROMPT_COMMAND|trap ' \
  ~/.bashrc ~/.profile ~/.bash_profile ~/.bash_logout /etc/bash.bashrc /etc/profile /etc/profile.d/* 2>/dev/null
```

`-n` te da el número de línea, `-E` activa las alternativas con `|`. Busca:

- `source` / `.` hacia rutas raras (`/tmp`, `/dev/shm`, carpetas ocultas).
- Descargas (`curl`, `wget`) y conexiones (`nc`, `bash -i >& /dev/tcp/...`).
- Ofuscación (`base64 -d`, `eval`).
- `PROMPT_COMMAND`: un comando que bash ejecuta **antes de cada prompt**. Persistencia muy discreta.
- `alias sudo=...`: redefinir `sudo` para robar la contraseña cuando la teclees.

### Técnica 3: mirar el final

Los añadidos suelen ir al final, con un comentario que suena oficial ("actualización automática", "fix de locale"):

```bash
tail -n 15 ~/.bashrc
```

### Neutralizar una trampa

Neutralizar = quitar **las líneas** que la ejecutan (no todo el fichero: el resto del `.bashrc` es legítimo) **y** el payload al que apuntan. Puedes editar con `nano` o `vi`. Después:

- Comprueba que el fichero sigue siendo bash válido: `bash -n ~/.bashrc` (analiza la sintaxis sin ejecutar).
- Recuerda que las shells **ya abiertas** cargaron la trampa al empezar. Para probar, abre una nueva.
- Revisa **todos** los ficheros de la tabla, no sólo el primero que encuentres. Y los de otros usuarios (`/root/.bashrc`, `/home/*/.bashrc`).

## 3. PATH: cómo decide bash qué programa ejecutar

Cuando escribes `ls`, bash no sabe dónde está `ls`. Lo busca. El orden completo es:

1. **Alias** (`alias ll='ls -l'`)
2. **Palabras clave** de la shell (`if`, `for`…)
3. **Funciones** definidas en la sesión
4. **Builtins** (comandos internos: `cd`, `echo`, `source`, `type`)
5. La **tabla hash** de rutas ya resueltas (caché)
6. Las carpetas de `$PATH`, **de izquierda a derecha**. Gana la primera que contenga un ejecutable con ese nombre.

```bash
echo "$PATH"
# /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

`/usr/local/bin` va antes que `/usr/bin`. Es intencionado: permite al administrador instalar una versión más nueva de algo sin tocar la del sistema. Pero también significa que **quien pueda escribir en una carpeta del PATH que va primero, puede reemplazar cualquier comando**.

### Herramientas para saber qué se ejecuta de verdad

```bash
type ls          # la definición que GANA ahora mismo
type -a ls       # TODAS las definiciones, en orden de prioridad
command -v ls    # la ruta que se ejecutaría (útil en scripts)
which -a ls      # sólo busca en PATH (no ve alias ni funciones)
hash             # la caché de rutas que bash ya resolvió
hash -r          # vacía la caché
```

Leer `type -a`:

```
ls is aliased to `ls --color=auto'
ls is /usr/local/bin/ls
ls is /usr/bin/ls
```

Hay tres capas: un alias (normal en Debian), y **dos** ficheros `ls`. Un comando básico duplicado en `/usr/local/bin` merece una mirada con `file` y `cat`.

### La caché `hash`

Bash recuerda dónde encontró cada comando para no recorrer el PATH cada vez. Si borras el impostor, tu shell puede seguir intentando ejecutar la ruta vieja (y dar "No such file or directory") hasta que hagas `hash -r` o abras otra shell. No es un fallo de tu arreglo: es la caché.

### Verificar que un binario es el legítimo

```bash
file /usr/bin/ls               # debe ser un ELF, no un script
dpkg -S /usr/bin/ls            # qué paquete lo instaló (coreutils)
dpkg -V coreutils              # verifica los ficheros del paquete contra sus hashes (sin salida = OK)
sha256sum /usr/bin/ls          # compara con un servidor sano o con una línea base
```

### PATH en scripts privilegiados

Un script que corre como root (por cron, por sudo, por systemd) **hereda** el PATH de quien lo lanza. Si ese PATH empieza por una carpeta que un usuario normal puede escribir, ese usuario decide qué `tar` o qué `date` ejecuta root. Defensas:

- El script fija su propio `PATH` al principio (sólo carpetas de root).
- O usa rutas absolutas (`/usr/bin/tar`).
- Nunca `.` (el directorio actual) ni carpetas escribibles por otros en el PATH de root.

Lo verás aplicado a tareas programadas en el módulo [07](#curso/07).

```bash
ls -ld $(echo "$PATH" | tr ':' ' ')    # ¿alguna carpeta del PATH es escribible por otros?
```

Leer los permisos: si la carpeta aparece como `drwxrwxrwx` (la última `w`), cualquiera puede dejar ahí un ejecutable.

## 4. El historial de comandos

Bash guarda lo que tecleas en memoria y, **al cerrar la shell**, lo escribe en `~/.bash_history` (variable `HISTFILE`).

```bash
history | tail -20           # historial de la sesión actual (memoria)
cat ~/.bash_history          # lo que se guardó de sesiones anteriores
sudo cat /root/.bash_history # lo que tecleó root
```

Detalles que importan en forense:

- El historial se escribe al **salir**. Una sesión que sigue abierta (o que murió con `kill -9`) puede no haber guardado nada.
- `history -c` borra la lista **en memoria** de la sesión actual. Si el atacante lo ejecuta, sus comandos de esa sesión no llegan al fichero. Pero el propio `history -c` y lo anterior pueden haber quedado en el fichero de sesiones previas.
- Variables que usan los atacantes: `unset HISTFILE`, `export HISTFILE=/dev/null`, `HISTSIZE=0`, o un enlace `~/.bash_history -> /dev/null`.
- Con `HISTCONTROL=ignorespace`, un comando que empieza con un espacio no se guarda.
- Por defecto no hay fechas. Con `HISTTIMEFORMAT='%F %T '` el historial guarda y muestra la hora de cada comando.

Señales de manipulación:

```bash
ls -la ~/.bash_history /root/.bash_history   # ¿tamaño 0? ¿es un enlace a /dev/null?
grep -nE 'history -c|HISTFILE|unset HIST|> */var/log|shred|rm .*log' /root/.bash_history /home/*/.bash_history 2>/dev/null
```

> Un historial vacío o un log truncado **no** es ausencia de evidencia: es evidencia de que alguien intentó borrar. Anótalo en tu informe.

## 5. Ejercicios

1. Crea un alias `ll` en tu sesión y comprueba con `type -a ll` qué es. ¿Sobrevive si abres otra shell?
2. Ejecuta `diff /etc/skel/.bashrc ~/.bashrc` en cualquier lab. ¿Hay diferencias? ¿Qué significan las marcas `<` y `>`?
3. Ejecuta `bash -c 'echo $PATH'` y `sudo bash -c 'echo $PATH'`. ¿Por qué pueden ser distintos?
4. ¿Por qué un script lanzado por cron no ejecuta tu `~/.bashrc`?

:::solucion Ver respuestas
1. `type -a ll` dirá `ll is aliased to ...`. No sobrevive: el alias sólo existe en la shell donde lo creaste. Para que sea permanente habría que escribirlo en `~/.bashrc`, que es justo lo que hace un atacante con sus trampas.
2. Si no hay salida, el fichero es idéntico a la plantilla. `>` = líneas que sólo están en tu `.bashrc` (añadidas); `<` = líneas de la plantilla que ya no están (borradas).
3. `sudo` aplica `secure_path` (definido en `/etc/sudoers`): sustituye tu PATH por uno fijo y seguro.
4. Porque cron lanza una shell **no interactiva**, que no lee `.bashrc` ni `.profile`. Por eso cron tiene su propio PATH mínimo y por eso los scripts de cron deben definir su entorno.
:::

## Chuleta

```bash
diff /etc/skel/.bashrc ~/.bashrc         # lo añadido a mano
tail -n 15 ~/.bashrc; bash -n ~/.bashrc  # mirar el final; validar sintaxis
grep -nE 'source|curl|base64|/dev/shm|/tmp|PROMPT_COMMAND' ~/.bashrc ~/.profile /etc/bash.bashrc /etc/profile.d/*
type -a <cmd>; command -v <cmd>; hash -r # qué se ejecuta de verdad
file "$(command -v <cmd>)"; dpkg -S <ruta> # ¿es el binario del paquete?
sudo cat /root/.bash_history             # qué tecleó root
```
