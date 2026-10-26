#!/usr/bin/env python3
"""
TerminalCero Lab — backend local (stdlib, cero dependencias).

Sirve la interfaz web (./web) y una pequeña API que levanta/para/valida los
contenedores Docker de cada lab. Pensado para correr SOLO en tu máquina:

    python3 server.py            # http://localhost:8099

Cada lab es una carpeta en ./labs/NN-nombre con su docker-compose.yml. El
backend nunca ejecuta comandos arbitrarios: sólo acciones fijas (start, stop,
reset, check, status) sobre IDs de lab que existen en el registro de abajo.
Cada contenedor expone una terminal web (ttyd) en el puerto 7600+NN del host.

Auto-destrucción (contenedores + redes + volúmenes, `compose down -v`):
  * Lab resuelto (Validar OK en la web, o check.sh OK desde la terminal, que
    deja la marca /tmp/.tclab-solved): se destruye tras TCLAB_DESTROY_GRACE
    segundos (60 por defecto). La web muestra la cuenta atrás y permite
    "Mantener abierto".
  * Tiempo de vida máximo: TCLAB_TTL_MIN minutos (120 por defecto; 0 = sin
    límite) desde que arrancó el contenedor, esté resuelto o no.
  * Contenedores de lab parados/huérfanos (p.ej. tras un reinicio de Docker).
  * Al cerrar el servidor (Ctrl+C / SIGTERM) se destruyen todos los labs
    (TCLAB_KEEP_ON_EXIT=1 lo desactiva). Al arrancar, el reaper limpia los
    labs parados o resueltos que dejara una ejecución anterior que no cerró
    bien; los vivos sin resolver caducan con su TTL (cuenta desde StartedAt).
"""
import json
import os
import re
import signal
import subprocess
import sys
import threading
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

ROOT = os.path.dirname(os.path.abspath(__file__))
LABS_DIR = os.path.join(ROOT, "labs")
WEB_DIR = os.path.join(ROOT, "web")
CURSOS_DIR = os.path.join(ROOT, "cursos")
PORT = int(os.environ.get("TCLAB_PORT", "8099"))
TTYD_BASE = 7600  # puerto host de la terminal = TTYD_BASE + número de lab
SOLVED_MARKER = "/tmp/.tclab-solved"  # la crea check.sh dentro del lab al pasar
GRACE_S = int(os.environ.get("TCLAB_DESTROY_GRACE", "60"))
TTL_MIN = int(os.environ.get("TCLAB_TTL_MIN", "120"))
KEEP_ON_EXIT = os.environ.get("TCLAB_KEEP_ON_EXIT") == "1"
REAP_EVERY_S = 10

