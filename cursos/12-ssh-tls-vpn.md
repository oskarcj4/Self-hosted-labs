# 12 · SSH, TLS y VPN

> Tres formas de cifrar y autenticar conexiones. Cómo funcionan las llaves de SSH y `authorized_keys`, cómo endurecer `sshd_config` sin romperlo, qué es un certificado TLS y cómo generarlo con openssl, y cómo se monta un túnel WireGuard.

## 1. La idea común: criptografía de clave pública

Las tres tecnologías usan **pares de llaves**:

- La **llave privada** no sale nunca de su dueño. Quien la tiene, "es" esa identidad.
- La **llave pública** se reparte. Sirve para comprobar que alguien tiene la privada correspondiente, sin conocerla.

Autenticarse con llave = demostrar que tienes la privada que corresponde a una pública que el otro lado ya conoce y en la que confía. El problema de seguridad casi nunca es la matemática: es **qué públicas** hay en la lista de confianza y **quién** puede leer la privada.

## 2. SSH: cómo entra alguien

```
cliente                                   servidor
~/.ssh/id_ed25519      (privada)          ~/.ssh/authorized_keys de la cuenta destino
~/.ssh/id_ed25519.pub  (pública) ──copia──▶ una línea por llave pública aceptada
~/.ssh/known_hosts     (huellas de los servidores que ya conoce)
```

Cuando alguien entra como `ana` con llave, `sshd` busca en `/home/ana/.ssh/authorized_keys` una pública que case con la privada del cliente. Si está, entra **sin contraseña**. Por eso:

- Cambiar la contraseña de una cuenta **no** expulsa a quien tiene su llave en `authorized_keys`.
- Una llave añadida por un intruso es persistencia silenciosa: no aparece en `/etc/passwd`, no hace ruido, sobrevive a reinicios.

### Leer authorized_keys

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...  ana@portatil
from="10.0.0.0/8",command="/usr/bin/backup" ssh-rsa AAAAB3Nza...  backup@srv
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQ...  root@kali
```

Cada línea: **opciones** opcionales, **tipo** de llave, la llave en base64 y un **comentario** libre. El comentario lo escribe quien genera la llave: no es de fiar, pero a menudo es una pista (`root@kali`, un nombre que nadie conoce, una llave igual en varias cuentas).

Para saber qué llave usó una sesión concreta, compara huellas (fingerprints):

```bash
ssh-keygen -lf ~/.ssh/authorized_keys     # huella de cada llave de la lista
grep 'Accepted publickey' /var/log/auth.log   # el log muestra la huella usada: SHA256:...
```

Quitar una llave = borrar **su línea**, no el fichero entero (las demás pueden ser legítimas). Revisa todas las cuentas, incluida root, y también `AuthorizedKeysFile` en `sshd_config` por si apunta a otro fichero.

Permisos que sshd exige (si son más abiertos, ignora el fichero, un efecto de `StrictModes`): `~/.ssh` en `700`, `authorized_keys` en `600`, y el home no escribible por otros.

## 3. Endurecer sshd_config

`/etc/ssh/sshd_config` controla el servidor. Formato: `Directiva valor`, una por línea. Las que empiezan por `#` son comentarios: muchas están ahí comentadas mostrando el **valor por defecto**, no el activo.

| Directiva | Valor endurecido | Por qué |
|---|---|---|
| `PermitRootLogin` | `no` (o `prohibit-password`) | Que nadie entre directamente como root |
| `PasswordAuthentication` | `no` | Sólo llaves: elimina la fuerza bruta de contraseñas |
| `KbdInteractiveAuthentication` | `no` | Otra vía de contraseña por PAM |
| `PermitEmptyPasswords` | `no` | Evidente |
| `PubkeyAuthentication` | `yes` | Necesaria si quitas las contraseñas |
| `X11Forwarding` | `no` | Superficie de ataque innecesaria en un servidor |
| `MaxAuthTries` | `3` | Menos intentos por conexión |
| `AllowUsers` / `AllowGroups` | Lista explícita | Sólo esas cuentas pueden entrar |

