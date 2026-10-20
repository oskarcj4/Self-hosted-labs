# 11 · Firewall: iptables, TCP wrappers y fail2ban

> Cómo recorre un paquete las reglas de iptables, por qué el orden importa, cómo pasar de "todo abierto" a default-deny sin cortarte la conexión, el bloqueo por aplicación con `hosts.deny` y el baneo automático con fail2ban.

## 1. El modelo de iptables

iptables es la interfaz clásica del filtrado de paquetes del kernel (netfilter). Organiza las reglas en **tablas** y **cadenas**. Para un firewall de host sólo necesitas la tabla `filter` (la de por defecto) y tres cadenas:

| Cadena | Qué paquetes |
|---|---|
| `INPUT` | Los que **llegan** a esta máquina |
| `OUTPUT` | Los que **salen** de esta máquina |
| `FORWARD` | Los que **atraviesan** la máquina (router, Docker) |

Cada cadena es una **lista ordenada** de reglas más una **política** por defecto. El kernel recorre la lista de arriba abajo; la **primera** regla que casa decide el destino (`-j`) y se deja de mirar. Si ninguna casa, se aplica la política.

| Destino (`-j`) | Efecto |
|---|---|
| `ACCEPT` | Deja pasar |
| `DROP` | Descarta en silencio: el otro lado espera hasta un timeout |
| `REJECT` | Descarta y avisa (el otro lado ve "connection refused" al instante) |
| `LOG` | Registra en el log del kernel y **sigue** con la siguiente regla |

> Consecuencia del "primera que casa gana": una regla `ACCEPT` para el puerto 9000 seguida de una `DROP` para el mismo puerto deja el puerto **abierto**. La segunda nunca se evalúa. Añadir un bloqueo al final no arregla un permiso que está arriba.

## 2. Leer las reglas

```bash
sudo iptables -S                  # todas las reglas, en el formato con el que se escriben
sudo iptables -S INPUT            # sólo INPUT
sudo iptables -L INPUT -n -v --line-numbers   # tabla con contadores y número de línea
```

### Leer `iptables -S INPUT`

```
-P INPUT ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp -m tcp --dport 80 -j ACCEPT
-A INPUT -p tcp -m tcp --dport 8081 -j ACCEPT
```

- `-P INPUT ACCEPT`: la política. Lo que no casa con nada, **pasa**. Es decir: firewall abierto.
- `-A INPUT ...`: cada regla, en orden.

### Leer `iptables -L -n -v --line-numbers`

```
Chain INPUT (policy DROP 37 packets, 2220 bytes)
num   pkts bytes target  prot opt in   out  source      destination
1      120  9800 ACCEPT  all  --  lo   *    0.0.0.0/0   0.0.0.0/0
2     5400  400K ACCEPT  all  --  *    *    0.0.0.0/0   0.0.0.0/0   ctstate RELATED,ESTABLISHED
3       12   720 ACCEPT  tcp  --  *    *    0.0.0.0/0   0.0.0.0/0   tcp dpt:22
```

`pkts` y `bytes` cuentan cuánto tráfico casó con cada regla: si una regla de bloqueo tiene contador 0 cuando esperabas tráfico, algo por encima ya lo está decidiendo. `num` sirve para borrar o insertar por posición.

## 3. Escribir reglas

| Operación | Sintaxis |
|---|---|
| Añadir al **final** | `iptables -A INPUT <condiciones> -j <destino>` |
| Insertar en una **posición** (por defecto la 1) | `iptables -I INPUT [n] <condiciones> -j <destino>` |
| Borrar por **especificación** (exactamente igual que se creó) | `iptables -D INPUT <condiciones> -j <destino>` |
| Borrar por **número** | `iptables -D INPUT n` |
| Cambiar la **política** | `iptables -P INPUT DROP` |
| Vaciar una cadena | `iptables -F INPUT` (no cambia la política) |

Condiciones habituales:

```
-p tcp --dport 22          protocolo y puerto destino
-s 192.0.2.10              origen (también redes: -s 10.0.0.0/8)
! -s 127.0.0.1             negación: origen distinto de
-i lo / -i eth0            interfaz de entrada
-m conntrack --ctstate ESTABLISHED,RELATED   conexiones ya abiertas y sus relacionadas
-m multiport --dports 80,443                 varios puertos a la vez
```

La forma más segura de borrar una regla es copiar su línea de `iptables -S` y cambiar `-A` por `-D`. Así no te equivocas en ningún detalle.

## 4. Diseñar un firewall default-deny

"Default deny" = la política es `DROP` y sólo abres lo que necesitas. Las piezas, en orden:

1. **Loopback**: muchas cosas locales hablan por `lo`. Si lo cortas, se rompen servicios de la propia máquina.
2. **Conexiones establecidas**: sin esta regla, las respuestas a las conexiones que **tú** abres (un `apt update`, un `curl`, tu propia sesión SSH ya abierta) se descartan.
3. **Servicios necesarios**: un `ACCEPT` por cada puerto que deba estar abierto, y sólo desde donde haga falta.
4. **Política DROP** al final de todo.

> Por qué la política va al final: si cambias la política a DROP antes de aceptar las establecidas y el puerto 22, y estás administrando por SSH, el siguiente paquete de tu propia sesión se descarta y te quedas fuera. En un servidor real, eso puede significar ir al centro de datos. Primero las reglas que te mantienen dentro, después el candado.

Red de seguridad mientras pruebas en un servidor remoto: programa una vuelta atrás automática y cancélala cuando confirmes que sigues dentro.

```bash
sudo iptables-save > /root/fw.bak                       # copia del estado actual
( sleep 300; sudo iptables-restore < /root/fw.bak ) &   # en 5 min, vuelve atrás
# ... aplicas cambios, compruebas que sigues conectado ...
kill %1                                                 # cancela la vuelta atrás
```

### Segmentar un servicio interno

Para un panel que sólo debe usarse desde la propia máquina hay dos niveles de arreglo:

- En la aplicación: que escuche en `127.0.0.1` en vez de `0.0.0.0` (módulo [10](#curso/10)). Es la mejor opción si puedes cambiarla.
- En el firewall: quitar cualquier `ACCEPT` amplio para ese puerto y bloquear el acceso que no venga de loopback. El orden de las reglas decide si funciona.

Después, verifica las dos cosas: que lo público sigue respondiendo y que lo interno ya no responde desde la red.

### Persistencia de las reglas

Las reglas de iptables viven **en memoria**: se pierden al reiniciar.

```bash
sudo iptables-save > /etc/iptables/rules.v4     # guardar
sudo iptables-restore < /etc/iptables/rules.v4  # cargar
```

En Debian, el paquete `iptables-persistent` las carga en el arranque. Otras distribuciones usan `nftables` (el sucesor, con `nft list ruleset`) o capas como `ufw` y `firewalld`. El modelo de cadenas, orden y política es el mismo.

## 5. TCP wrappers: hosts.allow y hosts.deny

Un mecanismo más antiguo, a nivel de **aplicación**: los programas compilados con `libwrap` consultan dos ficheros antes de aceptar una conexión.

```
# /etc/hosts.deny
sshd: 192.0.2.10
sshd: 198.51.100.0/255.255.255.0
ALL: 203.0.113.5
```

Formato: `servicio: lista de clientes`. Se consulta primero `hosts.allow` (si casa, se permite), después `hosts.deny` (si casa, se deniega), y si no casa ninguno, se permite.

Limitaciones que debes conocer: sólo funciona con programas que lo soporten (muchas versiones modernas de OpenSSH ya no lo incluyen), y actúa **después** de que la conexión TCP llegue al proceso. Un firewall corta antes. En los labs se usa como forma sencilla y comprobable de registrar un bloqueo; en producción, el bloqueo real va en el firewall.

Para escribirlo, recuerda el patrón del módulo [01](#curso/01): la redirección la abre tu shell, así que hace falta `sudo tee -a`.

## 6. fail2ban: baneo automático

fail2ban lee logs, busca patrones de fallo y, cuando una IP supera un umbral, la banea (normalmente con una regla de firewall) durante un tiempo.

| Concepto | Qué es |
|---|---|
| **filter** | Expresiones regulares que reconocen un fallo en una línea de log (`/etc/fail2ban/filter.d/sshd.conf`) |
| **action** | Qué hacer al banear: añadir una regla iptables, mandar un correo… |
| **jail** | Une un filter, un log, una action y unos umbrales |

### Los ficheros

- `jail.conf`: los valores por defecto del paquete. **No lo edites**: una actualización lo sobrescribe.
- `jail.local` (y `jail.d/*.local`): tus cambios. Lo que pongas aquí anula a `jail.conf`.

```ini
[DEFAULT]
bantime  = 1h        # cuánto dura el baneo
findtime = 10m       # ventana en la que se cuentan los fallos
maxretry = 5         # fallos permitidos dentro de findtime

[sshd]
enabled  = true
port     = ssh
logpath  = /var/log/auth.log
```

Lectura: "si una IP falla 5 veces en 10 minutos en el log de SSH, banéala 1 hora". La sección `[DEFAULT]` aplica a todas las jails; cada jail puede sobrescribir valores.

`backend` decide cómo lee el log: `auto`, `polling` (relee el fichero), `systemd` (lee el journal). Si los logs sólo están en un sitio, elige el que corresponda.

### Operar fail2ban

```bash
sudo fail2ban-client -t                       # prueba la configuración
sudo fail2ban-client start | reload | stop
sudo fail2ban-client status                   # jails activas
sudo fail2ban-client status sshd              # contadores e IPs baneadas de una jail
sudo fail2ban-client set sshd banip 192.0.2.10    # banear a mano
sudo fail2ban-client set sshd unbanip 192.0.2.10
sudo fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf   # ¿cuántas líneas casa el filtro?
```

### Leer `status sshd`

```
Status for the jail: sshd
|- Filter
|  |- Currently failed: 2
|  |- Total failed:     184
|  `- File list:        /var/log/auth.log
`- Actions
   |- Currently banned: 1
   |- Total banned:     3
   `- Banned IP list:   192.0.2.10
```

Si `Total failed` sigue en 0 con ataques en el log, el filtro no reconoce las líneas o lee otro fichero: comprueba `File list` y prueba con `fail2ban-regex`.

> Trampa: incluye tu IP de administración en `ignoreip` antes de bajar mucho `maxretry`. Fallar tres veces tu contraseña te dejaría baneado de tu propio servidor.

## 7. Ejercicios

1. INPUT tiene, en este orden: `-A INPUT -p tcp --dport 9000 -j ACCEPT` y `-A INPUT -p tcp --dport 9000 -j DROP`. ¿Está abierto el 9000?
2. ¿Por qué hace falta la regla `ESTABLISHED,RELATED` en un default-deny?
3. Haces `iptables -F INPUT` con política `DROP` mientras estás conectado por SSH. ¿Qué pasa?
4. ¿Por qué tus cambios van en `jail.local` y no en `jail.conf`?

:::solucion Ver respuestas
1. Sí. La primera regla que casa (ACCEPT) decide; la segunda no llega a evaluarse.
2. Para que pasen las respuestas a conexiones ya abiertas, incluidas las que inicia la propia máquina y tu sesión actual. Sin ella, la política DROP las descarta.
3. Borras todas las reglas, incluida la que acepta tu SSH, pero la política sigue en DROP: te quedas fuera.
4. Porque `jail.conf` es del paquete y una actualización lo sobrescribe. `jail.local` se lee después y lo anula.
:::

## Chuleta

```bash
sudo iptables -S INPUT; sudo iptables -L INPUT -n -v --line-numbers
iptables -A|-I|-D INPUT -p tcp --dport N [-s IP] -j ACCEPT|DROP|REJECT
iptables -P INPUT DROP; iptables -D INPUT n
-i lo; -m conntrack --ctstate ESTABLISHED,RELATED
iptables-save > f; iptables-restore < f
echo 'sshd: IP' | sudo tee -a /etc/hosts.deny
fail2ban-client status sshd; fail2ban-client set sshd banip IP; fail2ban-regex log filtro
```