# Registro de labs. Única fuente de verdad de metadatos; el contenido (RETO.md,
# SOLUCION.md) se lee del disco. 'track': A = detección/respuesta, B = hardening,
# C = 30 días de DevSecOps, D = operaciones/SRE, E = defensa anti-DDoS/DoS,
# F = pipeline CI y runtime Docker.
# 'cats': categorías visibles en la tarjeta (DevSecOps,
# DevOps, SysAdmin, Redes, Forense, Pentest, Docker). 'desc': resumen de una línea para la tarjeta.
LABS = [
    ("01", "Intruso SSH persistente", "A", 2, ["DevSecOps"],
     "El atacante sigue entrando aunque cambiaste la contraseña. Corta su acceso y su persistencia.",
     ["auth.log", "authorized_keys", "dotfiles", "hosts.deny"]),
    ("02", "Beacon + persistencia en cron", "A", 3, ["DevSecOps"],
     "Un servidor exfiltra datos al puerto 4444. Caza el proceso impostor y su cron.",
     ["ss", "/proc", "binario impostor", "cron"]),
    ("03", "Pentest: vhost oculto → Jenkins", "A", 2, ["Pentest"],
     "Auditoría autorizada: descubre un panel interno escondido tras un virtual host.",
     ["recon web", "fuzzing vhosts", "fingerprint"]),
    ("04", "Proceso fantasma: 100% CPU, monitor 0%", "A", 3, ["Forense", "SysAdmin"],
     "El monitor miente sobre el consumo. Usa /proc para encontrar el proceso real.",
     ["/proc", "proceso oculto", "consumo real"]),
    ("05", "Cuenta backdoor UID 0", "A", 2, ["DevSecOps", "SysAdmin"],
     "Hay dos cuentas con UID 0. Encuentra la cuenta root falsa y elimínala.",
     ["/etc/passwd", "uid 0", "awk"]),
    ("06", "Servicio systemd + timer rogue", "A", 3, ["DevSecOps"],
     "Un .service y un .timer disfrazados relanzan un beacon cada minuto. Desactívalos.",
     ["systemctl", ".service", ".timer", "persistencia"]),
    ("07", "Credenciales de fábrica (lección Mirai)", "A", 2, ["DevSecOps"],
     "Un panel IoT sigue con admin/admin. Endurécelo antes de que lo encuentre una botnet.",
     ["admin/admin", "hardening", "secretos"]),
    ("08", "Segmentación de red (lección Target)", "A", 3, ["Redes", "DevSecOps"],
     "Un panel interno queda abierto a todos. Segmenta el tráfico con el firewall.",
     ["iptables", "zonas", "firewall"]),
    ("09", "Logs borrados / anti-forense", "A", 3, ["Forense"],
     "El atacante vació auth.log. Reconstruye la intrusión con la evidencia que queda.",
     ["wtmp", "journalctl", "/proc", "forense"]),
    ("10", "Binario SUID backdoor", "A", 2, ["DevSecOps"],
     "Una copia SUID de bash con nombre de sistema da root sin contraseña. Encuéntrala.",
     ["find -perm", "suid", "privesc"]),
    ("11", "Malware con chattr +i", "A", 2, ["DevSecOps", "SysAdmin"],
     "rm no puede borrar el payload aunque seas root. Quita el atributo inmutable.",
     ["lsattr", "chattr", "inmutable"]),
    ("12", "Exfiltración por DNS", "A", 3, ["Forense", "Redes"],
     "Los datos salen dentro de subdominios. Detecta el patrón en el log y bloquéalo.",
     ["log dns", "base32", "blocklist"]),
    ("13", "Webshell en el web root", "A", 3, ["DevSecOps"],
     "Entre decenas de archivos del sitio hay una webshell. Encuéntrala sin romper la web.",
     ["grep", "timestamps", "web root"]),
    ("14", "Triage: fuerza bruta SSH", "A", 2, ["DevSecOps", "SysAdmin"],
     "Cientos de fallos SSH y un login exitoso. Identifica la IP que entró y bloquéala.",
     ["auth.log", "awk/sort/uniq", "bloqueo"]),
    ("15", "Integridad de binarios en PATH", "A", 2, ["DevSecOps"],
     "Un ls impostor se ejecuta antes del real. Detecta el secuestro de PATH.",
     ["which", "hash", "PATH"]),
    ("16", "Servicializar una app con systemd", "B", 2, ["DevOps", "SysAdmin"],
     "Convierte una app que se lanza a mano en un servicio que arranca al boot.",
     ["unit file", "systemctl enable", "boot"]),
    ("17", "Endurecer sshd_config", "B", 2, ["SysAdmin", "DevSecOps"],
     "Desactiva login root, contraseñas y X11 sin romper la configuración de sshd.",
     ["sshd_config", "sshd -t", "AllowUsers"]),
    ("18", "Firewall base (iptables)", "B", 2, ["Redes", "SysAdmin"],
     "La política INPUT es ACCEPT. Aplica default-deny y abre sólo lo necesario.",
     ["iptables", "default DROP", "22/80/443"]),
    ("19", "Conectar 2 servidores por VPN (WireGuard)", "B", 3, ["Redes", "DevOps"],
     "Levanta un túnel WireGuard cifrado entre dos servidores por IP privada.",
     ["wg", "llaves", "túnel", "ping privado"]),
    ("20", "fail2ban para sshd", "B", 3, ["SysAdmin", "DevSecOps"],
     "Configura fail2ban para banear la fuerza bruta SSH y bloquea la IP atacante.",
     ["jail.local", "fail2ban-client", "ban"]),
    ("21", "TLS + HTTPS", "B", 2, ["DevOps"],
     "Genera un certificado y sirve la app por HTTPS en el puerto 8443.",
     ["openssl", "cert self-signed", "https"]),
    ("22", "Auditoría con auditd", "B", 2, ["DevSecOps", "SysAdmin"],
     "Crea una regla auditd que registre quién y cuándo modifica /etc/passwd.",
     ["auditctl", "ausearch", "/etc/passwd"]),
    ("23", "Usuarios y sudo mínimos", "B", 2, ["SysAdmin", "DevSecOps"],
     "Quita un sudo NOPASSWD:ALL y crea una cuenta con sólo los permisos necesarios.",
     ["useradd", "sudoers", "least privilege"]),
    # Pista C: "30 días de DevSecOps" (inspirada en el curso de LabEx).
    ("24", "Día 01 · Auditar servicios en escucha", "C", 1, ["DevSecOps", "Redes"],
     "Inventaria qué escucha en el servidor y documenta cada puerto en un informe.",
     ["ss -tulpn", "inventario", "superficie"]),
    ("25", "Día 02 · Quitar un puerto público sobrante", "C", 1, ["Redes", "SysAdmin"],
     "Tras una prueba antigua, nginx sigue escuchando también en el 8080. Ciérralo.",
     ["ss", "systemctl", "bind"]),
    ("26", "Día 03 · Admin sólo en localhost", "C", 1, ["Redes", "DevSecOps"],
     "La interfaz de administración escucha en 0.0.0.0. Limítala a 127.0.0.1.",
     ["bind address", "127.0.0.1", "ss"]),
    ("27", "Día 04 · Desactivar listado de directorios", "C", 1, ["DevSecOps"],
     "nginx enseña el contenido de las carpetas, incluida una interna. Apágalo sin romper descargas.",
     ["autoindex", "nginx", "curl"]),
    ("28", "Día 05 · Retirar un backup expuesto", "C", 1, ["DevSecOps"],
     "Un backup con volcado de la BD quedó dentro del web root. Retíralo y guárdalo bien.",
     ["web root", "backups", "curl"]),
    ("29", "Día 06 · Permisos de un secreto", "C", 1, ["SysAdmin", "DevSecOps"],
     "La clave de firma de facturas es legible y escribible por todos. Ciérrala sin tumbar el servicio.",
     ["chmod", "chown", "0640"]),
    ("30", "Día 07 · Uploads escribibles por todos", "C", 1, ["SysAdmin", "DevSecOps"],
     "El directorio de subidas es 0777. Dale dueño y permisos correctos.",
     ["chmod", "find -perm", "www-data"]),
    ("31", "Día 08 · Usuario dedicado para un servicio", "C", 2, ["SysAdmin", "DevSecOps"],
     "Un demonio corre como root. Pásalo a un usuario de sistema propio.",
     ["useradd -r", "drop-in", "User="]),
    ("32", "Día 09 · Proteger el env file", "C", 1, ["SysAdmin", "DevSecOps"],
     "El EnvironmentFile con secretos (y su .bak) es legible por todos.",
     ["EnvironmentFile", "0600", "backups"]),
    ("33", "Día 10 · Frontera de escritura de logs", "C", 2, ["SysAdmin"],
     "Los logs son 0666 y logrotate los recrea igual. Corrige ambos.",
     ["logrotate", "create", "chmod"]),
    ("34", "Día 11 · Credenciales hardcodeadas", "C", 2, ["DevSecOps"],
     "Un script de mantenimiento lleva la contraseña de la BD dentro. Sácala a un fichero.",
     ["grep", "source", "0600"]),
    ("35", "Día 12 · Secreto en el entorno del proceso", "C", 2, ["DevSecOps", "SysAdmin"],
     "Un token en Environment= se ve en systemctl show y /proc. Entrégalo como fichero.",
     ["/proc/environ", "systemd", "*_FILE"]),
    ("36", "Día 13 · Sudo demasiado amplio", "C", 2, ["SysAdmin", "DevSecOps"],
     "deploy tiene NOPASSWD: ALL. Déjale sólo el comando que necesita.",
     ["visudo", "sudoers", "least privilege"]),
    ("37", "Día 14 · PATH seguro en scripts", "C", 2, ["SysAdmin", "DevSecOps"],
     "Un script de root confía en un PATH con un directorio escribible por todos.",
     ["PATH", "cron", "secuestro"]),
    ("38", "Día 15 · Endurecer un cron de root", "C", 2, ["SysAdmin", "DevSecOps"],
     "root ejecuta cada minuto un script que cualquiera puede modificar.",
     ["cron.d", "install -m", "permisos"]),
    ("39", "Día 16 · Auditoría de un stack Compose", "C", 1, ["Docker", "DevSecOps"],
     "Lo que hay en disco ya no describe lo que corre. Saca la línea base real del runtime.",
     ["docker compose config", "inspect", "informe"]),
    ("40", "Día 17 · Auditar el portal de soporte", "C", 1, ["Docker", "DevSecOps"],
     "Un contenedor lanzado a mano: audita imagen, puertos, montajes y secretos.",
     ["docker inspect", "env", "mounts"]),
    ("41", "Día 18 · Endpoint de métricas publicado", "C", 1, ["Docker", "Redes"],
     "Las métricas internas se publican al exterior. Déjalas sólo en la red interna.",
     ["ports", "compose", "exposición"]),
    ("42", "Día 19 · Consola de depuración sólo local", "C", 1, ["Docker", "Redes"],
     "Una consola eval escucha en todas las interfaces. Publícala sólo en 127.0.0.1.",
     ["127.0.0.1:port", "compose", "debug"]),
    ("43", "Día 20 · Base de datos interna", "C", 1, ["Docker", "Redes"],
     "La BD publica 5432 en el host. Que sólo la alcance la app.",
     ["ports", "red interna", "compose"]),
    ("44", "Día 21 · Configuración en sólo lectura", "C", 2, ["Docker", "DevSecOps"],
     "El gateway puede reescribir su config. Móntala :ro y dale un caché aparte.",
     [":ro", "tmpfs", "volúmenes"]),
    ("45", "Día 22 · Worker sin root", "C", 2, ["Docker", "DevSecOps"],
     "Un worker procesa ficheros como root. Hazlo correr con un UID sin privilegios.",
     ["USER", "UID", "chown"]),
    ("46", "Día 23 · Quitar privileged a un colector", "C", 2, ["Docker", "DevSecOps"],
     "Un colector de logs corre con privileged: true. Quítalo sin romperlo.",
     ["privileged", "capabilities", "sysctl"]),
    ("47", "Día 24 · Webhook sin socket de Docker", "C", 2, ["Docker", "DevSecOps"],
     "Un webhook monta /var/run/docker.sock: equivale a root en el host.",
     ["docker.sock", "escape", "compose"]),
    ("48", "Día 25 · Acotar un secreto de Compose", "C", 2, ["Docker", "DevSecOps"],
     "Un ancla YAML reparte un secreto a todos los servicios. Dáselo sólo a quien lo usa.",
     ["secrets", "anclas YAML", "/run/secrets"]),
    ("49", "Día 26 · Redes de frontend y backend", "C", 2, ["Docker", "Redes"],
     "web llega directo a la BD. Segmenta en dos redes con la api como único puente.",
     ["networks", "internal", "segmentación"]),
    ("50", "Día 27 · Token del entorno a un fichero", "C", 2, ["Docker", "DevSecOps"],
     "El token está en compose.yaml y en docker inspect. Pásalo a un secreto montado.",
     ["*_FILE", "secrets", "inspect"]),
    ("51", "Día 28 · Token fuera del build", "C", 3, ["Docker", "DevSecOps"],
     "ARG, ENV y RUN dejaron el token en la imagen. Límpiala y borra las capas viejas.",
     ["docker history", "docker save", "prune"]),
    ("52", "Día 29 · Endurecer la imagen de un worker", "C", 2, ["Docker", "DevSecOps"],
     "Base sin fijar, DEBUG=1 y ficheros de depuración dentro. Deja una imagen de producción.",
     [".dockerignore", "FROM fijado", "EXPOSE"]),
    ("53", "Día 30 · Limpiar la depuración de un incidente", "C", 2, ["Docker", "DevSecOps"],
     "Quedó un override con AUTH_BYPASS y una shell remota. Cierra el incidente de verdad.",
     ["compose.override", "--remove-orphans", "huérfanos"]),
    # --- Pista D · Operaciones / SRE (producción) -------------------------
    ("54", "Servicio caído: arranque y reinicio", "D", 1, ["SRE", "SysAdmin"],
     "Una API no levanta tras el reinicio. Diagnostícala con systemd y déjala estable.",
     ["systemctl", "journalctl", "Restart="]),
    ("55", "Disco lleno al 100%", "D", 1, ["SRE", "SysAdmin"],
     "El servidor no escribe: no queda espacio. Encuentra qué lo llena y recupéralo sin perder datos.",
     ["df", "du", "lsof +L1"]),
    ("56", "La app no llega a la base de datos", "D", 2, ["SRE", "Redes"],
     "La web da error 500: no conecta con la BD de otra máquina. Sigue la conexión salto a salto.",
     ["ss", "nc", "firewall"]),
    ("57", "SSH a través de un bastión", "D", 2, ["SRE", "Redes"],
     "Hay que llegar a un host interno sólo accesible por el bastión. Monta el salto con llaves.",
     ["ProxyJump", "ssh-keygen", "~/.ssh/config"]),
    ("58", "Backup a Blob storage por cron (3 AM)", "D", 2, ["SRE", "DevSecOps"],
     "Deja un backup diario a las 3:00 a un almacén tipo Blob, con rotación y candado anti-solape.",
     ["cron.d", "rclone", "flock"]),
    ("59", "Restaurar un backup de la BD", "D", 2, ["SRE", "SysAdmin"],
     "La tabla de pedidos se corrompió. Restaura desde el último dump y verifica la integridad.",
     ["pg_restore", "verificación", "RPO"]),
    ("60", "El OOM killer mata el proceso", "D", 2, ["SRE", "SysAdmin"],
     "Un servicio muere solo cada rato. El kernel lo está matando por memoria. Acótalo.",
     ["dmesg", "MemoryMax", "cgroups"]),
    ("61", "DNS interno roto", "D", 2, ["SRE", "Redes"],
     "La app no resuelve nombres internos. Arregla resolv.conf, el search y el servidor DNS.",
     ["resolv.conf", "getent", "dnsmasq"]),
    ("62", "502 Bad Gateway en nginx", "D", 2, ["SRE", "Redes"],
     "El proxy devuelve 502 y luego 504. Alinea el upstream, los permisos y los timeouts.",
     ["upstream", "proxy_read_timeout", "nginx"]),
    ("63", "Bucle de reinicios", "D", 3, ["SRE", "SysAdmin"],
     "Un worker reinicia sin parar hasta el start-limit. EnvironmentFile mal y un puerto ocupado.",
     ["NRestarts", "EnvironmentFile", "reset-failed"]),
    ("64", "Healthcheck y autorrecuperación", "D", 3, ["SRE", "SysAdmin"],
     "Un servicio se cuelga sin morir. Escribe un watchdog que lo detecte, lo reinicie y alerte.",
     ["timer", "watchdog", "RuntimeDirectory"]),
    ("65", "Deploy fallido: rollback", "D", 3, ["SRE", "DevSecOps"],
     "El último release no arranca y el rollback elige mal. Vuelve a la versión buena con symlinks.",
     ["releases", "symlink atómico", "rollback"]),
    ("66", "Too many open files", "D", 2, ["SRE", "SysAdmin"],
     "Un servicio agota los descriptores. Sube el límite en el sitio correcto (no en limits.conf).",
     ["LimitNOFILE", "/proc/PID/limits", "ulimit"]),
    ("67", "PostgreSQL: conexiones remotas", "D", 2, ["SRE", "Redes"],
     "La app remota no entra en Postgres. Ajusta listen_addresses y pg_hba sin abrirlo a todos.",
     ["listen_addresses", "pg_hba.conf", "scram"]),
    ("68", "Migración de datos con rsync", "D", 3, ["SRE", "SysAdmin"],
     "Mueve un árbol de ficheros a otra máquina conservando permisos, enlaces y fechas. Idempotente.",
     ["rsync -aH", "--delete", "hardlinks"]),
    ("69", "Balanceador con un backend caído", "D", 3, ["SRE", "Redes"],
     "Un backend cae y nginx sigue mandándole tráfico. Configura reintentos y health pasivo.",
     ["upstream", "max_fails", "proxy_next_upstream"]),
    ("70", "El cron no se ejecuta", "D", 2, ["SRE", "SysAdmin"],
     "Cinco cronjobs, cinco motivos para no correr: campo de usuario, nombre, PATH, % y newline.",
     ["cron.d", "journalctl", "%F"]),
    ("71", "Logs de Docker llenan el disco", "D", 2, ["SRE", "Docker"],
     "Un worker en DEBUG llena el disco con json.log. Rota los logs y déjalo en el compose.",
     ["json-file", "max-size", "max-file"]),
    ("72", "Certificado TLS caducado", "D", 2, ["SRE", "DevSecOps"],
     "El certificado de la tienda caducó. Reemítelo con la CA interna (con SAN) y recarga en caliente.",
     ["openssl ca", "subjectAltName", "nginx reload"]),
    ("73", "Game day: varias averías a la vez", "D", 3, ["SRE", "SysAdmin"],
     "Tres fallos simultáneos y 503. Triaje por capas, arregla sin perder datos y escribe el postmortem.",
     ["triage", "journalctl", "postmortem"]),
    ("74", "Escaneo de imágenes: a 0 CRITICAL", "D", 2, ["SRE", "DevSecOps", "Docker"],
     "El gate bloquea la imagen por CVE CRITICAL. Escanéala con grype y arregla la base.",
     ["grype", "CVE", "imagen base"]),
    ("75", "Logs centralizados con rsyslog", "D", 3, ["SRE", "Redes"],
     "Faltan logs de un host y se pierden en cada caída. Centraliza por TCP con cola en disco.",
     ["rsyslog", "imtcp", "cola en disco"]),
    ("76", "Sinkhole DNS (estilo Pi-hole)", "D", 3, ["SRE", "Redes", "DevSecOps"],
     "Un puesto habla con un C2. Monta un sinkhole desde un feed y localiza al infectado por los logs.",
     ["dnsmasq", "threat intel", "log-queries"]),
    ("77", "Verificar paquetes antes de instalar", "D", 3, ["SRE", "DevSecOps"],
     "El mirror está comprometido. Instala sólo lo que firme el fabricante: firma GPG y SHA-256.",
     ["gpg --verify", "VALIDSIG", "SHA256SUMS"]),
    ("78", "De iptables a nftables", "D", 2, ["SRE", "Redes", "DevSecOps"],
     "Migra un cortafuegos iptables de 2015 a nftables: deny por defecto, SSH acotado, sin reglas muertas.",
     ["nftables", "set", "limit rate"]),
    # --- Pista E · Defensa anti-DDoS/DoS (lado azul) ----------------------
    ("79", "Triage anti-DDoS: ¿ataque o tráfico legítimo?", "E", 2, ["DevSecOps", "Redes", "Forense"],
     "Un pico enorme de peticiones. Separa el flood distribuido del health check y los crawlers antes de bloquear.",
     ["access.log", "awk/uniq", "/24", "falsos positivos"]),
    ("80", "Endurecer Apache contra un flood HTTP", "E", 2, ["DevSecOps", "SysAdmin"],
     "Apache con la config aflojada cae ante un flood. Ponle reqtimeout, Timeout bajos y mod_evasive.",
     ["mod_reqtimeout", "mod_evasive", "KeepAlive", "ab"]),
    ("81", "Mitigar Slowloris (slow-DoS)", "E", 3, ["DevSecOps", "Redes"],
     "Pocas conexiones lentas agotan los workers de Apache. Córtalas con mod_reqtimeout.",
     ["slowloris", "RequestReadTimeout", "MinRate"]),
    ("82", "WAF: ModSecurity + OWASP CRS", "E", 3, ["DevSecOps"],
     "ModSecurity está en sólo-detectar y sin reglas. Ponlo en bloqueo y carga el Core Rule Set.",
     ["SecRuleEngine", "OWASP CRS", "WAF", "capa 7"]),
    ("83", "Reverse proxy con rate limiting (nginx)", "E", 2, ["Redes", "DevSecOps"],
     "nginx hace de proxy sin límite de tasa. Pon un limit_req por IP (el equivalente local a una CDN).",
     ["limit_req_zone", "burst", "proxy_pass", "token bucket"]),
    ("84", "Respuesta a incidentes tras un DDoS", "E", 2, ["DevSecOps", "SysAdmin", "Forense"],
     "El flood amainó. Cierra el incidente: mitigación duradera en el firewall y postmortem.",
     ["iptables hashlimit", "blocklist", "postmortem"]),
    # --- Pista F · Pipeline CI y runtime Docker -----------------------------
    ("85", "Parche rolling sin downtime", "F", 3, ["DevSecOps", "SRE"],
     "Hay que subir shop 1.0.0 → 1.2.0 detrás del balanceador sin cortar HTTP ni reiniciar nginx.",
     ["rolling", "reload", "health", "dos backends"]),
    ("86", "Cutover blue-green", "F", 3, ["DevSecOps", "SRE"],
     "Green sigue en 1.0.0 vulnerable. Blue ya está parcheado: cambia el upstream y recarga en caliente.",
     ["blue-green", "upstream", "nginx reload", "rollback"]),
    ("87", "Pipeline CI que filtra secretos", "F", 3, ["DevSecOps", "Docker"],
     "El runner imprime el token, monta docker.sock y corre en pull_request. Endurécelo sin romper el build.",
     ["CI", "secretos", "docker.sock", "pull_request"]),
    ("88", "Gate de seguridad saltado", "F", 3, ["DevSecOps"],
     "El job de scan está en continue-on-error y el deploy no lo espera. El gate tiene que ser obligatorio y verde.",
     ["pipeline", "needs", "continue-on-error", "scan"]),
    ("89", "Capabilities y no-new-privileges", "F", 2, ["Docker", "DevSecOps"],
     "La API arranca con CAP_ALL y SYS_ADMIN. Déjala en cap_drop ALL y no-new-privileges, sirviendo igual.",
     ["cap_drop", "no-new-privileges", "least privilege"]),
    ("90", "Cerrar vías de escape al host", "F", 3, ["Docker", "DevSecOps"],
     "privileged, pid/net host, docker.sock y / del host. Quita las vías de escape y deja la API con su volumen de datos.",
     ["privileged", "docker.sock", "pid: host", "bind /"]),
    ("91", "Admission: política de Compose", "F", 3, ["DevSecOps", "Docker"],
     "El admitidor es un grep y red team tiene 12 bypasses. Evalúa el compose renderizado, fail-closed, y engánchalo al deploy.",
     ["admission", "policy as code", "compose config", "fail-closed"]),
    ("92", "SBOM firmado y verificado", "F", 3, ["DevSecOps", "Docker"],
     "El gate de release está en verde con una clave que trajo el atacante. Ancla de confianza, SBOM real y atado a la imagen.",
     ["SBOM", "firma", "ancla de confianza", "supply chain"]),
    ("93", "Scan IaC del Compose", "F", 3, ["DevSecOps", "Docker"],
     "Un PR puso el scan en verde esquivando el grep. Arregla el escáner contra un corpus de casos y luego el compose.",
     ["IaC", "scanner", "falsos negativos", "tests"]),
    ("94", "xtrace que filtra el secreto", "F", 3, ["DevSecOps"],
     "El token sale por xtrace escondido, base64 y artefactos. Ciérralas y enmascara secretos en el runner.",
     ["set -x", "masking", "artefactos", "CI"]),
    ("95", "seccomp: perfil propio", "F", 3, ["Docker", "DevSecOps"],
     "La api corre unconfined. Deriva del perfil de Docker uno que niegue ptrace y process_vm_* y pruébalo en runtime.",
     ["seccomp", "ptrace", "lista blanca", "runtime"]),
    ("96", "Actions sin pin de SHA", "F", 3, ["DevSecOps"],
     "Tags mutables, un tag secuestrado y un escáner ciego. Fija cada uses al commit correcto del mirror.",
     ["GitHub Actions", "pin", "tag hijack", "supply chain"]),

    # --- Pista G · AppSec web (vulnerable a propósito; red o blue) ----------
    ("97", "Portal con SQLi en el login", "G", 2, ["AppSec", "Web"],
     "El login concatena la SQL. Captura la flag por inyeccion (red) o pasa a consultas parametrizadas (blue).",
     ["SQLi", "OWASP A03", "login bypass", "red/blue"]),
    ("98", "Command injection en herramienta de red", "G", 2, ["AppSec", "Web"],
     "Un parametro acaba en una shell. Ejecuta un comando (red) o quita shell=True y valida la entrada (blue).",
     ["command injection", "OWASP A03", "shell", "red/blue"]),
    ("99", "Gateway con SSRF", "G", 3, ["AppSec", "Web"],
     "El fetcher pide cualquier URL y presta su cabecera de confianza. Alcanza el metadata interno (red) o pon allowlist host+puerto (blue).",
     ["SSRF", "OWASP A10", "confused deputy", "red/blue"]),
    ("100", "API con JWT alg:none", "G", 3, ["AppSec", "Auth"],
     "El verificador obedece el 'alg' del token. Forja un admin (red) o fija HS256 y valida la firma (blue).",
     ["JWT", "alg confusion", "OWASP A07", "red/blue"]),
    ("101", "Importador XML con XXE", "G", 3, ["AppSec", "Web"],
     "El parser resuelve entidades externas. Lee un fichero del servidor (red) o desactiva DTD/entidades (blue).",
     ["XXE", "OWASP A05", "lxml", "red/blue"]),

    # --- Pista H · Máquinas HTB (contenedor atacante; red o blue) -----------
    ("102", "Saltar (o blindar) un firewall", "H", 3, ["Red", "Firewall"],
     "Firewall mal configurado con dos servicios internos. Sáltalo y captura user+root (red) o cierra las vías de bypass (blue).",
     ["iptables", "firewall bypass", "source port", "red/blue"]),
    ("103", "Panel con fuga de artefacto de build", "H", 2, ["Red", "Web"],
     "Backup del código en el webroot y modo debug activo: captura user+root (red) o cierra las dos fugas sin romper el panel (blue).",
     ["info disclosure", "debug mode", "OWASP A05", "red/blue"]),
    ("104", "Panel con credenciales por defecto y errores verbosos", "H", 2, ["Red", "Web"],
     "Contraseña por defecto en el panel y trazas de error que filtran: captura user+root (red) o endurece credencial y calla los errores sin romper el panel (blue).",
     ["default creds", "verbose errors", "OWASP A05", "OWASP A07", "red/blue"]),

    # --- Pista D (ampliación) · Operaciones de datos en producción ----------
    ("107", "Migración de datos en producción", "D", 3, ["Datos", "SRE"],
     "Migra una columna de una tabla grande con usuarios comprando (tráfico k6). Hazlo online (expand/contract) sin tumbar la tienda con un lock.",
     ["postgres", "zero-downtime", "locks", "expand/contract", "k6"]),
    ("108", "Restaurar un backup y reconectar la app", "D", 2, ["Datos", "SRE"],
     "Se perdió la base de producción. Elige el backup bueno, restáuralo y reconecta la app (DSN + reinicio) hasta que /health vuelva a 200.",
     ["postgres", "backup", "pg_restore", "DSN", "incidente"]),
]
LAB_BY_ID = {lab[0]: lab for lab in LABS}

