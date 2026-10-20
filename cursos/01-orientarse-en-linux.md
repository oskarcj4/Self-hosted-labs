# 01 · Orientarse en un Linux desconocido

> Dónde vive cada cosa en el sistema de ficheros, cómo se encadenan comandos (pipes, redirecciones, heredocs), por qué `sudo echo > fichero` falla y cómo saber si un comando funcionó.

## 1. Quién soy, dónde estoy, qué máquina es

Lo primero al entrar a cualquier servidor:

```bash
whoami              # tu usuario
id                  # uid, gid y grupos (importa para permisos y sudo)
hostname            # nombre de la máquina
hostname -I         # IPs de la máquina (la primera suele ser la de la red)
pwd                 # carpeta actual
cat /etc/os-release # distribución y versión (Debian 12, Alpine…)
uname -a            # kernel
uptime              # cuánto lleva encendida y carga media
```

En los labs eres `analista`, con `sudo` sin contraseña. Eso significa que puedes hacer de root cuando lo necesites, pero tu shell normal no lo es. Muchas pruebas salen distintas como `analista` y como root: tenlo presente.

## 2. El mapa del sistema de ficheros

Linux sigue (más o menos) el estándar FHS. Saber qué va en cada carpeta te dice **dónde buscar** y **qué es sospechoso**.

| Ruta | Qué contiene | Por qué te importa |
|---|---|---|
| `/etc` | Configuración de todo el sistema | sshd_config, sudoers, nginx, cron.d, passwd, systemd |
| `/var/log` | Logs | auth.log, syslog, nginx/, journal/ |
| `/var/lib` | Datos de servicios (bases de datos, estado) | Lo que un servicio escribe de forma persistente |
| `/var/www` | Sitios web (por convención) | Todo lo que hay dentro puede ser público |
| `/home/<usuario>` | Carpetas de usuarios | dotfiles (.bashrc), .ssh/authorized_keys, historial |
| `/root` | Carpeta de root | .bash_history de root, evidencia |
| `/tmp`, `/var/tmp` | Temporales, escribibles por todos | Escondite clásico de malware. Nada legítimo debería **ejecutarse** desde aquí |
| `/dev/shm` | Memoria compartida (un tmpfs en RAM) | Igual que /tmp pero no deja rastro en disco al reiniciar |
| `/proc` | Ventana virtual al kernel: procesos, memoria | La fuente que no se puede falsificar desde espacio de usuario |
| `/usr/bin`, `/bin` | Binarios del sistema (los instala el gestor de paquetes) | `ls`, `ps`, `bash`… |
| `/usr/local/bin`, `/usr/local/sbin` | Binarios instalados a mano por el admin | Va **antes** que /usr/bin en el PATH: un sitio para secuestrar comandos |
| `/opt` | Software de terceros | Apps de los labs, scripts de mantenimiento |
| `/lib/systemd/system` | Unidades systemd de los paquetes | Lo "oficial" |
| `/etc/systemd/system` | Unidades systemd creadas por el admin | Lo que alguien añadió a mano: revísalo primero |

> Regla práctica: en `/etc` hay **configuración**, en `/var` hay **datos que cambian**, en `/usr` hay **programas que no deberían cambiar**. Un binario nuevo en `/usr/bin` o un script en `/tmp` lanzado por root son anomalías.

### Ficheros ocultos

Un nombre que empieza por punto (`.bashrc`, `.update`, `.thumb.php`) no aparece en `ls` normal. No es un mecanismo de seguridad: es una convención para no ensuciar el listado. Los atacantes lo usan para camuflarse.

```bash
ls -la            # -a muestra ocultos, -l formato largo
ls -lah /dev/shm  # -h tamaños legibles (K, M, G)
ls -lat /tmp      # -t ordena por fecha de modificación (lo más reciente arriba)
```

## 3. Leer ficheros sin romper nada

