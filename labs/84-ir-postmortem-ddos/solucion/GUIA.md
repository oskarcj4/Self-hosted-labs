# Resolución guiada · Lab 84

:::piensa Un incidente no se cierra cuando el servicio vuelve
Se cierra cuando **no puede volver a pasar igual** y queda **documentado**
para quien venga después. Aquí hay dos entregables: una mitigación duradera en
el firewall y un postmortem. Y el postmortem se escribe con lo que dice la
evidencia, no con lo que recuerdas o supones.
:::

**El plan:** (1) sacar del log quién, cuánto y cuándo, (2) aplicar la
mitigación en el firewall, (3) escribir el postmortem con esos datos y
(4) comprobar que el servicio sigue sirviendo.

## Paso 1 · ¿Qué dice la evidencia?

**Objetivo:** reunir los datos del postmortem: origen, volumen, impacto y
horas. Cada cifra que escribas después tiene que salir de aquí.

**Pregúntate:** en un log de Apache, ¿en qué columna está la IP, la hora, la
ruta y el código de respuesta?

:::pista Cómo hacerlo
Una línea del log tiene este aspecto:
```
203.0.113.7 - - [10/Oct/2026:11:32:02 +0000] "GET /buscar?q=%25%25%25 HTTP/1.1" 503 540 "-" "python-requests/2.31.0"
```
`awk` parte por espacios: `$1` es la IP, `$4` la fecha, `$7` la ruta y `$9`
el código HTTP.

Los logs de Apache en Debian sólo los lee root y el grupo `adm`; por eso
todos estos comandos llevan `sudo`.

**¿Desde dónde?** Agrupa por red `/24` (los tres primeros números de la IP):
```bash
sudo awk '{print $1}' /var/log/apache2/access.log | cut -d. -f1-3 | sort | uniq -c | sort -rn | head
```

| Parte | Qué hace |
|---|---|
| `awk '{print $1}'` | Sólo la IP de cada línea. |
| `cut -d. -f1-3` | Parte la IP por los puntos (`-d.`) y se queda con los campos 1 a 3: `203.0.113.7` → `203.0.113`, es decir, su red `/24`. |
| `sort \| uniq -c` | Ordena para juntar las iguales y cuenta cuántas hay de cada una. |
| `sort -rn \| head` | De más a menos, las 10 primeras. |

**Qué deberías ver:** dos redes con 400 peticiones cada una, que coinciden con
`/etc/ddos/blocklist.txt`.

**¿Cuántas IP, qué pidieron y qué recibieron?**
```bash
sudo awk '{print $1}' /var/log/apache2/access.log | sort -u | wc -l    # IP distintas
sudo awk '{print $7}' /var/log/apache2/access.log | sort | uniq -c     # rutas
sudo awk '{print $9}' /var/log/apache2/access.log | sort | uniq -c     # códigos HTTP
```
`sort -u` ordena y quita repetidas; `wc -l` cuenta las líneas que quedan.

**Qué deberías ver:** 80 IP distintas, todas contra `/buscar` y 800
respuestas `503` (servicio no disponible). Ese es tu **impacto**.

**¿Cuándo?**
```bash
sudo awk '{print $4}' /var/log/apache2/access.log | sort | sed -n '1p;$p'
```
El log está desordenado, así que primero se ordenan las fechas (dentro del
mismo día, el orden alfabético coincide con el cronológico). `sed -n '1p;$p'`
imprime sólo la primera línea (`1p`) y la última (`$p`).

**Qué deberías ver:** `11:30:00` y `11:35:05`. Esa es tu **cronología**.
:::

## Paso 2 · Mitigación duradera en el firewall

**Objetivo:** que el mismo ataque no vuelva a tumbar el servicio.

**Pregúntate:** ¿bloqueas a los atacantes conocidos o limitas a todo el mundo
por tasa? ¿Qué te protege mejor contra el siguiente ataque, que vendrá de
otras IP?

:::pista Opción A · bloquear los rangos de la blocklist
```bash
while read -r net; do
  [ -n "$net" ] && sudo iptables -I INPUT -s "$net" -j DROP
done < /etc/ddos/blocklist.txt
```
- `while read -r net; do … done < fichero` lee el fichero línea a línea y
  guarda cada una en `$net`. `-r` evita que una `\` se interprete.
- `[ -n "$net" ] &&` salta las líneas vacías.
- `iptables -I INPUT` **inserta** la regla al principio de la cadena `INPUT`
  (el tráfico que entra en esta máquina). `-s` es el origen y `-j DROP`
  descarta el paquete sin responder.

Preciso contra lo conocido, pero no hace nada contra IP nuevas.
:::

:::pista Opción B · limitar la tasa de conexiones nuevas al 80
```bash
sudo iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW \
  -m hashlimit --hashlimit-above 25/sec --hashlimit-burst 50 \
  --hashlimit-mode srcip --hashlimit-name http -j DROP