# Módulos de cursos/ recomendados para cada lab (aviso "¿Dificultad?" en la web).
LAB_CURSOS = {
    "01": ["02", "09", "11", "12"], "02": ["06", "07", "10"], "03": ["10"],
    "04": ["06"], "05": ["03", "04", "05"], "06": ["07", "08"], "07": ["13"],
    "08": ["10", "11"], "09": ["06", "09"], "10": ["04"], "11": ["04"],
    "12": ["03", "09", "10"], "13": ["03", "09"], "14": ["03", "09", "11"],
    "15": ["02"], "16": ["08"], "17": ["12"], "18": ["11"], "19": ["10", "12"],
    "20": ["09", "11"], "21": ["12", "13"], "22": ["09"], "23": ["04", "05"],
    # Pista D
    "56": ["11"], "57": ["12"], "58": ["10", "12"], "61": ["11"], "62": ["11"],
    "67": ["11"], "72": ["12", "13"], "74": ["10"], "75": ["09"], "76": ["10", "11"],
    "77": ["13"], "78": ["11"],
    # Pista E · anti-DDoS (curso 14)
    "79": ["14", "09"], "80": ["14"], "81": ["14"], "82": ["14", "13"],
    "83": ["14", "11"], "84": ["14", "11", "09"],
    # Pista F · pipeline / runtime
    "85": ["08"], "86": ["08"], "87": ["13"], "88": ["13"],
    "91": ["13"], "92": ["13"], "93": ["13"], "94": ["13"], "96": ["13"],
}
ID_RE = re.compile(r"^\d{2,3}$")