### Las reglas del fichero que provocan errores

- Para la mayoría de directivas, **gana la primera aparición**. Si hay un `PermitRootLogin yes` arriba y añades `PermitRootLogin no` al final, sigue valiendo `yes`. Edita la línea existente o asegúrate de que la tuya es la única activa.
- Los ficheros de `/etc/ssh/sshd_config.d/*.conf` se incluyen (si hay una línea `Include` al principio) y, por la regla anterior, pueden ganar a lo que escribas en el fichero principal.
- Los bloques `Match` aplican a partir de ahí hasta el siguiente `Match` o el final del fichero. Una directiva escrita debajo de un `Match` sólo aplica a esa condición.

### Validar antes de recargar

```bash
sudo sshd -t                                # sintaxis. Sin salida = correcto
sudo sshd -T | grep -iE 'permitrootlogin|passwordauthentication'   # valores EFECTIVOS
grep -nE '^\s*(PermitRootLogin|PasswordAuthentication)' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf
sudo systemctl reload ssh                   # aplica sin cortar sesiones abiertas
```

`sshd -T` es la fuente de verdad: imprime lo que sshd usaría tras procesar todo el fichero, los includes y los valores por defecto.

> Antes de quitar `PasswordAuthentication`, comprueba que **tú** puedes entrar con llave. Y deja una sesión abierta mientras pruebas una nueva conexión en otra terminal. Si te equivocas, la sesión abierta sigue viva para arreglarlo.

## 4. TLS: certificados

TLS cifra HTTPS y muchos otros protocolos. El servidor presenta un **certificado**: su llave pública más unos datos (nombre, fechas de validez), todo **firmado** por alguien.

| Pieza | Qué es | Confidencial |
|---|---|---|
| Llave privada (`.key`) | La del servidor | Sí: `600`, dueño root o el usuario del servicio |
| Certificado (`.crt`, `.pem`) | Llave pública + identidad + firma | No |
| CA | Quien firma: Let's Encrypt, una CA interna | Su llave privada, muchísimo |

Un certificado **autofirmado** está firmado por su propia llave. Cifra igual de bien, pero el cliente no tiene forma de saber que es legítimo: por eso los navegadores avisan y `curl` exige `-k`. En pruebas y labs, normal; en producción, se usa una CA.

### openssl, la navaja

```bash
# llave + certificado autofirmado en un paso
openssl req -x509 -newkey rsa:2048 -nodes -keyout srv.key -out srv.crt -days 365 -subj "/CN=nombre"
```

| Parte | Significa |
|---|---|
| `req -x509` | Crea un certificado (no una solicitud para una CA) |
| `-newkey rsa:2048` | Genera a la vez una llave RSA nueva de 2048 bits |
| `-nodes` | No cifra la llave con contraseña (si no, el servicio la pediría al arrancar) |
| `-keyout` / `-out` | Dónde guardar la llave / el certificado |
| `-days` | Validez |
| `-subj "/CN=..."` | El nombre del servidor, sin preguntas interactivas |

```bash
openssl x509 -in srv.crt -noout -subject -issuer -dates   # leer un certificado
openssl s_client -connect host:443 -servername host </dev/null   # ver el certificado que presenta un servidor
curl -vk https://host:8443/ -o /dev/null                         # el apretón TLS paso a paso
```

En `x509 -noout -subject -issuer`: si `subject` e `issuer` son iguales, es autofirmado. `notAfter` es la caducidad: un certificado caducado tumba un servicio de golpe.