```

| Parte | Qué hace |
|---|---|
| `-A INPUT -p tcp --dport 80` | Añade (`-A`, al final) una regla para el tráfico TCP que entra al puerto 80. |
| `-m conntrack --ctstate NEW` | Sólo conexiones **nuevas**. Las ya establecidas no se tocan, así no cortas descargas en curso. |
| `-m hashlimit` | Módulo que lleva un contador por cada clave (aquí, cada IP). |
| `--hashlimit-above 25/sec` | La regla se aplica a lo que **supere** 25 conexiones nuevas por segundo. |
| `--hashlimit-burst 50` | Permite un pico inicial de 50 antes de empezar a limitar. |
| `--hashlimit-mode srcip` | La clave del contador es la IP de origen: cada IP tiene su propio límite. |
| `--hashlimit-name http` | Nombre de la tabla de contadores (aparece en `/proc/net/ipt_hashlimit/`). |
| `-j DROP` | Lo que supera el límite se descarta. |

Protege también contra IP nuevas. Lo ideal es **combinar** A y B.
:::

Comprueba las reglas:
```bash
sudo iptables -S INPUT
```
`-S` lista las reglas en el mismo formato con el que se escriben (más fácil de
leer y copiar que `-L`). **Qué deberías ver:** tus reglas `-j DROP`.

## Paso 3 · Escribe el postmortem

**Objetivo:** un documento que permita a otra persona entender qué pasó, qué
se hizo y qué falta, sin preguntarte.

**Pregúntate:** ¿cada cifra y cada hora que escribes sale de la evidencia del
paso 1? Lo que no sepas, dilo como "no consta", no lo inventes.

:::pista Plantilla con los datos de este incidente
```bash
cat > ~/postmortem.md <<'EOF'
# Postmortem — DDoS contra web-84 (10/10/2026)

## Impacto
800 peticiones a /buscar respondidas con 503 entre 11:30 y 11:35 (UTC).
Origen: 80 IP de dos redes, 203.0.113.0/24 y 198.51.100.0/24
(user-agent python-requests). Sin pérdida de datos.

## Cronología (UTC, según access.log)
- 11:30:00 primera petición del ataque.
- 11:35:05 última petición registrada; el flood amaina.
- Triage: los rangos se confirman en /etc/ddos/blocklist.txt.
- Mitigación aplicada en el cierre del incidente (ver abajo).

## Mitigación
- Bloqueo de 203.0.113.0/24 y 198.51.100.0/24 en iptables (INPUT).
- Rate limit hashlimit: más de 25 conexiones nuevas/s por IP al puerto 80 se descartan.

## Prevención (seguimiento)
- Persistir las reglas de iptables (se pierden al reiniciar). Responsable: <quién>. Fecha: <cuándo>.
- Rate limit también en el reverse proxy y alerta automática por tasa de 5xx.
- Evaluar CDN si el volumen supera el ancho de banda de entrada.
EOF
```
`<<'EOF'` con comillas: el texto se escribe **tal cual**, sin que la shell
intente sustituir nada que parezca una variable.

Fíjate en que la cronología sólo afirma lo que el log demuestra. El
validador busca que estén las cuatro secciones: impacto, cronología,
mitigación y prevención.
:::

## Paso 4 · Verifica

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1/
bash /opt/lab/check.sh
```
`-o /dev/null` tira el cuerpo de la respuesta y `-w '%{http_code}\n'` imprime
sólo el código HTTP. **Qué deberías ver:** `200`. Tus reglas no afectan a
`127.0.0.1`: ni está en la blocklist ni hace 25 conexiones por segundo.

## Cómo actuar en una situación así

- **Persiste las reglas** (`iptables-save > /etc/iptables/rules.v4` con el
  paquete `iptables-persistent`) o desaparecen al reiniciar.
- El postmortem es **sin culpa** (*blameless*): busca causas y acciones, no
  responsables. Cada acción de prevención lleva dueño y fecha.
- Revisa los **falsos positivos**: si un `/24` bloqueado tenía usuarios
  legítimos, acota el bloqueo o confía en el rate limit.

## Si te atascas

- **El check no ve la mitigación:** tus reglas deben estar en la cadena
  `INPUT` y terminar en `-j DROP` o `-j REJECT`. Compruébalo con
  `sudo iptables -S INPUT`.
- **El postmortem sale 3/4:** al validador le faltan palabras clave de alguna
  sección. Usa títulos claros: Impacto, Cronología, Mitigación, Prevención.
- **`curl` ya no da 200:** revisa que no hayas bloqueado `127.0.0.1` ni puesto
  `-P INPUT DROP` (política por defecto) sin una regla que permita lo demás.