def lab_dir(lab_id):
    """Carpeta del lab NN (p.ej. labs/04-proceso-fantasma). None si no existe."""
    if not ID_RE.match(lab_id) or lab_id not in LAB_BY_ID:
        return None
    for name in os.listdir(LABS_DIR):
        if name.startswith(lab_id + "-") and os.path.isdir(os.path.join(LABS_DIR, name)):
            return os.path.join(LABS_DIR, name)
    return None


def compose_file(lab_id):
    d = lab_dir(lab_id)
    if not d:
        return None
    f = os.path.join(d, "docker-compose.yml")
    return f if os.path.isfile(f) else None


def run(args, timeout=600, env=None):
    """Ejecuta un comando (lista de args, sin shell) y devuelve (code, salida)."""
    try:
        # UTF-8 explícito: en Windows el locale por defecto (cp1252) no decodifica
        # la salida de check.sh (✓, emojis) ni el progreso de docker build.
        p = subprocess.run(args, cwd=ROOT, capture_output=True, text=True,
                           encoding="utf-8", errors="replace", timeout=timeout,
                           env=({**os.environ, **env} if env else None))
        return p.returncode, (p.stdout + p.stderr)
    except subprocess.TimeoutExpired:
        return 124, "Tiempo agotado ejecutando el comando."
    except FileNotFoundError:
        return 127, "No se encontró 'docker'. ¿Está instalado y en el PATH?"
    except Exception as e:  # noqa: BLE001
        return 1, f"Error: {e}"


