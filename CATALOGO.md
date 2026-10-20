# Catálogo — @terminalcero (TikTok)

Perfil: https://www.tiktok.com/@terminalcero · Autor: Guillermo ML · También en YouTube (TerminalCero).
Extraído el 2026-10-18. 16 videos. Las transcripciones son subtítulos automáticos de TikTok (ASR), con errores típicos de reconocimiento.

> Este catálogo es para estudio personal. Los videos y sus textos son del autor; si publicas el laboratorio, da crédito y enlaza al canal, y no redistribuyas sus transcripciones tal cual.

## Casos prácticos reproducibles (núcleo del laboratorio)

| Lab | Video | Tema | Técnicas / comandos clave |
|-----|-------|------|----------------------------|
| 01 | [Expulsar a un hacker en 60s](https://www.tiktok.com/@terminalcero/video/7697584847849786626) | Intruso SSH con persistencia | `w`, `kill`, `authorized_keys`, trampa en `.bashrc`, firewall |
| 01 | [03:14 AM: el hacker seguía dentro](https://www.tiktok.com/@terminalcero/video/7697639418450038038) | Sesión activa + backdoor | sesiones PID, backdoor en memoria compartida, bloqueo de rango en firewall |
| 02 | [60 segundos para echar a un hacker](https://www.tiktok.com/@terminalcero/video/7697402057946434838) | Respuesta a incidentes | `ss -tulpn`, binario impostor en `/tmp`, `crontab`, `kill -9` |
| 02 | [Servidor al 100% pero el monitor dice 0%](https://www.tiktok.com/@terminalcero/video/7697576425972419862) | Virus fantasma / forense | proceso oculto al monitor, consumo real vs reportado |
| 03 | [Pentesting en vivo: subdominio oculto](https://www.tiktok.com/@terminalcero/video/7697640489805303062) | Recon web | fuzzing de vhosts/subdominios, panel Jenkins expuesto, versión vulnerable |

## Historias / divulgación (no reproducibles como lab — son narrativa)

| Video | Tema |
|-------|------|
| [Jobs y Wozniak y la caja azul](https://www.tiktok.com/@terminalcero/video/7698061312399658262) | Phreaking histórico (blue box) |
| [WannaCry parado con $10](https://www.tiktok.com/@terminalcero/video/7698049478095326486) | Kill-switch del ransomware |
| [Silbato de cereales / phreaking](https://www.tiktok.com/@terminalcero/video/7697958473597766934) | Cap'n Crunch, 2600 Hz |
| [Banco de Bangladesh / SWIFT](https://www.tiktok.com/@terminalcero/video/7697577964409523478) | Fraude SWIFT, typo "fandation" |
| [Casino por la pecera](https://www.tiktok.com/@terminalcero/video/7697398889745239318) | IoT, pivote desde termómetro |
| [Target por el aire acondicionado](https://www.tiktok.com/@terminalcero/video/7697382412166253846) | Supply chain, segmentación de red |
| [Jeep Cherokee en autopista](https://www.tiktok.com/@terminalcero/video/7697368589426380054) | CAN bus, IoT automotriz |
| [Botnet Mirai tumba Twitter/Netflix](https://www.tiktok.com/@terminalcero/video/7697353578142256406) | DDoS, credenciales de fábrica, DNS (Dyn) |
| [Cable O.MG](https://www.tiktok.com/@terminalcero/video/7695905218260782358) | BadUSB / HID injection |
| [¿Dedicarte a la ciberseguridad?](https://www.tiktok.com/@terminalcero/video/7698089040477883671) | Carrera / motivación |

## Tutorial / homelab

| Video | Tema | Posible lab futuro |
|-------|------|--------------------|
| [Pi-Hole contra anuncios](https://www.tiktok.com/@terminalcero/video/7695897710863535363) | DNS sinkhole en red local | docker-compose con pihole/pihole |

## Notas de las historias para convertir en labs defensivos

Varias "historias" tienen una lección técnica que SÍ se puede convertir en lab defensivo más adelante:
- **Target / Casino** → segmentación de red: VLANs, un contenedor "proveedor" que NO debería alcanzar la red interna. Lab de firewall/iptables.
- **Mirai** → credenciales de fábrica: un servicio con `admin/admin`, el reto es encontrarlo y endurecerlo.
- **Bangladesh** → validación/monitorización de transacciones y alertas.

---

# Pista C — 30 días de DevSecOps (labs 24–53)

Temario inspirado en el curso [30 Days of DevSecOps Challenges](https://labex.io/es/courses/30-days-of-devsecops-challenges) de LabEx (consultado el 2026-10-19).
Sólo se toma la idea de cada día; los escenarios, validadores (`check.sh`) y soluciones son una implementación propia que corre en local.

| Día | Lab | Carpeta | Tema | Técnicas clave |
|-----|-----|---------|------|----------------|
| 01 | 24 | `24-d01-servicios-en-escucha` | Auditar servicios en escucha | `ss -tulpn`, informe de línea base |
| 02 | 25 | `25-d02-puerto-publico-sobrante` | Quitar un puerto público sobrante | `listen` de nginx, `nginx -t` |
| 03 | 26 | `26-d03-admin-solo-localhost` | Admin sólo en localhost | bind a `127.0.0.1`, túnel SSH |
| 04 | 27 | `27-d04-listado-directorios` | Desactivar listado de directorios | `autoindex off` |
| 05 | 28 | `28-d05-backup-expuesto` | Retirar un backup expuesto | web root, logs de acceso |
| 06 | 29 | `29-d06-permisos-secreto` | Permisos de un secreto | `chown root:billing`, `0640` |
| 07 | 30 | `30-d07-uploads-world-writable` | Uploads escribibles por todos | `find -perm`, `755/644` |
| 08 | 31 | `31-d08-usuario-de-servicio` | Usuario dedicado para un servicio | `useradd -r`, drop-in `User=` |
| 09 | 32 | `32-d09-env-file-servicio` | Proteger el env file | `EnvironmentFile`, `0600`, `.bak` |
| 10 | 33 | `33-d10-frontera-de-logs` | Frontera de escritura de logs | `logrotate create 0640` |
| 11 | 34 | `34-d11-credenciales-hardcodeadas` | Credenciales hardcodeadas | fichero `0600` + `source` |
| 12 | 35 | `35-d12-secreto-en-entorno` | Secreto en el entorno del proceso | `/proc/PID/environ`, patrón `*_FILE` |
| 13 | 36 | `36-d13-sudo-demasiado-amplio` | Sudo demasiado amplio | `visudo -cf`, comando exacto |
| 14 | 37 | `37-d14-path-seguro-en-scripts` | PATH seguro en scripts | `PATH` explícito, dirs `0777` |
| 15 | 38 | `38-d15-cron-root-endurecido` | Endurecer un cron de root | `install -m 0755`, `cron.d` |
| 16 | 39 | `39-d16-auditoria-compose` | Auditoría de un stack Compose | `docker inspect`, runtime vs. disco |
| 17 | 40 | `40-d17-auditoria-portal-soporte` | Auditar el portal de soporte | env, puertos, montajes, usuario |
| 18 | 41 | `41-d18-endpoint-metricas` | Endpoint de métricas publicado | quitar `ports`, red interna |
| 19 | 42 | `42-d19-consola-debug-local` | Consola de depuración sólo local | `127.0.0.1:5555:5555` |
| 20 | 43 | `43-d20-base-datos-interna` | Base de datos interna | sin `ports` en la BD |
| 21 | 44 | `44-d21-config-solo-lectura` | Configuración en sólo lectura | `:ro`, `tmpfs` |
| 22 | 45 | `45-d22-worker-no-root` | Worker sin root | `USER 10001`, `chown` |
| 23 | 46 | `46-d23-colector-sin-privileged` | Quitar privileged a un colector | `privileged`, `sysctl` |
| 24 | 47 | `47-d24-webhook-docker-socket` | Webhook sin socket de Docker | `docker.sock` |
| 25 | 48 | `48-d25-secreto-compose-acotado` | Acotar un secreto de Compose | anclas YAML, `secrets:` |
| 26 | 49 | `49-d26-redes-separadas` | Redes de frontend y backend | `networks`, `internal: true` |
| 27 | 50 | `50-d27-token-en-entorno` | Token del entorno a un fichero | `secrets:` + `*_FILE` |
| 28 | 51 | `51-d28-token-en-build` | Token fuera del build | `docker history`, `docker save`, `prune` |
| 29 | 52 | `52-d29-imagen-worker-segura` | Endurecer la imagen de un worker | `FROM` fijado, `.dockerignore` |
| 30 | 53 | `53-d30-limpieza-debug-incidente` | Limpiar la depuración de un incidente | `compose.override.yaml`, `--remove-orphans` |

Familias técnicas:
- **Días 01–15**: Debian 12 con systemd real (`privileged`, `cgroup: host`). El escenario se planta una sola vez y luego se borran los ficheros de montaje.
- **Días 16–30**: Docker-in-Docker (`docker:27.5.1-dind`) con `python:3.12-alpine` precargada, sin necesidad de internet dentro del lab. Los proyectos viven en `/home/analista/<proyecto>`.

Cada lab incluye `RETO.md`, `check.sh` (validador que deja la marca de resuelto), `solucion/SOLUCION.md` y `solucion/solve.sh` (solución automática que se usó para probar el lab).
