# 03 · Procesar texto: grep, cut, sort, uniq y awk

> En Linux casi todo es texto: logs, /etc/passwd, la salida de ss o ps. Saber filtrar, cortar, contar y ordenar texto es lo que convierte 10.000 líneas de log en una respuesta.

## 1. La idea: el pipeline de análisis

Casi todos los análisis de los labs siguen la misma forma:

```
FILTRAR  →  EXTRAER  →  NORMALIZAR  →  CONTAR  →  ORDENAR  →  RECORTAR
 grep        grep -o      tr/awk        uniq -c    sort -rn    head
             cut/awk
```

Ejemplo con un log de SSH inventado:

```bash
grep 'Failed password' auth.log \
  | grep -oE 'from [0-9.]+' \
  | awk '{print $2}' \
  | sort | uniq -c | sort -rn | head
```

Paso a paso:

1. `grep 'Failed password'` → sólo las líneas de intentos fallidos.
2. `grep -oE 'from [0-9.]+'` → de cada línea, sólo el trozo `from 192.0.2.10`.
3. `awk '{print $2}'` → del trozo, la segunda palabra: la IP.
4. `sort` → pone las IPs iguales juntas (imprescindible para el siguiente paso).
5. `uniq -c` → colapsa repetidas consecutivas y antepone cuántas había.
6. `sort -rn` → ordena por ese número, de mayor a menor.
7. `head` → los 10 primeros.

Salida:

```
    412 192.0.2.10
     87 198.51.100.77
      3 192.0.2.200
```

> Método para entender un pipeline que no es tuyo: ejecútalo **por partes**. Primero sólo `grep 'Failed password' auth.log | head -3`, luego añade el segundo comando, y así. Ver la salida intermedia es la mejor explicación.

## 2. grep: encontrar líneas

`grep PATRÓN fichero` imprime las líneas que contienen el patrón.

| Flag | Qué hace | Cuándo usarlo |
|---|---|---|
| `-i` | Ignora mayúsculas/minúsculas | Directivas de config (`PermitRootLogin` vs `permitrootlogin`) |
| `-v` | Invierte: líneas que NO coinciden | Quitar comentarios: `grep -v '^#'` |
| `-n` | Muestra número de línea | Para luego editar esa línea |
| `-c` | Sólo cuenta coincidencias | ¿cuántos fallos hay? |
| `-o` | Imprime sólo el trozo que coincide, no la línea | Extraer IPs, dominios |
| `-E` | Regex extendida (`+`, `?`, `\|`, `()` sin escapar) | Casi siempre que uses regex |
| `-F` | Patrón literal, sin regex | Buscar una contraseña con `#`, `.`, `$` dentro |
| `-w` | Palabra completa | `-w root` no coincide con `rootkit` |
| `-r` / `-R` | Recursivo en carpetas | Buscar en todo `/etc` o `/var/www` |
| `-l` | Sólo nombres de fichero que coinciden | ¿qué ficheros contienen esto? |
| `-q` | Silencioso, sólo código de salida | En `if` y scripts |
| `-A n` / `-B n` / `-C n` | n líneas de contexto después / antes / ambos | Ver qué pasó alrededor de un evento |
| `-h` | No imprime el nombre del fichero | Al buscar en varios y luego contar |

```bash
grep -n PermitRootLogin /etc/ssh/sshd_config
grep -vE '^\s*(#|$)' /etc/ssh/sshd_config      # config sin comentarios ni líneas vacías
grep -rlF 'contraseña-literal' /etc /opt 2>/dev/null
grep -C 3 'Accepted' auth.log                  # cada login con 3 líneas de contexto
```

### Regex mínima que necesitas

