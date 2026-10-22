# Resolución guiada · Lab 79

:::piensa Antes de tocar nada
Un pico de peticiones no es, por sí solo, un ataque. Un lanzamiento, un enlace viral, tu propio health check o un crawler también disparan el volumen. Si bloqueas "al que más pide", puedes estar baneando a tu monitorización o a Google. El triage separa **volumen** de **malicia**.
:::

## Paso 1 · Mira el top de IPs (y desconfía de él)

**Pregúntate:** ¿quién pide más? ¿Y eso lo hace malo?

```bash
awk '{print $1}' /var/log/apache2/access.log | sort | uniq -c | sort -rn | head
```

Verás `10.0.0.50` arriba del todo: son 400 peticiones a `/health`. Es el health check. Alto volumen, cero malicia.

## Paso 2 · Agrupa por red /24

**Pregúntate:** ¿el volumen viene de una IP o repartido entre muchas de la misma red?

```bash
awk '{print $1}' /var/log/apache2/access.log | cut -d. -f1-3 | sort | uniq -c | sort -rn | head
```

`203.0.113` y `198.51.100` suman muchísimo repartido entre decenas de hosts: es la firma de un **flood distribuido**.

## Paso 3 · Busca la evidencia de malicia

**Pregúntate:** ¿qué distingue a esas peticiones de un usuario real?

```bash
grep '^203.0.113.' /var/log/apache2/access.log | head
```

- Misma ruta cara: `/buscar?q=%%%&sort=precio`.
- Mismo User-Agent de script: `python-requests/2.31.0`.
- Sin `Referer` (`"-"`).
- Muchos `503` (el servidor ya sufre).

Compáralo con un legítimo:

```bash
grep '^66.249.66.1 ' /var/log/apache2/access.log | head   # Googlebot: rutas reales, UA declarado
grep '^192.0.2.'     /var/log/apache2/access.log | head   # usuarios: rutas variadas, con Referer
```

## Paso 4 · Escribe el triage

:::pista Qué poner en triage.txt
```bash
cat > /home/analista/triage.txt <<'EOF'
Ataque: flood HTTP distribuido contra /buscar.
Rangos atacantes: 203.0.113.0/24 y 198.51.100.0/24.
Evidencia: decenas de IPs por /24, mismo UA python-requests, sin Referer,
misma ruta cara, muchos 503.
Falsos positivos a NO bloquear: 10.0.0.50 (health check interno) y
66.249.66.1 (Googlebot).
EOF
```
:::

## Paso 5 · Rellena la blocklist (sólo lo malo)

:::pista Cómo hacerlo
```bash
cat >> /etc/ddos/blocklist.txt <<'EOF'
203.0.113.0/24
198.51.100.0/24
EOF
```
:::

## Paso 6 · Verifica

```bash
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Nunca bloquees por volumen solo.** Correlaciona: ruta, User-Agent, Referer, código, geografía, ASN.
- **Lista blanca primero**: health checks, balanceadores, crawlers conocidos, oficinas (NAT corporativo = muchas peticiones de 1 IP, legítimas).
- Bloquear por **/24 o ASN** es más efectivo que IP a IP contra un flood distribuido, pero más peligroso: revisa que no haya legítimos dentro.
- Esta blocklist es la **entrada** para los labs siguientes: la aplicarás en iptables (lab 84), en el reverse proxy (lab 83) o en el WAF (lab 82).
