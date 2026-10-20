# 10 · Redes para defensores

> Lo mínimo de redes para saber qué escucha tu servidor, a quién habla y quién puede alcanzarlo: interfaces e IPs, puertos y sockets, cómo leer `ss`, la diferencia entre `127.0.0.1` y `0.0.0.0`, HTTP con `curl` (incluida la cabecera `Host`) y DNS.

## 1. Interfaces, IPs y rutas

```bash
ip -br addr          # interfaces y sus IPs, en formato breve
ip route             # por dónde sale el tráfico (default via = la puerta de enlace)
hostname -I          # sólo las IPs
cat /etc/hosts       # nombres resueltos localmente, antes que DNS
cat /etc/resolv.conf # qué servidor DNS usa la máquina
```

```
lo        UNKNOWN  127.0.0.1/8 ::1/128
eth0      UP       172.18.0.5/16
```

- `lo` (loopback): la máquina hablando consigo misma. Lo que sólo escucha aquí **no** es alcanzable desde fuera.
- `eth0`: la interfaz de red real. `/16` es la máscara: cuántas IPs están en la misma red local.

Rangos privados que verás: `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`. Los de documentación, usados en ejemplos: `192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24`.

## 2. Puertos y sockets

Una IP identifica la máquina; un **puerto** (0-65535) identifica el servicio dentro de ella. Un servicio "escucha" en una combinación IP + puerto + protocolo (TCP o UDP).

| Puerto | Servicio habitual |
|---|---|
| 22 | SSH |
| 53 | DNS (UDP y TCP) |
| 80 / 443 | HTTP / HTTPS |
| 3306 / 5432 / 6379 | MySQL / PostgreSQL / Redis (no deberían estar en internet) |
| 8080, 8000, 9000 | Apps y paneles de desarrollo o administración |
| 51820/udp | WireGuard |

Los puertos por debajo de 1024 sólo los puede abrir root (o un proceso con la capacidad `CAP_NET_BIND_SERVICE`). Un puerto alto "raro" abierto por un usuario sin privilegios es típico de un beacon o de una shell remota.

## 3. ss: qué escucha y quién habla

`ss` sustituye a `netstat`. Los flags se combinan:

| Flag | Significa |
|---|---|
| `-t` / `-u` | TCP / UDP |
| `-l` | Sólo sockets en escucha (servidores) |
| `-n` | Números, sin traducir a nombres (más rápido y sin ambigüedad) |
| `-p` | Muestra el proceso (requiere sudo para ver los de otros usuarios) |
| `-a` | Todos: en escucha y conexiones |
| `-H` | Sin cabecera (para procesar con awk) |

```bash
sudo ss -tulpn                  # el comando estrella: qué escucha y qué proceso
sudo ss -tnp state established  # conexiones activas
ss -tn dst 192.0.2.10           # conexiones hacia una IP
ss -tln sport = :443            # quién escucha en el 443
```

### Leer `ss -tulpn`

```
Netid State  Local Address:Port  Peer Address:Port Process
tcp   LISTEN 0.0.0.0:22          0.0.0.0:*         users:(("sshd",pid=88,fd=3))
tcp   LISTEN 127.0.0.1:9000      0.0.0.0:*         users:(("python3",pid=120,fd=5))
tcp   LISTEN 0.0.0.0:4444        0.0.0.0:*         users:(("algo",pid=301,fd=4))
tcp   LISTEN [::]:80             [::]:*            users:(("nginx",pid=60,fd=7))
```

La columna clave es **Local Address**:

| Dirección | Quién puede conectar |
|---|---|
| `0.0.0.0:P` | Cualquiera que llegue a cualquier IP de la máquina (IPv4) |
| `[::]:P` o `*:P` | Cualquiera, IPv6 (y a menudo también IPv4) |
| `127.0.0.1:P` o `[::1]:P` | Sólo la propia máquina |
| `172.18.0.5:P` | Sólo quien llegue por esa interfaz concreta |