Después de generar: llave con permisos estrictos (`chmod 600`), y el servicio tiene que poder **leerla** (si corre como un usuario sin privilegios, ajusta dueño o grupo). Y recuerda: un programa lanzado con `&` desde tu terminal muere cuando cierras la sesión; para algo permanente, un servicio (módulo [08](#curso/08)).

## 5. WireGuard: una VPN mínima

WireGuard crea una interfaz de red virtual (`wg0`) por la que viaja tráfico cifrado hacia otros "peers". Cada extremo tiene un par de llaves y conoce la **pública** del otro.

| Concepto | Qué es |
|---|---|
| Interfaz (`wg0`) | Tarjeta de red virtual con una IP privada del túnel (`10.8.0.1/24`) |
| `PrivateKey` | La llave privada de **este** extremo |
| `ListenPort` | Puerto UDP en el que escucha (si otros se conectan a él) |
| `[Peer] PublicKey` | La llave pública del **otro** extremo |
| `Endpoint` | Dónde encontrar al otro: `host:puerto` real (no la IP del túnel) |
| `AllowedIPs` | Qué IPs del túnel pertenecen a ese peer (y se enrutan hacia él) |
| `PersistentKeepalive` | Envía un paquete cada N segundos para mantener abierto el NAT |

```bash
wg genkey | tee priv.key | wg pubkey > pub.key   # par de llaves: la pública se deriva de la privada
umask 077                                         # antes de crear llaves: que salgan con permisos 600
```

Dos formas de levantar el túnel:

- **A mano**, con `ip` y `wg set`: creas la interfaz (`ip link add ... type wireguard`), le das IP (`ip addr add`), le pasas la privada y el peer (`wg set`), y la levantas (`ip link set ... up`).
- **Con `wg-quick`**: escribes `/etc/wireguard/wg0.conf` con secciones `[Interface]` y `[Peer]` y ejecutas `wg-quick up wg0`. Hace los pasos anteriores por ti.

### Comprobar y diagnosticar

```bash
sudo wg show                 # peers, endpoint, 'latest handshake' y bytes transferidos
ip -br addr show wg0         # ¿tiene la IP del túnel? ¿está UP?
ping -c 3 IP-DEL-OTRO-EXTREMO
```

`latest handshake` es la prueba: si no aparece, los dos lados no se han reconocido. Causas habituales: llave pública equivocada (pusiste la tuya en vez de la del otro), endpoint inalcanzable o puerto UDP bloqueado, `AllowedIPs` que no incluye la IP con la que responde el otro, o el otro lado todavía no tiene **tu** pública.

> La privada de WireGuard, como cualquier privada, no se copia a sitios compartidos. Lo que se intercambia es siempre la pública.

## 6. Ejercicios

1. Cambias la contraseña de una cuenta comprometida, pero el intruso sigue entrando. ¿Dónde miras?
2. Añades `PermitRootLogin no` al final de `sshd_config` y `sshd -T` sigue diciendo `yes`. ¿Por qué?
3. ¿Cómo distingues un certificado autofirmado de uno firmado por una CA?
4. `wg show` no muestra `latest handshake`. Da tres causas posibles.

:::solucion Ver respuestas
1. En `~/.ssh/authorized_keys` de esa cuenta (y de root y las demás): una llave del intruso le deja entrar sin contraseña. Compara con las huellas de `Accepted publickey` en el log.
2. Hay otra línea `PermitRootLogin` activa antes, o en un fichero de `sshd_config.d` incluido antes; para esa directiva gana la primera. Busca todas con `grep -n`.
3. Con `openssl x509 -noout -subject -issuer`: en el autofirmado ambos campos coinciden.
4. La llave pública del peer es incorrecta; el endpoint o el puerto UDP no son alcanzables; el otro extremo aún no tiene tu llave pública o tu `AllowedIPs` no casa.
:::

## Chuleta

```bash
ssh-keygen -lf ~/.ssh/authorized_keys; grep 'Accepted publickey' /var/log/auth.log
chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys
sudo sshd -t; sudo sshd -T | grep -i directiva; systemctl reload ssh
openssl req -x509 -newkey rsa:2048 -nodes -keyout k -out c -days 365 -subj "/CN=x"
openssl x509 -in c -noout -subject -issuer -dates; curl -vk https://...
wg genkey | tee priv | wg pubkey > pub; sudo wg show; ip -br addr show wg0
```
