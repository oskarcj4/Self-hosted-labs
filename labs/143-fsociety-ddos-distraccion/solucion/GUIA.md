# Resolución guiada · Lab 143

:::piensa El ruido tapa la señal
Un DDoS que tira la web es escandaloso y fácil de ver. Por eso es la tapadera
perfecta: mientras todo el equipo mira las gráficas de tráfico, nadie mira el
disco. Tu trabajo no termina cuando la web vuelve a responder: termina cuando
sabes **qué pasó mientras la web se caía**.
:::

**El plan:** (1) averiguar quién inunda y desde cuándo, (2) contener la
inundación, (3) buscar qué cambió en el disco *durante* la inundación,
(4) documentarlo y (5) limpiar sin destruir la evidencia.

## Paso 1 · ¿Quién inunda y desde cuándo?

**Objetivo:** sacar la IP del atacante y la hora en que empezó. La IP la
necesitas para el informe; la hora es la que abre la "ventana" que
investigarás en el paso 3.

**Pregúntate:** nginx apunta cada petición en `/var/log/nginx/access.log`.
Si una sola IP genera la inundación, ¿cómo la distingues entre miles de
líneas sin leerlas una a una?

:::pista Cómo hacerlo
Primero mira cómo es una línea del log, para saber qué columna es qué:
```bash
sudo tail -3 /var/log/nginx/access.log
```
```
10.143.0.66 - - [26/Nov/2026:10:04:51 +0000] "GET / HTTP/1.1" 200 64 "-" "Wget"
```
`awk` parte cada línea por espacios y llama a cada trozo `$1`, `$2`…:

| `$1` | `$2` `$3` | `$4` `$5` | `$6` | `$7` | `$8` | `$9` |
|---|---|---|---|---|---|---|
| `10.143.0.66` | `-` `-` | fecha y zona | `"GET` | `/` | `HTTP/1.1"` | `200` |
| IP del cliente | usuario (vacío) | cuándo | método | **ruta pedida** | protocolo | código de respuesta |
Sabiendo eso, cuenta cuántas veces pide `/` cada IP:
```bash
sudo awk '$7=="/"{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head
```

| Parte | Qué hace |
|---|---|
| `awk '$7=="/"{print $1}'` | De cada línea cuya ruta (`$7`) sea exactamente `/`, imprime sólo la IP (`$1`). |
| `sort` | Ordena las IP para que las repetidas queden juntas (`uniq` sólo junta líneas *contiguas*). |
| `uniq -c` | Colapsa las repetidas y antepone cuántas veces aparecía cada una. |
| `sort -rn` | Ordena por ese número (`-n`), de mayor a menor (`-r`). |
| `head` | Las 10 primeras: el "top" de IP. |

**Qué deberías ver:** una IP con miles de peticiones arriba del todo y un
par de IP de oficina con 1 o 2. Esa primera es `ip_ddos`.

Ahora, ¿cuándo empezó? La **primera** línea de esa IP en el log:
```bash
sudo grep -m1 '^10\.143\.0\.66 ' /var/log/nginx/access.log
```
- `-m1` hace que `grep` pare en la primera coincidencia (el log va en orden
  cronológico, así que es la más antigua).
- `^` ancla al principio de la línea y `\.` es un punto literal: sin eso,
  `10.143.0.6` también encajaría con `10.143.0.66`, o una IP podría aparecer
  en otra columna.

**Qué deberías ver:** `[...:02:11:00 +0000]`. Apunta **02:11**: inicio del DDoS.
:::

## Paso 2 · Contén la inundación

**Objetivo:** que una sola IP no pueda acaparar el servidor. No puedes
"apagar" un DDoS desde el propio servidor, pero sí poner un tope por
cliente: el que se pase recibe un `429 Too Many Requests` barato en vez de
una página entera.

**Pregúntate:** el límite se cuenta *por IP*. ¿Dónde guarda nginx esa
cuenta, y en qué parte de la configuración se declara para que sea común a
todo el servidor?