def dc(lab_id, *cmd, timeout=600, env=None):
    """docker compose -f <lab>/docker-compose.yml <cmd...>"""
    cf = compose_file(lab_id)
    if not cf:
        return 1, "Lab inexistente."
    return run(["docker", "compose", "-f", cf, *cmd], timeout=timeout, env=env)


# ---------------------------------------------------------------------------
# Modo red / blue (labs estilo HTB con contenedor atacante)
# ---------------------------------------------------------------------------
# Un lab es "red-capaz" si su compose define el servicio 'attacker' tras el
# profile 'red'. En blue se publica la terminal del target (ttyd) en el puerto
# host; en red se publica la del contenedor atacante y el target queda sin
# shell, solo accesible por la red Docker. Las banderas (user/root) las lee el
# servidor del target con `docker exec -u 0` y las valida contra lo que envía
# el alumno desde la web.
_RED_CACHE = {}


def red_capable(lab_id):
    if lab_id in _RED_CACHE:
        return _RED_CACHE[lab_id]
    cf = compose_file(lab_id)
    ok = False
    if cf:
        try:
            with open(cf, encoding="utf-8") as f:
                txt = f.read()
            ok = "attacker:" in txt and "profiles:" in txt
        except OSError:
            ok = False
    _RED_CACHE[lab_id] = ok
    return ok


