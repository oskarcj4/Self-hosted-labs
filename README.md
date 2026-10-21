<div align="center">

```
 _____                   _             _  ____
|_   _|__ _ __ _ __ ___ (_)_ __   __ _| |/ ___|___ _ __ ___
  | |/ _ \ '__| '_ ` _ \| | '_ \ / _` | | |   / _ \ '__/ _ \
  | |  __/ |  | | | | | | | | | | (_| | | |__|  __/ | | (_) |
  |_|\___|_|  |_| |_| |_|_|_| |_|\__,_|_|\____\___|_|  \___/   LAB
```

# 💸 Adiós a las plataformas que te cobran una fortuna por aprender hacking

### 78 laboratorios reales de DevSecOps, SRE, respuesta a incidentes y hardening.<br>En tu máquina. Gratis. Con un solo comando.

```bash
python server.py
```

**Sin suscripción · Sin cuenta · Sin límite de horas · Sin nube · Sin dependencias de Python**

</div>

---

## 🤔 ¿Por qué existe esto?

Aprender seguridad práctica no debería costar una suscripción mensual, ni
depender de que una VM remota tenga sitio libre, ni cortarse a los 60 minutos
justo cuando por fin entendías el problema.

TerminalCero Lab es la misma experiencia —escenario roto, terminal en el
navegador, botón de **Validar**— pero corriendo **100 % en local** sobre Docker:

| | Plataformas de pago típicas | **TerminalCero Lab** |
|---|---|---|
| Precio | Suscripción mensual o anual | **0 €** |
| Dónde corre | Su nube | **Tu máquina** |
| Límite de tiempo por lab | Sí | **Tú decides** (120 min por defecto, configurable o sin límite) |
| Necesita cuenta | Sí | **No** |
| Funciona sin internet | No | **Sí**, tras construir las imágenes |
| Ves cómo está hecho el lab | No | **Sí**: cada escenario, validador y solución está en el repo |
| Puedes crear tus propios labs | No | **Sí**: una carpeta con 5 ficheros |

## ⚡ Arranque en 30 segundos

```bash
git clone <este-repo> terminalcero-lab
cd terminalcero-lab
python server.py          # en Linux/macOS: python3 server.py
```

Abre **http://localhost:8099** y listo:

1. Elige un lab y lee el **Reto**.
2. **▶ Iniciar**: Docker construye y levanta el escenario.
3. **Terminal**: una shell real en el navegador, como el usuario `analista`.
4. Arregla el problema con comandos de verdad.
5. **✓ Validar**: el `check.sh` del lab te dice qué objetivo falta… o que lo has clavado.
6. ¿Atascado? **Solución** te enseña el paso a paso razonado.

El backend es Python stdlib puro: nada de `pip install`, nada de `node_modules`.

## 🧨 Los labs se autodestruyen solos

No vas a acabar con 30 contenedores zombis comiéndose la RAM. El servidor
limpia por ti (`docker compose down -v`: contenedores, redes **y** volúmenes):

| Cuándo | Qué pasa |
|---|---|
| Resuelves el lab (Validar en la web **o** `bash /opt/lab/check.sh` en la terminal) | Cuenta atrás de **60 s** y se destruye. Hay botón "Mantener abierto" por si quieres seguir trasteando. |
| El lab lleva demasiado tiempo encendido | Se destruye al superar el **TTL** (120 min por defecto), resuelto o no. |
| Un contenedor de lab quedó parado o huérfano | El *reaper* lo borra (revisa cada 10 s). |
| Cierras el servidor (Ctrl+C / SIGTERM) | Se destruyen **todos** los labs. |
| El servidor murió de golpe (kill -9, apagón) | Al volver a arrancarlo borra los labs parados o resueltos que quedaron; los que siguen vivos sin resolver caducan con su TTL, contado desde que arrancaron. |

Ajustes por variable de entorno:

| Variable | Por defecto | Qué hace |
|---|---|---|
| `TCLAB_PORT` | `8099` | Puerto de la interfaz web |
| `TCLAB_DESTROY_GRACE` | `60` | Segundos entre "resuelto" y la destrucción |
| `TCLAB_TTL_MIN` | `120` | Vida máxima de un lab en minutos (`0` = sin límite) |
| `TCLAB_KEEP_ON_EXIT` | — | `1` = no destruir los labs al cerrar el servidor |

> La autodestrucción la hacen `server.py` y `lab.sh`. Si levantas un lab a
> mano con `docker compose up`, nadie lo vigila: bórralo con `./lab.sh stop NN`
> o `./lab.sh reap`.

## 🗺️ Qué vas a practicar

### 🔴 Pista A — Detección y respuesta a incidentes (01–15)

Servidores **ya comprometidos**: echa al intruso, caza la persistencia y deja evidencia.
Inspirados en los casos del canal [@terminalcero](https://www.tiktok.com/@terminalcero).

| # | Lab | Dif. |
|---|---|---|
| 01 | Intruso SSH persistente | ⭐⭐ |
| 02 | Beacon + persistencia en cron | ⭐⭐⭐ |
| 03 | Pentest: vhost oculto → Jenkins | ⭐⭐ |
| 04 | Proceso fantasma: 100 % CPU, monitor 0 % | ⭐⭐⭐ |
| 05 | Cuenta backdoor UID 0 | ⭐⭐ |
| 06 | Servicio systemd + timer rogue | ⭐⭐⭐ |
| 07 | Credenciales de fábrica (lección Mirai) | ⭐⭐ |
| 08 | Segmentación de red (lección Target) | ⭐⭐⭐ |
| 09 | Logs borrados / anti-forense | ⭐⭐⭐ |
| 10 | Binario SUID backdoor | ⭐⭐ |
| 11 | Malware con `chattr +i` | ⭐⭐ |
| 12 | Exfiltración por DNS | ⭐⭐⭐ |
| 13 | Webshell en el web root | ⭐⭐⭐ |
| 14 | Triage: fuerza bruta SSH | ⭐⭐ |
| 15 | Integridad de binarios en PATH | ⭐⭐ |

### 🛡️ Pista B — Hardening y operaciones (16–23)

| # | Lab | Dif. |
|---|---|---|
| 16 | Servicializar una app con systemd | ⭐⭐ |
| 17 | Endurecer `sshd_config` | ⭐⭐ |
| 18 | Firewall base (iptables) | ⭐⭐ |
| 19 | Conectar 2 servidores por VPN (WireGuard) | ⭐⭐⭐ |
| 20 | fail2ban para sshd | ⭐⭐⭐ |
| 21 | TLS + HTTPS | ⭐⭐ |
| 22 | Auditoría con auditd | ⭐⭐ |
| 23 | Usuarios y sudo mínimos | ⭐⭐ |

### 📅 Pista C — 30 días de DevSecOps (24–53)

Un reto al día, de auditar puertos en un Linux a limpiar secretos de imágenes
Docker. Los días 1–15 son un servidor Debian con **systemd real**; los días
16–30 traen **su propio Docker Engine dentro** (Docker-in-Docker), así que
`docker ps` dentro del lab sólo ve el escenario, nunca tus contenedores.

| Día | # | Lab | | Día | # | Lab |
|---|---|---|---|---|---|---|
| 01 | 24 | Auditar servicios en escucha | | 16 | 39 | Auditoría de un stack Compose |
| 02 | 25 | Quitar un puerto público sobrante | | 17 | 40 | Auditar el portal de soporte |
| 03 | 26 | Admin sólo en localhost | | 18 | 41 | Endpoint de métricas publicado |
| 04 | 27 | Desactivar listado de directorios | | 19 | 42 | Consola de depuración sólo local |
| 05 | 28 | Retirar un backup expuesto | | 20 | 43 | Base de datos interna |
| 06 | 29 | Permisos de un secreto | | 21 | 44 | Configuración en sólo lectura |
| 07 | 30 | Uploads escribibles por todos | | 22 | 45 | Worker sin root |
| 08 | 31 | Usuario dedicado para un servicio | | 23 | 46 | Quitar `privileged` a un colector |
| 09 | 32 | Proteger el env file | | 24 | 47 | Webhook sin socket de Docker |
| 10 | 33 | Frontera de escritura de logs | | 25 | 48 | Acotar un secreto de Compose |
| 11 | 34 | Credenciales hardcodeadas | | 26 | 49 | Redes de frontend y backend |
| 12 | 35 | Secreto en el entorno del proceso | | 27 | 50 | Token del entorno a un fichero |
| 13 | 36 | Sudo demasiado amplio | | 28 | 51 | Token fuera del build |
| 14 | 37 | PATH seguro en scripts | | 29 | 52 | Endurecer la imagen de un worker |
| 15 | 38 | Endurecer un cron de root | | 30 | 53 | Limpiar la depuración de un incidente |

Mapeo completo y créditos en [CATALOGO.md](CATALOGO.md).

### 🚨 Pista D — Operaciones / SRE en producción (54–78)

Los incidentes que de verdad te sacan de la cama: un servicio caído, el disco
al 100%, un 502, un certificado caducado, un deploy que hay que revertir. 25
casos del día a día (y algún *game day* con varias averías a la vez), todos
sobre Debian con **systemd real** o con **su propio Docker dentro**. Cada uno
se resuelve y se valida con `check.sh`.

| # | Lab | | # | Lab |
|---|---|---|---|---|
| 54 | Servicio caído: arranque y reinicio | | 67 | PostgreSQL: conexiones remotas |
| 55 | Disco lleno al 100% | | 68 | Migración de datos con rsync |
| 56 | La app no llega a la base de datos | | 69 | Balanceador con un backend caído |
| 57 | SSH a través de un bastión | | 70 | El cron no se ejecuta |
| 58 | Backup a Blob storage por cron (3 AM) | | 71 | Logs de Docker llenan el disco |
| 59 | Restaurar un backup de la BD | | 72 | Certificado TLS caducado |
| 60 | El OOM killer mata el proceso | | 73 | Game day: varias averías a la vez |
| 61 | DNS interno roto | | 74 | Escaneo de imágenes: a 0 CRITICAL |
| 62 | 502 Bad Gateway en nginx | | 75 | Logs centralizados con rsyslog |
| 63 | Bucle de reinicios | | 76 | Sinkhole DNS (estilo Pi-hole) |
| 64 | Healthcheck y autorrecuperación | | 77 | Verificar paquetes antes de instalar |
| 65 | Deploy fallido: rollback | | 78 | De iptables a nftables |
| 66 | Too many open files | | | |

### 📚 Teoría de apoyo

En [`cursos/`](cursos/) hay 14 módulos (00–13) que cubren los labs 01–23:
orientarse en Linux, shell y PATH, procesar texto, permisos, sudo, procesos,
cron, systemd, logs e incidentes, redes, firewall, SSH/TLS/VPN y secretos. No
dan la respuesta de ningún lab: explican los conceptos y cómo leer la salida de
cada herramienta. En la web están en la pestaña **Cursos** del menú, y cada lab
muestra un aviso **¿Dificultad?** con los módulos que conviene leer. El mapa
lab → módulo está en `LAB_CURSOS` de `server.py`.

## 🧰 Requisitos

- **Docker** con **Docker Compose v2** (`docker compose version`). En Windows y macOS, Docker Desktop.
- **Python 3.8+** (sólo la biblioteca estándar).
- Linux, macOS o Windows (Docker Desktop / WSL2).
- Varios labs usan contenedores `privileged` (systemd, auditd, `chattr`,
  Docker-in-Docker) o `NET_ADMIN` (iptables, WireGuard). Corren aislados en tu
  Docker, pero **no expongas los puertos del laboratorio a una red que no controles**.
- Espacio: la primera vez cada lab construye su imagen (unos minutos). Después arranca en segundos.

## 🖥️ ¿Prefieres la línea de comandos?

```bash
./lab.sh list              # lista los labs
./lab.sh start 24          # construye, entra y lo destruye al salir
./lab.sh check 24          # valida (si pasa, destruye el lab)
./lab.sh solution 24       # muestra la solución
./lab.sh reset 24          # re-planta el escenario desde cero
./lab.sh stop 24           # apaga y destruye
./lab.sh stop-all          # destruye todos
./lab.sh reap              # destruye labs resueltos o parados que hayan quedado
./lab.sh web               # lanza la interfaz web
```

Dentro del lab: `cat /RETO.md` y, cuando creas que está, `bash /opt/lab/check.sh`.

## 🔒 Seguro por diseño

- Los "malware" son **scripts inofensivos** (un `sleep`, un listener, un beacon
  que escribe en un log). Existen para que los detectes y los limpies.
- El servidor escucha en `localhost` y **sólo ejecuta acciones fijas**
  (iniciar, parar, reiniciar, validar) sobre IDs de lab del registro. Nada de
  comandos arbitrarios desde la web.
- Los escenarios se plantan una vez y borran sus ficheros de montaje: no hay
  *spoilers* escondidos en el contenedor.

## 🏗️ Anatomía de un lab (crea el tuyo)

```
labs/NN-nombre/
├── RETO.md              # escenario y objetivos
├── docker-compose.yml   # contenedor tc-lab-NN, terminal en 7600+NN
├── Dockerfile           # imagen del lab (incluye ttyd)
├── setup/plant.sh       # planta el escenario roto
├── check.sh             # validador: sale 0 si todo OK y deja la marca de "resuelto"
└── solucion/
    ├── SOLUCION.md      # el paso a paso explicado
    └── solve.sh         # solución automática (sirve para probar el lab)
```

Añade la entrada en `LABS` dentro de `server.py` y aparece en la web.

## 🎯 Método recomendado

1. Lee el reto e **investiga sin mirar la solución**. Apunta lo que encuentres.
2. Arregla. **Valida** hasta que pase.
3. Lee `SOLUCION.md` y compara con tu método: ahí están las lecciones.
4. **Reinicia** el lab y hazlo otra vez de memoria, contra reloj.

---

<div align="center">

**Créditos**

Pistas A y B: casos del canal **Terminal Cero** ([@terminalcero](https://www.tiktok.com/@terminalcero), Guillermo ML).<br>
Pista C: temario inspirado en
[30 Days of DevSecOps Challenges](https://labex.io/es/courses/30-days-of-devsecops-challenges) de LabEx;
escenarios, validadores y soluciones son una implementación propia.<br>
Material de estudio: no redistribuye vídeos ni contenido de esas plataformas.

**Si te ha ahorrado una suscripción, deja una ⭐**

</div>