:::pista Cómo hacerlo
En nginx el límite tiene **dos piezas**, y es lo que más confunde:

1. **La zona** (`limit_req_zone`): una tabla en memoria compartida donde nginx
   lleva la cuenta de cada IP. Se declara una vez, en el contexto `http`.
   En Debian, todo lo que pongas en `/etc/nginx/conf.d/*.conf` se carga
   dentro de `http`, así que va ahí.
2. **La aplicación** (`limit_req`): dice "esta `location` usa esa zona".
   Va dentro de `location /`.

Crea la zona:
```bash
sudo tee /etc/nginx/conf.d/limites.conf <<'N'
limit_req_zone  $binary_remote_addr zone=raiz:10m rate=5r/s;
limit_conn_zone $binary_remote_addr zone=conx:10m;
limit_req_status  429;
limit_conn_status 429;
N
```
`sudo tee fichero <<'N' … N` escribe en `fichero` todo lo que hay entre las
dos `N` (un *heredoc*). Se usa `tee` con `sudo` porque `sudo echo … > fichero`
**no funciona**: la redirección `>` la hace tu shell, sin privilegios, antes
de que `sudo` entre en juego.

| Directiva | Qué significa |
|---|---|
| `$binary_remote_addr` | La clave de la cuenta: la IP del cliente (en binario, ocupa menos que en texto). |
| `zone=raiz:10m` | Nombre de la zona (`raiz`) y memoria reservada (10 MB ≈ 160 000 IP). |
| `rate=5r/s` | Ritmo permitido: 5 peticiones por segundo por IP. |
| `limit_conn_zone … zone=conx` | Otra tabla, esta para contar **conexiones abiertas a la vez** por IP. |
| `limit_req_status 429` / `limit_conn_status 429` | Qué responder al que se pasa. Por defecto nginx da `503`, que parece una caída del servidor; `429` dice la verdad: "vas demasiado rápido". |

Ahora aplícala. Abre el sitio:
```bash
sudo nano /etc/nginx/sites-available/allsafe
```
y deja `location /` así (añades las dos líneas `limit_`):
```nginx
    location / {
        limit_req zone=raiz burst=10 nodelay;
        limit_conn conx 10;
        try_files $uri $uri/ =404;
    }
```

| Directiva | Qué significa |
|---|---|
| `limit_req zone=raiz` | Aplica a esta ruta el ritmo de la zona `raiz`. |
| `burst=10` | Tolera una ráfaga de hasta 10 peticiones por encima del ritmo (un navegador pide varias cosas de golpe al cargar). |
| `nodelay` | Las de la ráfaga se sirven al momento, sin hacerlas esperar en cola. Lo que pase de la ráfaga, `429`. |
| `limit_conn conx 10` | Máximo 10 conexiones simultáneas por IP. |

No toques `location /static/`: es otra `location` y no hereda lo que pongas en
`location /`. Por eso los estáticos se quedan sin límite.

Valida y aplica:
```bash
sudo nginx -t && sudo systemctl reload nginx
```
`nginx -t` comprueba la sintaxis sin tocar el servicio; el `&&` hace que sólo
se recargue si la prueba pasa. `reload` (no `restart`) aplica la configuración
nueva sin cortar las conexiones que ya hay.

**Comprueba que funciona** desde dos ángulos:
```bash
sudo tail -n 5 /var/log/nginx/access.log      # el bot ya recibe 429
hey -z 5s -c 20 http://127.0.0.1/             # tu propia ráfaga
```
`hey` es un generador de carga: `-z 5s` dispara durante 5 segundos y `-c 20`
con 20 clientes en paralelo. Al final, en *Status code distribution*, verás
unos pocos `[200]` y muchos `[429]`. Repite con `http://127.0.0.1/static/app.js`:
ahí todo debe ser `[200]`.
:::

## Paso 3 · ¿Qué tapaba el ruido?

**Objetivo:** encontrar lo que el atacante dejó en el disco mientras todos
miraban el tráfico.