def read_flags(lab_id):
    """{'user': 'TCLAB{..}', 'root': 'TCLAB{..}'} leído del target (como root)."""
    code, out = run(["docker", "exec", "-u", "0", f"tc-lab-{lab_id}",
                     "cat", "/opt/lab/.flags"], timeout=20)
    if code != 0:
        return {}
    flags = {}
    for line in out.splitlines():
        k, _, v = line.strip().partition("=")
        if k and v:
            flags[k.strip().lower()] = v.strip()
    return flags


def container_running(lab_id):
    code, out = run(["docker", "inspect", "-f", "{{.State.Running}}",
                     f"tc-lab-{lab_id}"], timeout=20)
    return code == 0 and "true" in out.lower()


RUNNING_RE = re.compile(r"^tc-lab-(\d{2,3})$")


def lab_states():
    """{id: estado} del contenedor principal tc-lab-NN de cada lab del registro
    (running, exited, created...). Una sola llamada a `docker ps -a`; ignora
    contenedores ajenos y auxiliares como -peer."""
    code, out = run(["docker", "ps", "-a", "--filter", "name=tc-lab-",
                     "--format", "{{.Names}}\t{{.State}}"], timeout=20)
    if code != 0:
        return {}
    states = {}
    for line in out.splitlines():
        name, _, state = line.strip().partition("\t")
        m = RUNNING_RE.match(name)
        if m and m.group(1) in LAB_BY_ID:
            states[m.group(1)] = state.strip().lower()
    return states


def running_labs():
    """IDs de los labs de esta página con su contenedor principal corriendo."""
    return sorted(i for i, st in lab_states().items() if st == "running")


# ---------------------------------------------------------------------------
# Auto-destrucción
# ---------------------------------------------------------------------------
LOCK = threading.Lock()
PENDING = {}   # id -> epoch en que se destruye (lab resuelto, en cuenta atrás)
KEPT = set()   # ids que el usuario pidió mantener tras resolver
BUSY = set()   # ids con start/reset/stop en curso: el reaper no los toca
STARTED = {}   # id -> epoch de arranque del contenedor (para el TTL)
MODE = {}      # id -> "red" | "blue" con el que se arrancó
CAPTURED = {}  # id -> set() de banderas ya capturadas en red ("user"/"root")


def log(msg):
    sys.stderr.write(f"  [autodestrucción] {msg}\n")


def started_at(lab_id):
    code, out = run(["docker", "inspect", "-f", "{{.State.StartedAt}}",
                     f"tc-lab-{lab_id}"], timeout=20)
    if code != 0:
        return None
    try:  # 2026-10-19T12:34:56.123456789Z -> basta hasta los segundos
        dt = datetime.strptime(out.strip()[:19], "%Y-%m-%dT%H:%M:%S")
        return dt.replace(tzinfo=timezone.utc).timestamp()
    except ValueError:
        return None


def is_solved(lab_id):
    code, _ = run(["docker", "exec", f"tc-lab-{lab_id}", "test", "-e",
                   SOLVED_MARKER], timeout=20)
    return code == 0


def destroy(lab_id, reason):
    """docker compose down -v: borra contenedores, red y volúmenes del lab."""
    with LOCK:
        if lab_id in BUSY:
            return
        BUSY.add(lab_id)
    try:
        log(f"lab {lab_id}: {reason} -> destruyendo")
        dc(lab_id, "down", "-v", "--remove-orphans", "-t", "5", timeout=300)
    finally:
        with LOCK:
            BUSY.discard(lab_id)
            PENDING.pop(lab_id, None)
            KEPT.discard(lab_id)
            STARTED.pop(lab_id, None)


def schedule_destroy(lab_id):
    with LOCK:
        KEPT.discard(lab_id)
        PENDING[lab_id] = time.time() + GRACE_S


