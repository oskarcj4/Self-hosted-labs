# 09 · Logs y respuesta a incidentes

> Qué registra Linux y dónde, cómo leer `auth.log` mensaje a mensaje, qué hacer cuando el atacante borró el log, cómo construir una línea de tiempo y cómo vigilar ficheros críticos con auditd.

## 1. Mentalidad: primero entender, luego limpiar

Cuando te "hackean", la tentación es borrar todo lo raro cuanto antes. Si lo haces sin mirar, pierdes la respuesta a las preguntas que importan: ¿por dónde entró?, ¿qué hizo?, ¿qué más tocó?, ¿sigue dentro? Sin esas respuestas, vuelve a entrar por el mismo sitio.

El orden general de respuesta a un incidente:

1. **Contener**: cortar el daño activo (bloquear una IP, congelar un proceso con `kill -STOP`) sin destruir evidencia.
2. **Recoger evidencia**: copiar logs, listar procesos y conexiones, guardar los binarios sospechosos. Lo volátil (procesos, conexiones, `/dev/shm`) primero, porque desaparece.
3. **Analizar**: construir la línea de tiempo.
4. **Erradicar**: quitar persistencia, procesos, binarios, cuentas, llaves.
5. **Recuperar y aprender**: arreglar la causa raíz y documentar.

```bash
mkdir -p ~/evidencia
sudo cp -a /var/log/auth.log* ~/evidencia/      # -a conserva fechas y permisos
ps auxww > ~/evidencia/ps.txt
sudo ss -tunap > ~/evidencia/ss.txt
```

## 2. El mapa de logs