`Process` te da el PID: de ahí a `/proc/PID/exe` para saber qué binario es (módulo [06](#curso/06)).

Preguntas para cada línea: ¿lo esperaba?, ¿qué programa es?, ¿necesita escuchar en todas las interfaces o le bastaría `127.0.0.1`?, ¿está protegido por el firewall (módulo [11](#curso/11))?

### Escuchar no es lo mismo que ser alcanzable

Un servicio en `0.0.0.0` puede estar bloqueado por el firewall. Uno en `127.0.0.1` no se alcanza desde fuera aunque el firewall esté abierto. Para saber si algo está **expuesto** necesitas las dos cosas: `ss` (dónde escucha) e `iptables` (qué deja pasar). Y la prueba definitiva: conectar desde fuera.

```bash
curl -s -m 3 http://127.0.0.1:9000/ >/dev/null && echo "responde en loopback"
curl -s -m 3 http://$(hostname -I | awk '{print $1}'):9000/ >/dev/null && echo "responde por la red"
nc -zv -w 2 IP PUERTO      # ¿acepta conexión TCP? (si netcat está)
```

> Probar desde la propia máquina contra `localhost` pasa por la interfaz `lo`, y muchas reglas de firewall aceptan todo lo de `lo`. Para comprobar exposición, prueba contra la IP de la red o desde otra máquina.

## 4. HTTP con curl

`curl` es tu navegador de terminal. Para un defensor importa ver **cabeceras** y **códigos**.

```bash
curl -s http://host/                  # cuerpo de la respuesta (-s silencia la barra de progreso)
curl -I http://host/                  # sólo cabeceras (petición HEAD)
curl -sv http://host/ -o /dev/null    # -v: la conversación completa, peticiones y cabeceras
curl -s -o /dev/null -w '%{http_code}\n' http://host/   # sólo el código de estado
curl -k https://host/                 # acepta certificados no verificados (sólo en pruebas)
curl -m 5 ...                         # timeout de 5 s
```

### Códigos de estado

| Código | Significa |
|---|---|
| `200` | OK |
| `301` / `302` | Redirección (mira la cabecera `Location`) |
| `401` / `403` | Falta autenticación / prohibido |
| `404` | No existe (o el servidor finge que no existe) |
| `500` / `502` | Error del servidor / el proxy no llega a la app de detrás |

### Las cabeceras delatan el software

```
HTTP/1.1 200 OK
Server: nginx/1.22.1
X-Powered-By: PHP/8.2.7
```

`Server`, `X-Powered-By` y cabeceras propias de cada producto (muchos paneles añaden una con su nombre y versión) son **fingerprinting** gratuito: dicen qué software y qué versión corre. Para el atacante, es la lista de CVEs que probar; para el defensor, información que no debería regalar.

### La cabecera Host y los virtual hosts

Una sola IP puede servir muchos sitios. El servidor web decide cuál mostrar por la cabecera `Host` de la petición, no por la IP. Por eso:

```bash
curl -s http://IP/                              # el sitio por defecto
curl -s -H 'Host: otro.ejemplo.test' http://IP/ # otro sitio en la misma IP
```

Un sitio "oculto" que no está enlazado ni en DNS público sigue respondiendo si aciertas el nombre en `Host`. Probar una lista de nombres y comparar códigos o tamaños de respuesta es cómo se descubren (en una auditoría autorizada). Fíjate en lo que **cambia** entre respuestas: el código, el tamaño (`-w '%{size_download}'`), el título.

```bash
for n in uno dos tres; do
  printf '%s %s\n' "$(curl -s -o /dev/null -w '%{http_code} %{size_download}' -H "Host: $n.ejemplo.test" http://IP/)" "$n"
done
```

## 5. DNS en dos minutos

DNS traduce nombres a IPs. Un nombre se lee de derecha a izquierda: `api.datos.ejemplo.com` es el subdominio `api.datos` del dominio base `ejemplo.com`, bajo el TLD `com`.

```bash
getent hosts ejemplo.com     # resuelve como lo haría cualquier programa (incluye /etc/hosts)
dig +short ejemplo.com       # pregunta al DNS directamente (si dig está)
dig +short TXT ejemplo.com   # otros tipos de registro
```

| Registro | Contiene |
|---|---|
| `A` / `AAAA` | IPv4 / IPv6 |
| `CNAME` | Alias de otro nombre |
| `MX` | Servidor de correo |
| `TXT` | Texto libre (verificaciones, SPF… y a veces datos) |

### Por qué DNS sirve para exfiltrar

Para resolver `xxxx.ejemplo.com`, la pregunta viaja hasta el servidor DNS autoritativo de `ejemplo.com`. Si ese servidor lo controla un atacante, **recibe** `xxxx`. Basta con codificar datos robados en la parte `xxxx` y hacer muchas consultas. Funciona aunque el firewall bloquee todo menos el puerto 53, y no toca HTTP. La detección está en los logs de consultas (módulo [09](#curso/09), sección 8). Bloquear el dominio base en el resolver corta el canal.

## 6. Ver tráfico

```bash
sudo tcpdump -ni eth0 port 53            # consultas DNS en vivo
sudo tcpdump -ni any host 192.0.2.10     # todo lo de una IP
sudo tcpdump -ni eth0 -c 20 'tcp port 4444'   # 20 paquetes y para
```

`-n` evita traducir IPs a nombres (que genera más tráfico DNS y confunde), `-i` elige interfaz.

## 7. Ejercicios

1. `ss` muestra `127.0.0.1:6379` y `0.0.0.0:6380`. ¿Cuál es alcanzable desde otra máquina, en principio?
2. ¿Cómo sabes qué binario está detrás de un puerto abierto?
3. Una petición con `Host: a.ejemplo.test` devuelve 404 y con `Host: b.ejemplo.test` devuelve 200 con otro contenido, misma IP. ¿Qué significa?
4. ¿Por qué un firewall que sólo permite DNS saliente no impide la exfiltración?

:::solucion Ver respuestas
1. El `6380` en `0.0.0.0`, salvo que un firewall lo bloquee. El `6379` sólo acepta conexiones de la propia máquina.
2. `sudo ss -tulpn` da el PID, y `ls -l /proc/PID/exe` la ruta real del binario.
3. Que el servidor tiene un virtual host configurado para `b`. Es otro sitio servido en la misma IP.
4. Porque los datos pueden viajar dentro de los nombres consultados hacia un dominio controlado por el atacante. La respuesta y la pregunta son DNS legítimo en forma.
:::

## Chuleta

```bash
ip -br addr; ip route; cat /etc/resolv.conf
sudo ss -tulpn; sudo ss -tnp state established
curl -sI URL; curl -sv URL -o /dev/null; curl -s -o /dev/null -w '%{http_code}' URL
curl -H 'Host: nombre' http://IP/; curl -k https://...
getent hosts nombre; dig +short nombre
sudo tcpdump -ni any port 53
```
