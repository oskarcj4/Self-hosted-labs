# 14 · DDoS: defensa en profundidad (de cero a experto)

> Qué es un DoS y un DDoS, por qué la D de "distribuido" lo cambia todo, en qué capa ataca cada variante, cómo distinguir un flood malicioso del tráfico legítimo de alto volumen, y cómo mitigar por capas: kernel, firewall, Apache, WAF, reverse proxy y CDN. Acompaña a los labs 79–84.

## 1. Qué es (y qué no es) un DoS

**DoS** (Denial of Service) es cualquier maniobra que deja un servicio **sin
capacidad de atender a sus usuarios legítimos**. No roba datos: niega el acceso.
Se gana agotando un recurso finito: ancho de banda, CPU, memoria, workers del
servidor, entradas en una tabla de conexiones, descriptores de fichero…

**DDoS** (Distributed DoS) es un DoS lanzado desde **muchos orígenes a la vez**
—normalmente una **botnet** de equipos comprometidos (recuerda Mirai: cámaras y
routers con credenciales de fábrica)—. La D cambia tres cosas:

1. **No puedes bloquear una IP y listo**: son miles, repartidas por el mundo.
2. **El volumen agregado** puede superar tu ancho de banda de entrada: entonces
   ya no hay config local que te salve, el tráfico satura el cable antes.
3. **Se mezcla con el tráfico real**: distinguir es el problema central.

> Un pico de tráfico **no es** por sí solo un ataque. Un lanzamiento, un enlace
> viral, tu health check o un crawler también lo disparan. Confundir volumen con
> malicia y bloquear a lo bruto es autoinfligirse el DoS (lab 79).

## 2. En qué capa ataca: el mapa

Los DDoS se clasifican por la capa del modelo OSI que saturan. La defensa cambia
radicalmente según la capa.

| Tipo | Capa | Ejemplo | Qué agota | Dónde se mitiga |
|---|---|---|---|---|
| **Volumétrico** | 3/4 | UDP flood, amplificación DNS/NTP | Ancho de banda | Upstream / CDN / scrubbing |
| **De protocolo** | 3/4 | SYN flood, ACK flood, Ping of Death | Tabla de conexiones, CPU de red | Kernel (syncookies), firewall |
| **De aplicación** | 7 | HTTP flood, Slowloris, abuso de endpoint caro | Workers, CPU, BD | Apache, WAF, reverse proxy |

- **Volumétrico**: fuerza bruta de tráfico. Amplificación = el atacante manda una
  petición pequeña con tu IP falseada a un servidor que responde enorme (DNS,
  NTP, memcached); la respuesta cae sobre ti multiplicada ×50-×50000. **No se
  mitiga en tu servidor**: cuando el tráfico llega, ya saturó tu línea. Se para
  *aguas arriba* (operador, CDN, servicio de scrubbing).
- **De protocolo**: abusa de cómo funciona TCP/IP. El clásico **SYN flood**:
  abrir medio-handshakes y no completarlos, llenando la cola de conexiones.
- **De aplicación (capa 7)**: lo más barato para el atacante y lo más difícil de
  distinguir, porque *son peticiones HTTP válidas*. Aquí viven la mayoría de los
  labs.

## 3. Anatomía de un ataque de capa 7

### HTTP flood
Muchas peticiones por segundo a una ruta, idealmente **cara** (una búsqueda, un
endpoint que pega a la base de datos, una página sin caché). Pocas peticiones por
IP pero multiplicadas por miles de bots.

### Slowloris (slow-DoS) — lab 81
Lo contrario al flood: **pocas** conexiones, pero mantenidas abiertas enviando
las cabeceras HTTP **gota a gota**, sin terminarlas nunca. Cada conexión ocupa un
worker esperando. Con unos cientos de conexiones y casi sin ancho de banda,
agota todos los workers de Apache. Variantes: *slow POST* (cuerpo lento), *slow
read* (lee la respuesta lentísimo).

### Abuso de endpoint caro
Ni flood ni slow: peticiones a ritmo "normal" pero a la ruta que más duele (login
con hash costoso, exportación de informes, búsqueda sin índice). Pocas peticiones
tumban la BD.

## 4. El problema central: distinguir malicioso de legítimo

No hay una señal única. Se **correlacionan** varias. Firma típica de un flood
distribuido frente a usuarios reales:

| Señal | Flood malicioso | Tráfico legítimo |
|---|---|---|
| **Ruta** | La misma, repetida, cara | Variada, navegación natural |
| **User-Agent** | Igual para todos, de script (`python-requests`, `curl`) o falso | Diverso, navegadores reales |
| **Referer** | Ausente (`"-"`) | Presente en navegación interna |
| **Distribución IP** | Muchas IPs de pocos /24 o un ASN | Dispersa y orgánica |
| **Ritmo** | Constante, robótico, 24/7 | Sigue el horario humano |
| **Códigos** | Pico de 5xx / 429 | Mayoría 200/304 |
| **Cookies/sesión** | Sin sesión, sin JS | Con sesión, cargan estáticos |

**Trampas (falsos positivos a NO bloquear):**
- **Health checks y balanceadores**: muchísimas peticiones desde una IP interna.
  Legítimo. Bloquearlos = te quedas sin monitorización.
- **Crawlers** (Googlebot, Bingbot): verifícalos por DNS inverso, no por el
  User-Agent (que se falsea).
- **NAT corporativo**: una oficina entera sale por una IP → muchas peticiones
  legítimas de una sola IP.
- **CDN**: si tienes CDN delante, **todo** el tráfico llega con la IP de la CDN;
  limita por la IP real de `X-Forwarded-For`, no por la del borde.

Herramientas de triage (lab 79):

```bash
# top de IPs (¡el top no implica malicia!)
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head
# agrupar por /24 (delata lo distribuido)
awk '{print $1}' access.log | cut -d. -f1-3 | sort | uniq -c | sort -rn | head
# tasa por minuto
awk -F'[:[]' '{print $2":"$3":"$4}' access.log | sort | uniq -c
# User-Agents dominantes
awk -F'"' '{print $6}' access.log | sort | uniq -c | sort -rn | head
```

## 5. Defensa en profundidad: capa por capa

Ninguna medida sola basta. Se apilan, de fuera hacia dentro:

```
 Internet
    │
 [ CDN / scrubbing ]   ← volumétrico (cap.3/4): absorbe lejos del origen
    │
 [ Firewall / kernel ] ← protocolo (cap.3/4): syncookies, rate limit, blocklist
    │
 [ Reverse proxy ]     ← cap.7: limit_req por IP, buffering (anti-Slowloris)   · lab 83
    │
 [ WAF (ModSecurity) ] ← cap.7: patrones de ataque, abuso de endpoints          · lab 82
    │
 [ Apache endurecido ] ← cap.7: reqtimeout, Timeout/KeepAlive, mod_evasive      · labs 80/81
    │
 [ Aplicación ]        ← caché, colas, límites por cuenta, captcha
```

### Capa 3/4 — kernel y firewall

**SYN flood** → cookies SYN (el kernel no guarda estado del half-open):
```bash
sudo sysctl -w net.ipv4.tcp_syncookies=1
sudo sysctl -w net.ipv4.tcp_max_syn_backlog=2048
```

**Rate limit de conexiones nuevas** con iptables (lab 84):
```bash
sudo iptables -A INPUT -p tcp --dport 80 -m conntrack --ctstate NEW \
  -m hashlimit --hashlimit-above 25/sec --hashlimit-burst 50 \
  --hashlimit-mode srcip --hashlimit-name http -j DROP
```

**Límite de conexiones simultáneas por IP** (contra Slowloris a nivel red):
```bash
sudo iptables -A INPUT -p tcp --dport 80 -m connlimit --connlimit-above 50 -j REJECT
```

**Blocklist de rangos/ASN** confirmados en el triage:
```bash
sudo iptables -I INPUT -s 203.0.113.0/24 -j DROP
```
> El bloqueo por IP individual pierde contra una botnet distribuida. Agrupa por
> **/24 o ASN**, pero revisa que no arrastres legítimos.

### Capa 7 — Apache (labs 80/81)

```apache
Timeout 30
KeepAliveTimeout 5
RequestReadTimeout header=20-40,MinRate=500 body=20,MinRate=500   # mod_reqtimeout
# mod_evasive: banea a quien repite
DOSPageCount 5
DOSSiteCount 100
DOSBlockingPeriod 60
```

### Capa 7 — reverse proxy (lab 83)