| Patrón | Significa | Ejemplo |
|---|---|---|
| `^` | Inicio de línea | `^root:` |
| `$` | Fin de línea | `ACCEPT$` |
| `.` | Cualquier carácter | `a.c` = abc, a-c… |
| `*` | El anterior 0 o más veces | `ab*` = a, ab, abbb |
| `+` | El anterior 1 o más veces (con -E) | `[0-9]+` |
| `[abc]` | Uno de esos | `[0-9]`, `[a-z]` |
| `[^abc]` | Cualquiera menos esos | `[^ ]+` = una "palabra" sin espacios |
| `\s` | Espacio o tabulador | `^\s*#` = línea comentada aunque tenga sangría |
| `\.` | Un punto literal | `auth\.log` |
| `\(` | Paréntesis literal | `system\(` busca la llamada `system(` |
| `[[:space:]]` | Espacio (versión POSIX, funciona en todos los grep) | `sshd:[[:space:]]*` |

Y la alternativa: con `-E`, la barra vertical separa opciones. `grep -E 'Failed|Invalid'` encuentra líneas con cualquiera de las dos palabras. `(a|b)` agrupa la alternativa dentro de un patrón más largo: `^\s*(#|$)` = línea que, tras espacios opcionales, es un comentario o está vacía.

Para buscar una función como `system(` necesitas escapar el paréntesis (`system\(`) porque con `-E` el paréntesis agrupa.

## 3. cut: columnas por separador

```bash
cut -d: -f1 /etc/passwd          # campo 1 con separador ':' → nombres de usuario
cut -d: -f1,3 /etc/passwd        # campos 1 y 3 → usuario:uid
cut -d= -f2- fichero.conf        # todo desde el campo 2 (por si el valor contiene '=')
cut -c1-10 fichero               # caracteres 1 a 10
```

`cut` es simple y rápido, pero sólo entiende **un** carácter separador exacto. Si las columnas se separan con varios espacios (como `ps` o `ss`), usa `awk`.

## 4. sort y uniq: contar y ordenar

```bash
sort fichero           # alfabético
sort -n                # numérico (10 después de 9, no después de 1)
sort -rn               # numérico descendente
sort -u                # ordena y quita duplicados
sort -t: -k3 -n /etc/passwd   # por el campo 3 (uid), separador ':'
uniq                   # quita duplicados CONSECUTIVOS (por eso va después de sort)
uniq -c                # y cuenta cuántos había
uniq -d                # sólo los que estaban repetidos
```

> Error clásico: `uniq -c` sin `sort` antes. Como sólo junta repetidos **seguidos**, la misma IP aparece contada en trozos. Siempre `sort | uniq -c`.

## 5. tr, wc, head, tail

```bash
tr 'a-z' 'A-Z'          # minúsculas a mayúsculas
tr -d '\r'              # borra retornos de carro (ficheros que vienen de Windows)
tr '\0' '\n'            # convierte separadores NUL en saltos de línea (/proc/PID/cmdline, environ)
tr ':' '\n' <<< "$PATH" # una carpeta del PATH por línea
wc -l                   # cuenta líneas
head -n 5 ; tail -n 5   # primeras / últimas
tail -n +2              # todo desde la línea 2 (salta una cabecera)
```

## 6. awk: el cuchillo suizo

`awk` lee línea a línea, parte cada línea en **campos** y ejecuta un programa. Lo mínimo:

```bash
awk '{print $1}' fichero          # primer campo (separador por defecto: espacios/tabs, cualquier cantidad)
awk -F: '{print $1, $3}' /etc/passwd   # separador ':'; imprime usuario y uid
awk '{print $NF}'                 # NF = número de campos; $NF = el ÚLTIMO campo
awk '{print $(NF-1)}'             # el penúltimo
awk 'END {print NR}'              # NR = número de línea; al final, total de líneas
```

### Condiciones: el filtro de awk

```bash
awk -F: '$3 == 0' /etc/passwd             # líneas cuyo campo 3 (uid) vale 0
awk -F: '$3 >= 1000 {print $1}' /etc/passwd   # usuarios "humanos"
awk '$5 ~ /sshd/' auth.log                # campo 5 contiene 'sshd' (~ = coincide con regex)
awk 'length($0) > 100' fichero            # líneas de más de 100 caracteres
```