def reap_once():
    now = time.time()
    for lab_id, state in lab_states().items():
        with LOCK:
            if lab_id in BUSY:
                continue
        # 'created'/'restarting' pueden ser un arranque en curso: no se tocan.
        if state in ("exited", "dead"):
            destroy(lab_id, "contenedor parado/huérfano")
            continue
        if state != "running":
            continue
        with LOCK:
            deadline = PENDING.get(lab_id)
            kept = lab_id in KEPT
            t0 = STARTED.get(lab_id)
        if deadline is not None and now >= deadline:
            destroy(lab_id, "lab resuelto")
            continue
        if deadline is None and not kept and is_solved(lab_id):
            log(f"lab {lab_id}: resuelto desde la terminal, destrucción en {GRACE_S}s")
            schedule_destroy(lab_id)
        if t0 is None:
            t0 = started_at(lab_id)
            if t0 is not None:
                with LOCK:
                    STARTED[lab_id] = t0
        if TTL_MIN > 0 and t0 is not None and now - t0 > TTL_MIN * 60:
            destroy(lab_id, f"superó el tiempo máximo de {TTL_MIN} min")


def reaper_loop():
    while True:
        try:
            reap_once()
        except Exception as e:  # noqa: BLE001 — el reaper no debe morir nunca
            log(f"error: {e}")
        time.sleep(REAP_EVERY_S)


def destroy_all(reason):
    threads = [threading.Thread(target=destroy, args=(i, reason))
               for i in lab_states()]
    for t in threads:
        t.start()
    for t in threads:
        t.join()


def lifecycle(lab_id):
    """Segundos hasta la autodestrucción por resuelto y por TTL (o None)."""
    now = time.time()
    with LOCK:
        deadline = PENDING.get(lab_id)
        t0 = STARTED.get(lab_id)
    return {
        "destroyIn": max(0, int(deadline - now)) if deadline else None,
        "expiresIn": max(0, int(t0 + TTL_MIN * 60 - now))
        if (t0 and TTL_MIN > 0) else None,
    }


def read_md(lab_id, kind):
    d = lab_dir(lab_id)
    if not d:
        return None
    # RETO.md va dentro del contenedor; solución y guía viven en solucion/,
    # que nunca se copia a la imagen.
    path = os.path.join(d, "RETO.md") if kind == "reto" \
        else os.path.join(d, "solucion",
                          "GUIA.md" if kind == "guia" else "SOLUCION.md")
    try:
        with open(path, encoding="utf-8") as f:
            return f.read()
    except OSError:
        return None


def curso_path(curso_id):
    """cursos/NN-nombre.md del módulo NN. None si no existe."""
    if not ID_RE.match(curso_id) or not os.path.isdir(CURSOS_DIR):
        return None
    for name in sorted(os.listdir(CURSOS_DIR)):
        if name.startswith(curso_id + "-") and name.endswith(".md"):
            return os.path.join(CURSOS_DIR, name)
    return None


def cursos_payload():
    """Índice de módulos: id, título (primer '# ') y resumen (primera línea '> ')."""
    out = []
    if not os.path.isdir(CURSOS_DIR):
        return out
    for name in sorted(os.listdir(CURSOS_DIR)):
        m = re.match(r"^(\d{2})-.+\.md$", name)
        if not m:
            continue
        title, summary = name, ""
        with open(os.path.join(CURSOS_DIR, name), encoding="utf-8") as f:
            for line in f:
                if line.startswith("# ") and title == name:
                    title = line[2:].strip()
                elif line.startswith("> ") and not summary:
                    summary = line[2:].strip()
                if title != name and summary:
                    break
        title = re.sub(r"^\d{2}\s*·\s*", "", title)
        out.append({"id": m.group(1), "title": title, "summary": summary})
    return out


def labs_payload():
    out = []
    running = set(running_labs())
    for lab_id, name, track, diff, cats, desc, skills in LABS:
        out.append({
            "id": lab_id,
            "name": name,
            "track": track,
            "difficulty": diff,
            "categories": cats,
            "description": desc,
            "skills": skills,
            "cursos": LAB_CURSOS.get(lab_id, []),
            "exists": lab_dir(lab_id) is not None,
            "running": lab_id in running,
            "ttydPort": TTYD_BASE + int(lab_id),
            "redCapable": red_capable(lab_id),
            "mode": MODE.get(lab_id),
        })
    return out


