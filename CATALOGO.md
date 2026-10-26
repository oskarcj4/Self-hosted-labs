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

# Pista D — Operaciones / SRE en producción (labs 54–78)

Casos reales de operaciones: diagnóstico de servicios, redes, almacenamiento, despliegues, respuesta a incidentes y endurecimiento. Escenarios, validadores y soluciones de implementación propia, que corren en local. La mayoría son Debian 12 con systemd real; algunos (varias máquinas) añaden contenedores auxiliares, y los de Docker/CVE usan Docker-in-Docker.

| Lab | Carpeta | Tema | Técnicas clave |
|-----|---------|------|----------------|
| 54 | `54-servicio-caido-reinicio` | Servicio caído: arranque y reinicio | `systemctl`, `journalctl`, `Restart=` |
| 55 | `55-disco-lleno` | Disco lleno al 100% | `df`, `du`, `lsof +L1` (ficheros borrados en uso) |
| 56 | `56-app-no-llega-bd` | La app no llega a la base de datos | `ss`, `nc`, cortafuegos entre dos hosts |
| 57 | `57-ssh-bastion` | SSH a través de un bastión | `ProxyJump`, llaves, `~/.ssh/config` |
| 58 | `58-backup-blob-cron` | Backup a Blob storage por cron (3 AM) | `cron.d`, `rclone`, `flock`, rotación |
| 59 | `59-restaurar-backup-bd` | Restaurar un backup de la BD | `pg_restore`, verificación de integridad |
| 60 | `60-oom-killer` | El OOM killer mata el proceso | `dmesg`, `MemoryMax`, cgroups |
| 61 | `61-dns-roto` | DNS interno roto | `resolv.conf`, `search`, `getent`, dnsmasq |
| 62 | `62-502-bad-gateway` | 502 Bad Gateway en nginx | upstream, permisos, `proxy_read_timeout` |
| 63 | `63-bucle-reinicios` | Bucle de reinicios | `NRestarts`, `EnvironmentFile`, `reset-failed` |
| 64 | `64-healthcheck-autorrecuperacion` | Healthcheck y autorrecuperación | watchdog con timer, alerta |
| 65 | `65-deploy-fallido-rollback` | Deploy fallido: rollback | releases, symlink atómico |
| 66 | `66-too-many-open-files` | Too many open files | `LimitNOFILE`, `/proc/PID/limits` |
| 67 | `67-postgres-conexiones-remotas` | PostgreSQL: conexiones remotas | `listen_addresses`, `pg_hba.conf`, scram |
| 68 | `68-migracion-rsync` | Migración de datos con rsync | `rsync -aH --delete`, hardlinks, idempotencia |
| 69 | `69-balanceador-backend-caido` | Balanceador con un backend caído | upstream, `max_fails`, `proxy_next_upstream` |
| 70 | `70-cron-no-se-ejecuta` | El cron no se ejecuta | `cron.d`, campo de usuario, `%` escapado, newline |
| 71 | `71-docker-logs-disco` | Logs de Docker llenan el disco | `json-file`, `max-size`, `max-file` (DinD) |
| 72 | `72-certificado-caducado` | Certificado TLS caducado | `openssl ca`, `subjectAltName`, `nginx reload` |
| 73 | `73-game-day-multifallo` | Game day: varias averías a la vez | triaje por capas, postmortem |
| 74 | `74-escaneo-imagenes` | Escaneo de imágenes: a 0 CRITICAL | `grype`, CVE, imagen base (DinD) |
| 75 | `75-rsyslog-centralizado` | Logs centralizados con rsyslog | `imtcp`, ruleset, cola en disco |
| 76 | `76-dns-sinkhole` | Sinkhole DNS (estilo Pi-hole) | dnsmasq, feed de threat intel, `log-queries` |
| 77 | `77-verificar-paquetes` | Verificar paquetes antes de instalar | `gpg --verify` + `VALIDSIG`, `SHA256SUMS` |
| 78 | `78-iptables-a-nftables` | De iptables a nftables | `nftables`, set, `limit rate`, policy drop |

Cada lab incluye `RETO.md`, `check.sh`, `solucion/SOLUCION.md` y `solucion/solve.sh`, igual que las demás pistas.

---

# Pista E — Defensa anti-DDoS/DoS (labs 79–84)

Lado azul: distinguir un flood malicioso del tráfico legítimo de alto volumen y mitigar por capas (kernel, firewall, Apache, WAF, reverse proxy, CDN). Todo el tráfico se genera **en local** contra el propio contenedor (`ab`, probador incluido), nunca contra terceros. Acompaña al curso [14 · DDoS: defensa en profundidad](cursos/14-ddos-defensa-en-profundidad.md). Inspirado en la lección Mirai del catálogo (botnet, DDoS a Dyn).