**Pregúntate:** ya sabes **cuándo** fue el ruido (desde las 02:11). En vez
de buscar "algo raro" en todo el sistema, ¿puedes preguntar al disco qué
cambió justo en esa ventana?

:::pista Cómo hacerlo
Cada fichero guarda su fecha de última modificación (*mtime*). `find` puede
filtrar por ella:
```bash
sudo find / -xdev -type f -newermt "$(date +%F) 02:10" ! -newermt "$(date +%F) 02:20" 2>/dev/null
```

| Parte | Qué hace |
|---|---|
| `find /` | Busca empezando en la raíz. |
| `-xdev` | No salta a otros sistemas de ficheros (`/proc`, `/sys`…): son virtuales, enormes y sólo meten ruido. |
| `-type f` | Sólo ficheros normales, no directorios. |
| `-newermt "FECHA"` | Modificado **después** de esa fecha y hora (`m` = mtime, `t` = la fecha va en texto). |
| `! -newermt "FECHA"` | El `!` lo niega: modificado **no** después, o sea, **antes** de esa hora. Juntas forman la ventana 02:10–02:20. |
| `$(date +%F)` | Se sustituye por la fecha de hoy (`2026-11-26`), así no la escribes a mano. |
| `2>/dev/null` | Tira los avisos de "permiso denegado" para que no tapen el resultado. |

**Qué deberías ver:** tres o cuatro ficheros, entre ellos un `cron.d`, un
script en `/usr/local/bin` y un `fsociety00.dat`.

Ahora **léelos antes de tocar nada**:
```bash
cat /etc/cron.d/fsociety
cat /usr/local/bin/fsociety-beacon
sudo tail -3 /var/log/fsociety.log
```
El cron se lee así: los cinco `*` son minuto, hora, día, mes y día de la
semana; cinco asteriscos = **cada minuto**. Luego va el usuario (`root`) y el
comando. Es decir: cada minuto, como root, se ejecuta el beacon. El log
`fsociety.log` lo confirma: una línea nueva por minuto.

Y la hora exacta en que se plantó:
```bash
stat -c '%y  %n' /etc/cron.d/fsociety /usr/local/bin/fsociety-beacon /opt/allsafe/.fsociety/fsociety00.dat
```
`stat -c` imprime sólo lo que le pidas: `%y` es la fecha de modificación y
`%n` el nombre. **Qué deberías ver:** `02:14:00` en los tres. Tres minutos
después de empezar el DDoS: esa es tu prueba de que el ruido era la tapadera.
:::

:::ojo No te fíes de que siempre sea tan fácil
Aquí las fechas son honestas. Un atacante cuidadoso puede cambiarlas con
`touch -d`. Por eso, en un caso real, la ventana de tiempo es un **punto de
partida**, no una prueba única: crúzala con logs, `auth.log` y paquetes.
:::

## Paso 4 · Documenta antes de borrar

**Objetivo:** dejar por escrito lo encontrado **antes** de limpiar. Si borras
primero, la única prueba de que existía era el propio fichero.

**Pregúntate:** de `fsociety00.dat` vas a conservar el fichero, pero ¿cómo
demuestras mañana que nadie lo ha modificado desde que lo encontraste?

:::pista Cómo hacerlo
Con su **hash**: una huella de 64 caracteres que cambia por completo si
cambia un solo byte del fichero.
```bash
sha256sum /opt/allsafe/.fsociety/fsociety00.dat
```
Ahora escribe los dos ficheros. Puedes hacerlo con `nano ~/hallazgos.txt`, o
así, dejando que la shell calcule el hash por ti:
```bash
DAT=/opt/allsafe/.fsociety/fsociety00.dat
cat > ~/hallazgos.txt <<EOF
ip_ddos=10.143.0.66
ruta_persistencia=/etc/cron.d/fsociety
binario_beacon=/usr/local/bin/fsociety-beacon
fsociety_dat=$DAT
sha256_dat=$(sha256sum $DAT | cut -d' ' -f1)
EOF
```
- Este heredoc usa `<<EOF` **sin comillas**: así la shell sustituye `$DAT` y
  `$(…)` por su valor. Con `<<'EOF'` (con comillas) los escribiría tal cual.