| Fichero | Qué contiene |
|---|---|
| `/var/log/auth.log` | Autenticación: SSH, sudo, su, cambios de cuentas (Debian/Ubuntu) |
| `/var/log/secure` | Lo mismo en RHEL/Fedora |
| `/var/log/syslog` | Mensajes generales del sistema, cron, servicios |
| `/var/log/kern.log` | Kernel (también en `dmesg`) |
| `/var/log/nginx/`, `/var/log/apache2/` | Accesos y errores web |
| `/var/log/wtmp` | Binario: inicios y cierres de sesión. Se lee con `last` |
| `/var/log/btmp` | Binario: intentos de login fallidos. Se lee con `lastb` |
| `/var/log/lastlog` | Binario: último login de cada usuario. Se lee con `lastlog` |
| `/var/log/journal/` | El journal de systemd (módulo [08](#curso/08)) |
| `/var/log/audit/audit.log` | Eventos de auditd (sección 7) |
| `~/.bash_history` | Historial de comandos de cada usuario (módulo [02](#curso/02)) |

Los logs de texto los escribe `rsyslog`; el journal lo escribe `journald`. En muchos sistemas conviven: el mismo evento puede estar en los dos.

## 3. Leer auth.log

Cada línea tiene el formato syslog: fecha, host, programa con PID y mensaje.

```
Oct 20 03:12:01 srv sshd[901]: Failed password for invalid user admin from 192.0.2.10 port 40122 ssh2
Oct 20 03:12:09 srv sshd[905]: Failed password for root from 192.0.2.10 port 40188 ssh2
Oct 20 03:14:07 srv sshd[930]: Accepted password for ana from 192.0.2.10 port 40210 ssh2
Oct 20 03:14:07 srv sshd[930]: pam_unix(sshd:session): session opened for user ana(uid=1001) by (uid=0)
Oct 20 03:15:30 srv sudo:      ana : TTY=pts/0 ; PWD=/home/ana ; USER=root ; COMMAND=/usr/bin/id
Oct 20 03:40:02 srv sshd[930]: pam_unix(sshd:session): session closed for user ana
```

| Mensaje | Significa |
|---|---|
| `Failed password for invalid user X` | Probaron un usuario que **no existe** (diccionario de nombres) |
| `Failed password for X` | El usuario existe, la contraseña falló |
| `Accepted password for X` | Entró con contraseña |
| `Accepted publickey for X` | Entró con llave: busca qué llave en `authorized_keys` |
| `session opened` / `session closed` | Inicio y fin de sesión: te dan la duración |
| `sudo: X : ... COMMAND=...` | Qué ejecutó con sudo, desde qué carpeta y terminal |
| `useradd`, `usermod`, `passwd`, `chpasswd` | Cambios de cuentas |
| `Connection closed by ... [preauth]` | Se desconectó antes de autenticar (escáneres) |

Lo que buscas en un triage de fuerza bruta: **muchos fallos** desde una IP (ruido) y luego un **Accepted** desde esa misma IP (brecha). El ruido sin éxito es el día a día de cualquier servidor con SSH abierto; el `Accepted` tras el ruido es lo que te convierte en víctima.

```bash
grep -c 'Failed password' auth.log                           # cuánto ruido
grep 'Failed password' auth.log | grep -oE 'from [0-9.]+' | sort | uniq -c | sort -rn | head
grep -E 'Accepted (password|publickey)' auth.log             # quién entró de verdad
grep 'from 192.0.2.10' auth.log | tail                       # todo lo de una IP
grep 'sshd\[930\]' auth.log                                  # toda la sesión de un PID
```

El PID de `sshd` (`[930]` en el ejemplo) une las líneas de una misma conexión: el login, la apertura de sesión y el cierre. Es la forma de seguir una sesión concreta entre cientos.

## 4. Rotación: los logs viejos no desaparecen

`logrotate` renombra los logs periódicamente para que no crezcan sin fin:

```
auth.log        el actual
auth.log.1      el periodo anterior, en texto
auth.log.2.gz   más antiguo, comprimido
auth.log.3.gz
```

```bash
ls -la --time-style=full-iso /var/log/auth.log*
zcat /var/log/auth.log.2.gz | grep Accepted     # leer un .gz sin descomprimir a disco
zgrep Accepted /var/log/auth.log*                # grep que entiende .gz y texto a la vez
```

Un atacante que sólo vacía el fichero actual deja intactas las copias rotadas.

## 5. Cuando el atacante borró el log

Borrar o vaciar un log **también deja huella**. Señales:

- El fichero existe pero mide 0 bytes, y su fecha de modificación es reciente (`ls -la`, `stat`).
- Hay un hueco: el log termina o empieza en una hora en la que debería haber actividad.
- El servicio sigue corriendo pero el fichero dejó de crecer, o el proceso que lo escribe aún tiene abierto el fichero borrado: `sudo ls -l /proc/*/fd 2>/dev/null | grep deleted`.

Fuentes alternativas, de más a menos fiable:

| Fuente | Por qué puede sobrevivir |
|---|---|
| Copias rotadas (`.1`, `.gz`) | El atacante sólo vació el fichero actual |
| journal (`journalctl _COMM=sshd`) | Se guarda aparte, en formato binario |
| `last`, `lastb`, `lastlog` | Ficheros binarios distintos de `auth.log` |
| Historial de shell (`/root/.bash_history`, `/home/*/.bash_history`) | Puede contener los propios comandos del atacante, **incluido el borrado** |
| `/proc` | Procesos aún vivos, sesiones abiertas (`who`, `w`), conexiones (`ss`) |
| Logs de otros servicios | Web, firewall, un SIEM o un servidor de logs remoto |

```bash
last -i | head                 # sesiones con IP
sudo lastb -i | head           # fallos (si btmp existe)
lastlog | grep -v 'Never'      # último acceso de cada cuenta
who; w                         # quién está conectado ahora
sudo cat /root/.bash_history
```

> El comando con que se vació un log (`> /var/log/auth.log`, `truncate -s0`, `shred`, `history -c`) en el historial es en sí una prueba que debes documentar: dice qué hizo, con qué cuenta y, por su posición en el historial, en qué orden.

Por esto en producción los logs se envían **fuera** de la máquina (rsyslog remoto, un SIEM): el atacante que gana root en el servidor no puede borrar lo que ya salió.

## 6. Línea de tiempo y documentación

Un informe de incidente útil responde con evidencia, no con suposiciones:

```
Origen: IP 192.0.2.10
Primer contacto: 2026-10-20 03:12 (fuerza bruta, auth.log.1 líneas 120-480)
Acceso: 03:14:07 Accepted password for ana (auth.log.1)
Acciones: sudo id 03:15; descarga de /dev/shm/x (bash_history de ana)
Borrado de rastro: '> /var/log/auth.log' en /root/.bash_history
```

Para cada afirmación anota **la fuente** (fichero y, si puedes, línea). Si otro analista no puede reproducir tu conclusión, no está demostrada.

`grep -n` da el número de línea; `stat` da las tres fechas de un fichero (acceso, modificación y cambio de inodo); `ls -lt --time-style=full-iso` ordena por modificación con fecha completa.

## 7. auditd: que el kernel apunte quién toca qué

Los logs de texto dicen lo que cada programa quiere contar. **auditd** registra desde el kernel llamadas al sistema concretas: abrir un fichero para escribir, cambiar sus atributos, ejecutar algo. El atacante no puede "no contarlo".

### Reglas de vigilancia de ficheros

```
-w /ruta/fichero -p wa -k clave
   │              │    └ etiqueta para buscar luego
   │              └ permisos a vigilar: r leer, w escribir, x ejecutar, a cambiar atributos
   └ watch: vigila esta ruta
```

```bash
sudo auditctl -w /etc/sudoers -p wa -k cambios_sudoers   # añadir en caliente (se pierde al reiniciar)
sudo auditctl -l                                         # reglas activas
sudo auditctl -D                                         # borrar todas las reglas en caliente
```

Para que sobreviva a reinicios, la regla va en un fichero de `/etc/audit/rules.d/` (extensión `.rules`) y se cargan con `sudo augenrules --load`.

### Buscar eventos

```bash
sudo ausearch -k cambios_sudoers           # eventos con esa clave
sudo ausearch -k cambios_sudoers -i        # -i traduce UIDs a nombres y fechas legibles
sudo ausearch -k cambios_sudoers --start recent   # últimos 10 minutos
sudo aureport -f -i                        # resumen de accesos a ficheros
```

### Leer un evento

Un evento son varias líneas `type=...` con el mismo número de serie. Las útiles:

| Línea | Campos que importan |
|---|---|
| `type=SYSCALL` | `auid` (quién **inició sesión**, aunque luego hiciera sudo), `uid` (con qué usuario corría), `comm` y `exe` (qué programa), `success` |
| `type=PATH` | `name` (qué fichero) |
| `type=PROCTITLE` | La línea de comandos (en hexadecimal; con `-i` se decodifica) |

`auid` es el gran aporte de auditd: aunque alguien haga `sudo -i` y actúe como root, auditd recuerda con qué cuenta entró originalmente.

> Una regla que vigila un fichero se dispara también con los cambios legítimos (un `useradd` modifica `/etc/passwd`). Es lo esperado: auditd no juzga, registra. Tú decides qué es normal.

## 8. Logs que no son de sesión: patrones anómalos

La misma técnica de contar sirve para cualquier log: DNS, web, firewall. Busca lo que se sale de la norma (módulo [03](#curso/03) para los pipelines):

- **Frecuencia**: un origen o un destino que aparece muchísimo más que el resto.
- **Longitud**: valores mucho más largos que lo normal (`awk '{print length($N)}'`).
- **Unicidad**: miles de valores distintos que comparten un mismo sufijo (un mismo dominio base, una misma ruta).
- **Alfabeto**: cadenas que parecen base32 (`a-z2-7`), base64 o hexadecimal.
- **Horario**: actividad a horas en que nadie trabaja.

Un dominio legítimo se consulta con pocos nombres cortos que se repiten; un canal de exfiltración usa nombres largos, únicos y con aspecto aleatorio hacia el mismo dominio base.

## 9. Ejercicios

1. ¿Qué diferencia hay entre `Failed password for invalid user test` y `Failed password for test`?
2. `auth.log` mide 0 bytes. Nombra cuatro sitios donde buscar quién entró.
3. Con auditd, ¿qué campo te dice qué persona hizo un cambio aunque usara `sudo`?
4. ¿Por qué copias los logs antes de empezar a limpiar?

:::solucion Ver respuestas
1. La primera: la cuenta `test` no existe. La segunda: existe y la contraseña era incorrecta. La segunda es más preocupante porque el atacante acertó un nombre real.
2. Las copias rotadas (`auth.log.1`, `.gz`), el journal (`journalctl _COMM=sshd`), `last` y `lastb` (wtmp y btmp) y el historial de shell de root y de los usuarios. También `who` y `ss` si la sesión sigue abierta.
3. `auid` (audit UID): el usuario con que se inició sesión, que no cambia con `sudo` ni `su`.
4. Porque limpiar puede modificar o borrar evidencia, y la necesitas para entender el alcance, para el informe y para no equivocarte de culpable.
:::

## Chuleta

```bash
grep -E 'Accepted|Failed' auth.log; grep 'sshd\[PID\]' auth.log
zgrep Accepted /var/log/auth.log*; ls -la --time-style=full-iso /var/log/auth.log*
last -i; lastb -i; lastlog; who; w
journalctl _COMM=sshd --since today
auditctl -w /ruta -p wa -k clave; auditctl -l; ausearch -k clave -i
/etc/audit/rules.d/x.rules + augenrules --load
cp -a log ~/evidencia/; stat f; grep -n
```