class Handler(BaseHTTPRequestHandler):
    server_version = "TerminalCeroLab/1.0"

    def log_message(self, fmt, *args):  # salida compacta
        sys.stderr.write("  %s\n" % (fmt % args))

    # ---- helpers ----
    def _json(self, obj, code=200):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _file(self, relpath):
        # Sirve estáticos de ./web, sin salir de esa carpeta.
        safe = os.path.normpath(relpath).lstrip("\\/")
        full = os.path.join(WEB_DIR, safe)
        if not os.path.abspath(full).startswith(os.path.abspath(WEB_DIR)) \
                or not os.path.isfile(full):
            self.send_error(404, "No encontrado")
            return
        ctype = {
            ".html": "text/html; charset=utf-8",
            ".css": "text/css; charset=utf-8",
            ".js": "application/javascript; charset=utf-8",
            ".svg": "image/svg+xml",
            ".ico": "image/x-icon",
        }.get(os.path.splitext(full)[1], "application/octet-stream")
        with open(full, "rb") as f:
            data = f.read()
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        # no-cache: el navegador revalida y nunca usa un app.js viejo tras actualizar
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(data)

    # ---- routing ----
    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/" or path == "":
            return self._file("index.html")
        if path == "/api/labs":
            return self._json({"labs": labs_payload()})
        if path == "/api/running":
            ids = running_labs()
            return self._json({"running": ids,
                               "lifecycle": {i: lifecycle(i) for i in ids}})
        if path == "/api/cursos":
            return self._json({"cursos": cursos_payload()})
        m = re.match(r"^/api/cursos/(\d{2})$", path)
        if m:
            cp = curso_path(m.group(1))
            if not cp:
                return self._json({"error": "no disponible"}, 404)
            with open(cp, encoding="utf-8") as f:
                return self._json({"markdown": f.read()})
        m = re.match(r"^/api/labs/(\d{2,3})/(reto|solucion|guia)$", path)
        if m:
            lab_id, kind = m.group(1), m.group(2)
            txt = read_md(lab_id, kind)
            if txt is None:
                return self._json({"error": "no disponible"}, 404)
            return self._json({"markdown": txt})
        m = re.match(r"^/api/labs/(\d{2,3})/status$", path)
        if m:
            lab_id = m.group(1)
            if lab_id not in LAB_BY_ID:
                return self._json({"error": "lab inexistente"}, 404)
            mode = MODE.get(lab_id)
            payload = {
                "running": container_running(lab_id),
                "ttydPort": TTYD_BASE + int(lab_id),
                "mode": mode,
                "redCapable": red_capable(lab_id),
                **lifecycle(lab_id),
            }
            if mode == "red" and payload["running"]:
                flags = read_flags(lab_id)
                with LOCK:
                    cap = sorted(CAPTURED.get(lab_id, set()))
                payload["flagKinds"] = sorted(flags)   # solo los nombres
                payload["captured"] = cap
            return self._json(payload)
        if path.startswith("/api/"):
            return self._json({"error": "ruta desconocida"}, 404)
        return self._file(path)

    def do_POST(self):
        url = urlparse(self.path)
        path = url.path
        m = re.match(r"^/api/labs/(\d{2,3})/(start|stop|reset|check|keep|flag)$",
                     path)
        if not m:
            return self._json({"error": "ruta desconocida"}, 404)
        lab_id, action = m.group(1), m.group(2)
        if lab_dir(lab_id) is None:
            return self._json({"error": "lab inexistente"}, 404)

        qs = url.query.split("&")
        want_red = "mode=red" in qs and red_capable(lab_id)

        # Envío de bandera (solo modo red): comparar contra lo que el target
        # guarda en /opt/lab/.flags, que solo lee el servidor (docker exec -u 0).
        if action == "flag":
            if MODE.get(lab_id) != "red":
                return self._json(
                    {"ok": False, "error": "Las banderas solo se envían en red."},
                    400)
            n = int(self.headers.get("Content-Length", 0) or 0)
            try:
                body = json.loads(self.rfile.read(n) or b"{}")
            except ValueError:
                body = {}
            kind = str(body.get("kind", "")).lower()
            value = str(body.get("value", "")).strip()
            flags = read_flags(lab_id)
            if not flags:
                return self._json(
                    {"ok": False,
                     "error": "No pude leer las banderas (¿target corriendo?)."},
                    409)
            if kind not in flags:
                return self._json(
                    {"ok": False, "error": "Bandera desconocida: %s" % kind}, 400)
            correct = bool(value) and value == flags[kind]
            with LOCK:
                cap = CAPTURED.setdefault(lab_id, set())
                if correct:
                    cap.add(kind)
                captured = sorted(cap)
                remaining = sorted(set(flags) - cap)
            solved = correct and not remaining
            if solved:
                schedule_destroy(lab_id)
            return self._json({
                "ok": correct, "kind": kind, "correct": correct,
                "captured": captured, "remaining": remaining,
                "required": sorted(flags), "solved": solved,
                **lifecycle(lab_id),
            })

        # Levantar un lab con otros de la página ya corriendo consume RAM/CPU
        # de más: se rechaza con 409 salvo que el cliente confirme con ?force=1.
        if action in ("start", "reset") and "force=1" not in url.query.split("&"):
            others = [x for x in running_labs() if x != lab_id]
            if others:
                return self._json({
                    "ok": False,
                    "conflict": True,
                    "running": others,
                    "error": "Hay otros labs corriendo.",
                }, 409)

        if action == "keep":
            with LOCK:
                PENDING.pop(lab_id, None)
                KEPT.add(lab_id)
            return self._json({"ok": True, **lifecycle(lab_id)})

        if action == "check":
            code, out = dc(lab_id, "exec", "-T", "lab", "bash",
                           "/opt/lab/check.sh", timeout=180)
            if code == 0:
                schedule_destroy(lab_id)
        else:
            with LOCK:
                BUSY.add(lab_id)
                PENDING.pop(lab_id, None)
                KEPT.discard(lab_id)
                STARTED.pop(lab_id, None)
                CAPTURED.pop(lab_id, None)
            port = TTYD_BASE + int(lab_id)

            def _up(force=()):
                if want_red:
                    env = {"TCLAB_MODE": "red", "ATTACKER_PUB": str(port),
                           "TARGET_PUB": "0"}
                    return dc(lab_id, "--profile", "red", "up", "-d",
                              "--build", *force, env=env)
                env = {"TCLAB_MODE": "blue", "TARGET_PUB": str(port),
                       "ATTACKER_PUB": "0"}
                return dc(lab_id, "up", "-d", "--build", *force, env=env)

            def _down():
                args = ["down", "-v", "--remove-orphans", "-t", "5"]
                if red_capable(lab_id):
                    args = ["--profile", "red", *args]
                return dc(lab_id, *args)

            try:
                if action == "start":
                    code, out = _up()
                    if code == 0:
                        with LOCK:
                            MODE[lab_id] = "red" if want_red else "blue"
                elif action == "stop":
                    code, out = _down()
                    with LOCK:
                        MODE.pop(lab_id, None)
                else:  # reset
                    _down()
                    code, out = _up(force=("--force-recreate",))
                    if code == 0:
                        with LOCK:
                            MODE[lab_id] = "red" if want_red else "blue"
            finally:
                with LOCK:
                    BUSY.discard(lab_id)

        return self._json({
            "ok": code == 0,
            "code": code,
            "output": out[-20000:],  # recorta salidas enormes
            "running": container_running(lab_id),
            "mode": MODE.get(lab_id),
            "redCapable": red_capable(lab_id),
            **lifecycle(lab_id),
        })


def _raise_interrupt(signum, frame):  # noqa: ARG001
    raise KeyboardInterrupt


def main():
    for stream in (sys.stdout, sys.stderr):  # consola de Windows: acentos y emojis
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
    if not os.path.isdir(WEB_DIR):
        print(f"[!] No existe {WEB_DIR}", file=sys.stderr)
    httpd = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    httpd.daemon_threads = True
    # SIGTERM (kill) y, en Windows, cerrar la consola (SIGBREAK) siguen el
    # mismo camino que Ctrl+C: destruir los labs antes de salir.
    for sig in ("SIGTERM", "SIGBREAK", "SIGHUP"):
        if hasattr(signal, sig):
            try:
                signal.signal(getattr(signal, sig), _raise_interrupt)
            except (ValueError, OSError):
                pass
    # Limpia restos de una ejecución anterior y vigila el ciclo de vida.
    threading.Thread(target=reaper_loop, daemon=True).start()
    url = f"http://localhost:{PORT}"
    print(f"TerminalCero Lab escuchando en {url}")
    ttl = f"{TTL_MIN} min" if TTL_MIN > 0 else "sin límite"
    print(f"Autodestrucción: al resolver (+{GRACE_S}s), TTL {ttl}, al salir"
          + (" [desactivada al salir: TCLAB_KEEP_ON_EXIT=1]" if KEEP_ON_EXIT else ""))
    print("Ctrl+C para salir.")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nApagando.")
    finally:
        if not KEEP_ON_EXIT:
            print("Destruyendo labs en ejecución…")
            destroy_all("servidor apagado")
        httpd.server_close()


if __name__ == "__main__":
    main()