| Lab | Carpeta | Tema | Técnicas clave |
|-----|---------|------|----------------|
| 79 | `79-ddos-triage` | Triage: ¿ataque o tráfico legítimo? | `awk`/`uniq`, agrupar por /24, User-Agent, falsos positivos (health check, crawler, NAT) |
| 80 | `80-apache-anti-dos` | Endurecer Apache contra un flood HTTP | `mod_reqtimeout`, `mod_evasive`, `Timeout`/`KeepAliveTimeout`, `ab` |
| 81 | `81-slowloris` | Mitigar Slowloris (slow-DoS) | `RequestReadTimeout header=...,MinRate=...`, probador acotado a localhost |
| 82 | `82-waf-modsecurity` | WAF: ModSecurity + OWASP CRS | `SecRuleEngine On`, CRS, bloqueo de SQLi (403), capa 7 |
| 83 | `83-reverse-proxy-ratelimit` | Reverse proxy con rate limiting (nginx) | `limit_req_zone`, `limit_req burst=... nodelay`, token bucket, equivalente local a una CDN |
| 84 | `84-ir-postmortem-ddos` | Respuesta a incidentes tras un DDoS | `iptables hashlimit`/blocklist, postmortem blameless |

> Nota sobre Cloudflare: es una CDN/WAF *alojada*, no corre en un contenedor. El lab 83 monta el equivalente local que sí controlas (reverse proxy con rate limiting); el curso 14 explica cuándo hace falta una CDN de verdad (floods volumétricos que saturan tu ancho de banda de entrada).

# Pista F — Pipeline CI y runtime Docker (labs 85–96)

Gates de CI, despliegue sin corte, supply chain y endurecimiento del contenedor.
Escenarios, validadores y soluciones de implementación propia. 85–86: Debian 12
con systemd y nginx. 87–96: Docker-in-Docker (`docker:27.5.1-dind`).

| Lab | Carpeta | Tema | Técnicas clave |
|-----|---------|------|----------------|
| 85 | `85-parche-rolling` | Parche rolling sin downtime | dos backends, `systemctl restart` de la app, PID de nginx intacto |
| 86 | `86-blue-green` | Cutover blue-green | upstream green→blue, `nginx reload`, green vivo para rollback |
| 87 | `87-pipeline-secretos` | Pipeline CI que filtra secretos | token fuera del YAML, sin `docker.sock`, sin `pull_request` |
| 88 | `88-gate-pipeline` | Gate de seguridad saltado | quitar `continue-on-error`, `needs:`, scan en verde |
| 89 | `89-capabilities` | Capabilities y no-new-privileges | `cap_drop: ALL`, `no-new-privileges`, sin `SYS_ADMIN` |
| 90 | `90-escape-host` | Cerrar vías de escape al host | sin privileged/sock/`/`/`pid: host`/`network: host` |
| 91 | `91-admission-compose` | Admission: política de Compose | `docker compose config` + jq, 12 bypasses de red team, fail-closed, gate en `deploy.sh` |
| 92 | `92-sbom-firmado` | SBOM firmado y verificado | ancla de confianza fija, SBOM con `apk info -v`, id de imagen atado, clave del atacante |
| 93 | `93-iac-compose` | Scan IaC del Compose | escáner con corpus de tests, tag implícito/puerto de registro, `user: 0`, `${VAR:-true}` |
| 94 | `94-xtrace-secreto` | xtrace que filtra el secreto | `set -eux` escondido, base64, artefactos, masking literal en el runner |
| 95 | `95-seccomp` | seccomp: perfil propio | perfil derivado del default sin `ptrace`/`process_vm_*`, EPERM en runtime |
| 96 | `96-actions-pin` | Actions sin pin de SHA | mirror git, `^{commit}` vs tag anotado, tag secuestrado, reusable workflows |

# Pista G — AppSec web (labs 97–101)

Apps web intencionadamente vulnerables, estilo máquinas fácil/media de Hack The
Box. Cada lab se puede resolver de **dos formas**: 🔴 red (explotar y capturar la
flag) o 🔵 blue (arreglar la vulnerabilidad). El validador acepta cualquiera de
las dos vías. La flag solo la lee el usuario `app`; el alumno es `analista` sin
sudo, así que debe explotar la app o arreglarla. `solucion/` trae **solo el
arreglo** (blue), nunca el camino de explotación.

| Lab | Carpeta | Tema | Arquetipo HTB / OWASP |
|-----|---------|------|------------------------|
| 97 | `97-web-sqli-login` | Portal con SQLi en el login | SQLi clásico en login · OWASP A03 |
| 98 | `98-web-cmdi-dns` | Command injection en herramienta de red | parámetro a `shell=True` · OWASP A03 |
| 99 | `99-web-ssrf-fetch` | Gateway con SSRF | fetcher confused-deputy a metadata interno · OWASP A10 |
| 100 | `100-auth-jwt-weak` | API con JWT `alg:none` | confusión de algoritmo JWT · OWASP A07 |
| 101 | `101-web-xxe-import` | Importador XML con XXE | entidad externa `lxml` lee fichero · OWASP A05 |

# Pista H — Máquinas HTB (labs 102+)

Máquinas vulnerables a propósito con **contenedor atacante**, estilo HTB. Al
iniciar, un popup pregunta si juegas 🔴 red (sin acceso al target; atacas por la
red desde una caja atacante y entregas las banderas **user** y **root**) o 🔵
blue (acceso total + validador del arreglo). Mismo compose para ambos modos.

| Lab | Carpeta | Tema | Clave |
|-----|---------|------|-------|
| 102 | `102-firewall-bypass` | Saltar / blindar un firewall | iptables: confianza en puerto de origen y orden de reglas |