```nginx
limit_req_zone $binary_remote_addr zone=web:10m rate=10r/s;   # http {}
location / { limit_req zone=web burst=20 nodelay; proxy_pass http://backend; }
```
nginx además **bufferiza** la petición completa antes de pasarla, así que las
conexiones lentas (Slowloris) las aguanta el proxy, no los workers de Apache.

### Capa 7 — WAF (lab 82)

ModSecurity + OWASP CRS inspecciona cada petición y bloquea inyección, XSS,
scanners y —con las reglas opcionales 912xxx— abuso de tasa por IP a nivel de
aplicación.

## 6. ¿Y Cloudflare "gratis"?

Cloudflare (y Fastly, Akamai…) es una **CDN/WAF alojada**, no un contenedor. Su
plan gratuito sí da protección DDoS de capa 3/4 "ilimitada" y un WAF básico. El
modelo:

1. Apuntas el **DNS** de tu dominio a Cloudflare (cambias los nameservers).
2. El tráfico entra por su **borde distribuido**, que absorbe el flood
   volumétrico *lejos de tu origen* y sólo te reenvía lo limpio.
3. Ocultas la IP real de tu servidor (y la proteges con firewall para que sólo
   acepte tráfico del rango de Cloudflare).

Por eso **no se "instala en un contenedor"**: su valor es estar *fuera*,
distribuido, con más ancho de banda que cualquier atacante. Lo que **sí** montas
y controlas en local es el **equivalente conceptual** —un reverse proxy con rate
limiting (lab 83)—, que cubre la capa 7 pero **no** te salva de un volumétrico
que ya saturó tu línea. CDN local y reverse proxy no compiten: se complementan.

Alternativas open-source del mismo patrón: **HAProxy** (`stick-table` para rate
limit), **Traefik** (middleware), **crowdsec** (blocklist colaborativa),
**Anubis** (prueba de trabajo anti-bot).

## 7. Durante el incidente: el runbook (lab 84)

1. **Detecta**: alerta por tasa de 5xx, latencia, saturación de workers.
2. **Triage**: ¿capa 3/4 o 7? ¿distribuido? ¿qué ruta? ¿se distingue del tráfico
   real? (sección 4)
3. **Comunica**: status page, avisa a stakeholders. Un incidente silencioso
   erosiona más la confianza que el propio corte.
4. **Mitiga por capas**: empieza por lo más barato y reversible (rate limit,
   bloqueo de /24), escala hacia arriba (CDN "under attack mode") si no basta.
5. **Estabiliza y observa**: confirma que los legítimos vuelven a pasar.
6. **Postmortem** *blameless*: impacto, cronología, mitigación, prevención con
   dueño y fecha. Sin culpables; con acciones.

> Regla de oro: **mide antes y después**. Mitigar sin medir es fe, no ingeniería.
> El mismo `ab`/probador que simula el ataque te sirve para verificar que la
> defensa funciona (todo en local, inofensivo).

## 8. Errores caros

- Bloquear "al que más pide" sin mirar: era el health check.
- Rate limit tan bajo que mata a usuarios reales (móviles, NAT de oficina).
- `Timeout` tan corto que corta subidas legítimas de ficheros grandes.
- Olvidar persistir las reglas de iptables (desaparecen al reiniciar).
- Olvidar **IPv6** (`ip6tables`): un firewall sólo IPv4 deja la puerta de atrás.
- Confiar en el User-Agent para "verificar" un crawler (se falsea; usa DNS
  inverso).
- Tratar un volumétrico con config local: cuando el paquete llega, ya es tarde.

## 9. Práctica

| Lab | Qué practica |
|---|---|
| **79** | Triage: distinguir flood malicioso de alto volumen legítimo |
| **80** | Endurecer Apache (reqtimeout, Timeout/KeepAlive, mod_evasive) |
| **81** | Mitigar Slowloris con mod_reqtimeout |
| **82** | WAF: ModSecurity + OWASP CRS en modo bloqueo |
| **83** | Reverse proxy con rate limiting (nginx) — equivalente local a una CDN |
| **84** | Respuesta a incidentes: mitigación duradera + postmortem |

> Todo el tráfico de estos labs es local e inofensivo: generas las peticiones
> contra tu propio contenedor con `ab` o el probador incluido, nunca contra
> terceros. Estás en el lado azul: aprender a atacar tu propio servicio es la
> única forma honesta de comprobar que lo defiendes.