Estructura: `awk 'CONDICIÓN {ACCIÓN}'`. Sin acción, imprime la línea. Sin condición, actúa en todas.

### Partir un campo en trozos

Un dominio como `abc.def.ejemplo.com` es un solo campo para awk. Para quedarte con el "dominio base" (las dos últimas etiquetas) pásalo a otro awk con `.` como separador:

```bash
echo "x7f3.datos.ejemplo.com" | awk -F. '{print $(NF-1)"."$NF}'
# ejemplo.com
```

### Contar con arrays (sin sort | uniq)

```bash
awk '{c[$1]++} END {for (k in c) print c[k], k}' access.log | sort -rn | head
```

`c[$1]++` usa el primer campo como clave y suma 1. Al final (`END`) recorre las claves. Equivale a `awk '{print $1}' | sort | uniq -c`.

### Medir longitud (útil para detectar datos codificados)

```bash
awk '{print length($1), $1}' fichero | sort -rn | head
```

Nombres legítimos suelen ser cortos y repetidos. Cadenas largas, únicas y de aspecto aleatorio (base32/base64/hex) indican que alguien está metiendo datos dentro.

## 7. Columnas de los formatos que verás en los labs

### /etc/passwd

```
root:x:0:0:root:/root:/bin/bash
 1   2 3 4  5     6      7
```

1 usuario · 2 contraseña (`x` = está en /etc/shadow) · 3 **UID** · 4 GID · 5 descripción · 6 home · 7 shell. Ser root = **UID 0**, no llamarse root.

### auth.log (formato syslog clásico)

```
Oct 20 03:14:07 servidor sshd[2048]: Accepted publickey for analista from 192.0.2.10 port 51234 ssh2
 1   2     3       4         5          6        7      8     9       10      11      12   13   14
```

Las posiciones **cambian** según el mensaje (`Failed password for invalid user X from ...` tiene dos palabras más). Por eso para extraer la IP es más robusto `grep -oE 'from [0-9.]+'` que `awk '{print $11}'`.

### Salidas de herramientas (columnas separadas por espacios variables)

`ps`, `ss`, `df`, `ls -l`: usa `awk`, nunca `cut -d' '`. Con `ss` o `ps` añade el flag que quita la cabecera (`ss -H`, `ps --no-headers`) cuando vayas a procesar.

## 8. Ejercicios

Hazlos sobre ficheros reales de cualquier lab.

1. Lista los usuarios que tienen una shell de login real (`/bin/bash` o `/bin/sh`).
2. ¿Cuántas líneas de `/etc/ssh/sshd_config` son configuración activa (ni comentario ni vacía)?
3. De la salida de `ps -eo user,comm`, cuenta cuántos procesos tiene cada usuario.
4. Tienes un log donde el dominio consultado es el penúltimo campo. Escribe el pipeline que dé los 5 dominios base más consultados.

:::solucion Ver respuestas
1. `awk -F: '$7 ~ /(bash|sh)$/ {print $1}' /etc/passwd` (o `grep -E '(bash|sh)$' /etc/passwd | cut -d: -f1`).
2. `grep -cvE '^\s*(#|$)' /etc/ssh/sshd_config`
3. `ps --no-headers -eo user | sort | uniq -c | sort -rn`
4. `awk '{print $(NF-1)}' log | awk -F. '{print $(NF-1)"."$NF}' | sort | uniq -c | sort -rn | head -5`
:::

## Chuleta

```bash
grep -nE 'a|b' f; grep -v '^#' f; grep -rlF 'literal' /dir; grep -oE 'from [0-9.]+'
cut -d: -f1,3 /etc/passwd
awk -F: '$3==0 {print $1}' /etc/passwd
awk '{print $NF}'; awk '{print $(NF-1)}'; awk -F. '{print $(NF-1)"."$NF}'
... | sort | uniq -c | sort -rn | head
tr '\0' '\n' < /proc/PID/cmdline
```