```bash
cat fichero              # vuelca todo
less fichero             # paginado: espacio avanza, b retrocede, /texto busca, q sale
head -n 20 fichero       # primeras 20 líneas
tail -n 20 fichero       # últimas 20 (el final de .bashrc o de un log)
tail -f /var/log/syslog  # sigue el fichero en vivo (Ctrl+C para salir)
wc -l fichero            # cuántas líneas
file fichero             # qué tipo de contenido es (ELF, script, texto, gzip…)
stat fichero             # permisos, dueño, tamaño y las tres fechas (acceso, modificación, cambio)
```

`file` es tu detector de mentiras: un fichero llamado `kworker` que resulta ser un ELF de Python, o un `ls` que resulta ser un "Bourne-Again shell script", son señales claras.

## 4. Encadenar comandos: el corazón de la shell

### Pipes `|`

Un pipe conecta la **salida** de un comando con la **entrada** del siguiente. Así se construyen análisis potentes con piezas simples:

```bash
ps aux | grep python          # lista procesos y filtra
cat auth.log | wc -l          # cuenta líneas (mejor: wc -l auth.log)
```

Cada comando del pipe hace una sola cosa. Para leer un pipe largo, léelo de izquierda a derecha preguntando "¿qué sale de aquí?" en cada `|`. Si no entiendes un pipe, **córtalo**: ejecuta sólo la primera parte, luego añade la segunda, y mira cómo cambia la salida.

### Las tres corrientes: stdin, stdout, stderr

Todo proceso tiene tres canales:

| Número | Nombre | Uso |
|---|---|---|
| 0 | stdin | Lo que entra (teclado, o un pipe) |
| 1 | stdout | La salida normal |
| 2 | stderr | Los errores |

Por eso existen estas redirecciones:

```bash
comando > fichero        # stdout a un fichero (lo SOBRESCRIBE)
comando >> fichero       # stdout al final del fichero (AÑADE)
comando 2> errores.txt   # sólo stderr a un fichero
comando 2>/dev/null      # tira los errores (típico con find / para no ver "Permission denied")
comando > todo.txt 2>&1  # stdout y stderr al mismo fichero
comando < entrada.txt    # usa un fichero como stdin
```

`/dev/null` es un agujero negro: todo lo que escribes ahí desaparece.

> **Cuidado con `>`**: sobrescribe sin preguntar. `> /var/log/auth.log` vacía el log (justo lo que hace un atacante en el lab 09). Si quieres añadir, usa `>>`.

### Por qué `sudo echo "x" > /etc/fichero` falla

```bash
sudo echo "sshd: 1.2.3.4" >> /etc/hosts.deny
# bash: /etc/hosts.deny: Permission denied
```

La redirección `>>` la hace **tu shell** (como `analista`) **antes** de ejecutar `sudo`. `sudo` sólo eleva a `echo`, que no necesita privilegios. La solución es que el proceso que escribe sea el que tiene sudo:

```bash
echo "sshd: 1.2.3.4" | sudo tee -a /etc/hosts.deny     # tee escribe como root; -a = añadir
echo "contenido" | sudo tee /etc/fichero >/dev/null    # sin -a sobrescribe; >/dev/null oculta el eco
sudo sh -c 'echo "x" >> /etc/fichero'                  # alternativa: toda la línea dentro de un sh root
```

`tee` copia su entrada a la pantalla **y** a un fichero. Con `sudo tee` el fichero lo abre root. Este patrón aparece en muchísimas soluciones: entiéndelo una vez y lo verás en todas partes.

### Heredocs: escribir varias líneas de golpe

```bash
cat > ~/notas.txt <<EOF
Host: $(hostname)
Fecha: $(date)
EOF
```

Todo lo que hay entre `<<EOF` y la línea `EOF` se pasa como stdin a `cat`. Dos variantes importantes:

```bash
cat <<EOF       # las variables ($HOME) y comandos $(...) SE EXPANDEN
cat <<'EOF'     # con comillas: el texto va LITERAL, sin expandir nada
```

Usa `<<'EOF'` cuando escribas scripts o configuraciones que contienen `$` (unidades systemd, scripts bash), para que tu shell no los sustituya por su valor. Y combínalo con `sudo tee` para escribir ficheros de sistema:

```bash
sudo tee /etc/miapp.conf >/dev/null <<'EOF'
PORT=8080
EOF
```

## 5. Comillas, variables y sustitución

