# 00 · Cómo estudiar con estos cursos

> Ruta de aprendizaje, mapa de qué módulo sirve para qué lab y el método para investigar un servidor que no conoces.

## Para qué existen estos cursos

Los labs te sueltan en un servidor real (un contenedor Docker) con un problema: un intruso, un servicio mal configurado, un secreto expuesto. El `RETO.md` te dice **qué** conseguir, la `SOLUCION.md` te dice **exactamente qué teclear**. Entre las dos hay un hueco: entender **por qué** funciona cada comando y **dónde mirar** cuando el problema es nuevo.

Estos módulos cubren ese hueco. No te dan la respuesta de ningún lab. Te dan:

- El modelo mental: qué es un proceso, qué es un permiso, por qué un fichero se ejecuta al abrir la terminal.
- Las herramientas, flag por flag, con salidas de ejemplo para que sepas **leerlas**.
- Las trampas típicas: lo que rompe un servicio, lo que te deja fuera del servidor, lo que borra evidencia.
- Ejercicios cortos que puedes hacer en cualquier lab (o en tu propio Linux) sin estropear el reto.

Ningún curso garantiza que resuelvas un lab a la primera. Lo que sí debería garantizar: que sepas **dónde estás parado** y que, cuando ejecutes un comando, tengas una idea clara de lo que va a hacer.

## La regla número uno: no memorices, aprende a preguntar

En Linux avanzado nadie se sabe todos los flags. Lo que se aprende es a preguntar al sistema:

```bash
man ss                 # manual completo (q para salir, /palabra para buscar, n siguiente)
ss --help              # resumen rápido de flags
help source            # ayuda de comandos internos de bash (builtins)
type -a ls             # ¿qué es 'ls'? ¿alias, función, binario? ¿dónde?
apropos firewall       # busca manuales por palabra clave (si man-db está instalado)
```

Y antes de ejecutar algo que modifica el sistema, hazte tres preguntas:

1. ¿Qué cambia? (un fichero, un proceso, una regla de red)
2. ¿Se puede deshacer? (¿hice copia? ¿sé el comando inverso?)
3. ¿Cómo compruebo que funcionó? (¿qué comando me lo demuestra?)

## El método de investigación (sirve para todos los labs)

Cuando entras a un servidor con un problema, sigue siempre el mismo orden. Te evita tocar cosas a ciegas.

1. **Lee el reto entero.** Los objetivos suelen esconder pistas ("no borres la llave legítima", "sin parar servicios").
2. **Observa antes de tocar.** Procesos (`ps`), red (`ss`), ficheros recientes (`find -newer`), logs (`/var/log`), tareas programadas (`cron`, `systemctl list-timers`).
3. **Forma una hipótesis.** "Este proceso sale de `/tmp` y escucha en un puerto raro: es el beacon".
4. **Confírmala con una segunda fuente.** Si `ps` dice una cosa, mira `/proc`. Si la documentación dice otra, manda el runtime.
5. **Actúa en el orden correcto.** Primero lo que hace volver al problema (persistencia), luego el problema (proceso), luego los restos (binarios).
6. **Verifica.** Vuelve a mirar con los mismos comandos del paso 2. Después ejecuta `bash /opt/lab/check.sh`.

> El validador (`check.sh`) es un buen profesor: dice qué objetivo falla y, a veces, por qué. Léelo con calma. Incluso puedes abrirlo con `cat /opt/lab/check.sh` para ver qué comprueba, sin que eso te dé la respuesta.

## Ruta recomendada

Si empiezas desde cero, sigue este orden. Cada módulo se apoya en los anteriores.