- `sha256sum` imprime `hash  ruta`; `cut -d' ' -f1` parte por espacios y se
  queda con el primer campo, el hash.

```bash
cat > ~/timeline.txt <<'EOF'
02:11  empieza el DDoS a / desde 10.143.0.66 (access.log)
02:14  se planta /etc/cron.d/fsociety + /usr/local/bin/fsociety-beacon y cae fsociety00.dat (mtime)
Conclusión: la persistencia se plantó durante la inundación; el DDoS era la distracción.
EOF
cat ~/hallazgos.txt ~/timeline.txt     # revisa que no haya huecos
```
:::

## Paso 5 · Erradica, conserva la evidencia

**Objetivo:** que el beacon no vuelva a ejecutarse, sin borrar
`fsociety00.dat`.

**Pregúntate:** ¿qué hay que quitar para que deje de ejecutarse: el script,
el cron que lo lanza, o ambos? ¿Y hace falta matar algún proceso?

:::pista Cómo hacerlo
Ambos: el cron es el **mecanismo** (lo que hace que vuelva) y el script es la
**carga**. Si quitas sólo el script, el cron sigue intentándolo; si quitas sólo
el cron, dejas el binario listo para reutilizar.
```bash
sudo rm /etc/cron.d/fsociety /usr/local/bin/fsociety-beacon
sudo systemctl restart cron
```
cron ya revisa `/etc/cron.d` cada minuto; el `restart` sólo fuerza que olvide
la entrada ya, sin esperar.

¿Proceso que matar? Este beacon escribe una línea y termina: no se queda
vivo. Compruébalo en vez de suponerlo:
```bash
pgrep -af '[f]society-beacon' || echo "no hay beacon corriendo"
sleep 70; sudo tail -2 /var/log/fsociety.log    # no debe aparecer ninguna línea nueva
```
El `[f]` es un truco: la expresión `[f]society-beacon` encaja con el texto
`fsociety-beacon`, pero **no consigo misma** (en su propia línea de comandos
lo que aparece es `[f]society…`). Sin él, `pgrep -f`/`pkill -f` se encuentran
a sí mismos o al `sudo` que los lanza, y `sudo pkill -f fsociety-beacon` acaba
matando su propio `sudo` (verás `Terminated`).

No borres `fsociety00.dat`: es la evidencia que acabas de documentar.
:::

## Comprueba

```bash
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- Todo pico de tráfico anómalo abre una **ventana temporal**: audítala en
  disco (`find -newermt`), cuentas, cron, timers de systemd y `authorized_keys`.
- **Documenta → luego limpia.** El hash del artefacto va al informe (cadena de
  custodia), no a la papelera.
- Un límite por IP no frena una botnet de miles de IP: eso se resuelve antes
  del servidor (CDN, anycast, *scrubbing*). Aquí lo importante era no quedarse
  en el DDoS.

## Si te atascas

- **Sale 503 en vez de 429:** falta `limit_req_status 429;` en `limites.conf`.
- **`nginx -t` dice `"limit_req_zone" directive is not allowed here`:** la
  pusiste dentro de `server` o `location`. Va en `conf.d/`, que es contexto `http`.
- **`nginx -t` dice `zero size shared memory zone "raiz"`:** usas
  `limit_req zone=raiz` pero la zona no existe o tiene otro nombre. Revisa que
  `limites.conf` se creó y que los nombres coinciden.
- **`/static/` también da 429:** pusiste el límite a nivel de `server`, fuera
  de `location /`.
- **El `find` no saca nada:** revisa que escribiste las comillas alrededor de
  `"$(date +%F) 02:10"`; sin ellas, la fecha y la hora llegan a `find` como dos
  argumentos distintos.