```bash
NOMBRE=mundo           # sin espacios alrededor del =
echo "hola $NOMBRE"    # comillas dobles: expande variables -> hola mundo
echo 'hola $NOMBRE'    # comillas simples: literal -> hola $NOMBRE
echo "hoy es $(date +%F)"   # $(...) ejecuta un comando y pega su salida
PID=$(pgrep -x sshd)   # guarda la salida en una variable
echo "$PID"
```

Regla: pon **siempre** comillas dobles alrededor de variables (`"$PID"`, `"$FICHERO"`). Sin ellas, una variable vacía o con espacios rompe el comando de forma silenciosa.

## 6. ¿Funcionó? Códigos de salida

Cada comando termina con un número: `0` = éxito, cualquier otro = fallo. La shell lo guarda en `$?`.

```bash
grep -q root /etc/passwd
echo $?          # 0: lo encontró
grep -q zzz /etc/passwd
echo $?          # 1: no lo encontró
```

Esto permite encadenar con lógica:

```bash
sudo nginx -t && sudo systemctl reload nginx     # && : sólo recarga si la prueba pasó
ping -c1 10.8.0.2 || echo "sin respuesta"        # || : se ejecuta si el anterior FALLÓ
comando1 ; comando2                              # ;  : ejecuta ambos, pase lo que pase
```

`check.sh` funciona así: cada objetivo es un `if` sobre el código de salida de un `grep -q`, `test`, `curl`… y al final sale con 0 si todo pasó. Leer un `check.sh` es una buena práctica de lectura de bash.

### Tests rápidos

```bash
[ -f /etc/hosts.deny ] && echo "existe y es fichero"
[ -d /data ] && echo "es carpeta"
[ -e /tmp/x ] || echo "no existe"
[ -s fichero ] && echo "existe y no está vacío"
[ -u /usr/bin/sudo ] && echo "tiene SUID"
```

## 7. Ayuda y descubrimiento

- `man <comando>` y dentro, `/OPCION` para buscar un flag concreto.
- `<comando> --help | less` cuando no hay manual.
- `tldr <comando>` si lo tienes en tu máquina (ejemplos prácticos).
- `ls /etc/<servicio>` para ver qué ficheros de configuración tiene un servicio.
- `dpkg -L <paquete>` (Debian) lista qué ficheros instaló un paquete; `dpkg -S /ruta/fichero` dice qué paquete instaló un fichero. Si `dpkg -S` no conoce un binario de `/usr/bin`, nadie lo instaló con el gestor de paquetes.

## 8. Ejercicios

1. ¿Qué diferencia hay entre `ls -la /tmp > lista.txt` y `ls -la /tmp >> lista.txt`?
2. Escribe una línea que añada `hola` al final de `/etc/motd` siendo `analista` (con sudo).
3. ¿Por qué `find / -name '*.conf'` llena la pantalla de errores y cómo los ocultas?
4. ¿Qué imprime `echo '$HOME'` y qué imprime `echo "$HOME"`?

:::solucion Ver respuestas
1. `>` sobrescribe `lista.txt` con el listado; `>>` lo añade al final de lo que ya hubiera.
2. `echo hola | sudo tee -a /etc/motd`. La redirección `>>` con sudo delante no funcionaría porque la abre tu shell.
3. Porque `analista` no puede leer muchas carpetas y cada una genera un "Permission denied" por stderr. `find / -name '*.conf' 2>/dev/null` los tira. (O ejecútalo con sudo.)
4. El primero imprime literalmente `$HOME` (comillas simples no expanden). El segundo imprime la ruta, por ejemplo `/home/analista`.
:::

## Chuleta

```bash
id; hostname -I; cat /etc/os-release          # orientación
ls -lat <dir>                                  # lo más reciente arriba
file <f>; stat <f>                             # qué es y metadatos
cmd > f   cmd >> f   cmd 2>/dev/null           # redirecciones
echo x | sudo tee -a /etc/f                    # escribir como root
sudo tee /etc/f >/dev/null <<'EOF' ... EOF     # fichero multilínea literal
cmd1 && cmd2   cmd1 || cmd2   echo $?          # lógica por código de salida
```