| Orden | Módulo | Te prepara para |
|---|---|---|
| 1 | [01 · Orientarse en un Linux desconocido](#curso/01) | Todos los labs |
| 2 | [02 · La shell por dentro: .bashrc, PATH e historial](#curso/02) | 01, 15 |
| 3 | [03 · Procesar texto: grep, cut, sort, uniq, awk](#curso/03) | 05, 12, 13, 14 |
| 4 | [04 · Usuarios, grupos y permisos](#curso/04) | 05, 10, 11, 23 |
| 5 | [05 · sudo y mínimo privilegio](#curso/05) | 05, 23 |
| 6 | [06 · Procesos y memoria](#curso/06) | 02, 04, 09 |
| 7 | [07 · Persistencia: cron y escondites del atacante](#curso/07) | 02, 06 |
| 8 | [08 · systemd y journald](#curso/08) | 06, 16 |
| 9 | [09 · Logs y respuesta a incidentes](#curso/09) | 01, 09, 12, 13, 14, 20, 22 |
| 10 | [10 · Redes para defensores](#curso/10) | 02, 03, 08, 12, 19 |
| 11 | [11 · Firewall: iptables, TCP wrappers y fail2ban](#curso/11) | 01, 08, 14, 18, 20 |
| 12 | [12 · SSH, TLS y VPN](#curso/12) | 01, 17, 19, 21 |
| 13 | [13 · Secretos y credenciales](#curso/13) | 07, 21 |

## Mapa lab → módulos

Si vas directo a un lab, mira aquí qué leer antes. Cada lab muestra también, bajo su descripción, el aviso **¿Dificultad?** con los módulos que conviene leer.

| Lab | Tema | Módulos clave |
|---|---|---|
| [01](#lab/01) | Intruso SSH persistente | 02, 09, 11, 12 |
| [02](#lab/02) | Beacon + cron | 06, 07, 10 |
| [03](#lab/03) | Vhost oculto → Jenkins | 10 |
| [04](#lab/04) | Proceso fantasma | 06 |
| [05](#lab/05) | Cuenta backdoor UID 0 | 03, 04, 05 |
| [06](#lab/06) | Timer de systemd rogue | 07, 08 |
| [07](#lab/07) | Credenciales de fábrica | 13 |
| [08](#lab/08) | Segmentación de red | 10, 11 |
| [09](#lab/09) | Logs borrados | 06, 09 |
| [10](#lab/10) | Binario SUID backdoor | 04 |
| [11](#lab/11) | chattr +i | 04 |
| [12](#lab/12) | Exfiltración por DNS | 03, 09, 10 |
| [13](#lab/13) | Webshell | 03, 09 |
| [14](#lab/14) | Fuerza bruta SSH | 03, 09, 11 |
| [15](#lab/15) | Secuestro de PATH | 02 |
| [16](#lab/16) | Servicializar con systemd | 08 |
| [17](#lab/17) | Endurecer sshd_config | 12 |
| [18](#lab/18) | Firewall default-deny | 11 |
| [19](#lab/19) | VPN WireGuard | 10, 12 |
| [20](#lab/20) | fail2ban | 09, 11 |
| [21](#lab/21) | TLS + HTTPS | 12, 13 |
| [22](#lab/22) | auditd | 09 |
| [23](#lab/23) | Usuarios y sudo mínimos | 04, 05 |

## Cómo leer los módulos

- Los bloques de código son comandos reales. Puedes ejecutarlos en cualquier lab: casi todos sólo **leen**. Cuando uno modifica algo, se avisa.
- Las secciones **Leer la salida** explican columna por columna lo que imprime un comando. Es la parte más importante: ejecutar es fácil, interpretar es lo que se aprende.
- Los **Ejercicios** tienen la respuesta plegada. Intenta primero.
- Al final de cada módulo hay una **chuleta** para tener a mano.

## Hábitos que te van a salvar

- **Copia antes de editar** un fichero de configuración: `sudo cp -a fichero fichero.bak.$(date +%s)`. Pero ojo: en los labs de secretos, las copias son justamente el problema. Guárdalas fuera del sitio expuesto y bórralas al terminar.
- **Valida antes de recargar**: `sshd -t`, `nginx -t`, `visudo -c`. Una configuración rota puede dejarte fuera.
- **Prueba como el usuario afectado**, no como root: `sudo -u billing cat fichero`, `sudo -u nobody touch carpeta/x`. Root lo puede casi todo y esconde los problemas de permisos.
- **Prueba desde la red, no desde localhost**, cuando el objetivo trata de exposición: `curl http://$(hostname -I | awk '{print $1}')/`.
- **El estado en ejecución manda**: la wiki, los comentarios y el README pueden mentir. `ss`, `ps`, `nginx -T`, `docker inspect` dicen la verdad.
