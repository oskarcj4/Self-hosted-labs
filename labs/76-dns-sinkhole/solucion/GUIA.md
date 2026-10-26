# Resolución guiada · Sinkhole DNS (estilo Pi-hole)

:::piensa Antes de tocar nada
dnsmasq en `dns-01` es el **único** sitio donde se ve la IP privada de cada
puesto (todos salen a Internet con la misma IP pública). Cuatro piezas:
registrar consultas, limpiar el feed (tiene manías de fichero real), montar el
sinkhole que cubra subdominios, y leer el log para hallar el puesto infectado.
Cuidado con dos falsos positivos: la allowlist y tus propias pruebas con `dig`
(127.0.0.1).
:::

## Paso 1 · Registrar las consultas

:::pista `/etc/dnsmasq.d/20-log.conf`
```bash
sudo tee /etc/dnsmasq.d/20-log.conf <<'EOF'
log-queries
log-facility=/var/log/dnsmasq.log
EOF
sudo dnsmasq --test && sudo systemctl restart dnsmasq
sudo tail -f /var/log/dnsmasq.log
# query[A] 3fa9c1d2.cdn-telemetria.xyz from 10.76.76.22
```
Sin log no se puede saber **qué puesto** pregunta por el C2.
:::

## Paso 2 · Limpiar el feed (antes de filtrar)

**Pregúntate:** ¿qué manías tiene el fichero? `cat -A` las enseña.

:::pista Normalización
```bash
cat -A /srv/threat-intel/feed-2026-10-20.txt | head
# \r (^M) de Windows, comentarios al final (# botnet), IPs 0.0.0.0 y 127.0.0.1,
# mayúsculas, duplicados, cabecera hosts (localhost, 0.0.0.0 0.0.0.0)
tr -d '\r' < /srv/threat-intel/feed-2026-10-20.txt \
  | sed 's/#.*//' \
  | awk 'NF >= 2 {print tolower($2)}' \
  | grep -vxE 'localhost|0\.0\.0\.0' \
  | grep -vxFf <(grep -v '^#' /srv/threat-intel/allowlist.txt | grep .) \
  | sort -u > /tmp/bloquear.txt
wc -l /tmp/bloquear.txt
```
dnsmasq perdona `\r` y mayúsculas, pero `grep -x`/`sort -u` **no**: normaliza
primero o bloquearás `localhost` y el falso positivo de la allowlist.
:::

## Paso 3 · El sinkhole (cubre subdominios)

**Pregúntate:** el malware inventa subdominios aleatorios. ¿Cómo los cubro?

:::pista Cómo hacerlo
```bash
sed 's|.*|address=/&/0.0.0.0|' /tmp/bloquear.txt | sudo tee /etc/dnsmasq.d/50-blocklist.conf >/dev/null
sudo dnsmasq --test && sudo systemctl restart dnsmasq
dig @127.0.0.1 +short panel.malsrv.top              # 0.0.0.0
dig @127.0.0.1 +short abc.cdn-telemetria.xyz        # 0.0.0.0 (subdominio)
dig @127.0.0.1 +short analytics.proveedor.example   # resuelve (allowlist)
```
`address=/dominio/0.0.0.0` cubre el dominio **y todos sus subdominios** — un
`/etc/hosts` no podría (sólo nombres exactos). Sin IP → NXDOMAIN.
:::

## Paso 4 · ¿Quién es? (`~/infectado.txt`)

:::pista Cómo hallarlo
```bash
awk '/query\[/ && $NF != "127.0.0.1" {print $(NF-2), $NF}' /var/log/dnsmasq.log | sort -u \
  | while read -r d ip; do
      [ "$(dig +short @127.0.0.1 "$d" | tail -1)" = 0.0.0.0 ] && echo "$ip $d"
    done | sort -u
echo 10.76.76.22 > ~/infectado.txt
```
Trampas: `10.76.76.21` pregunta por `analytics.proveedor.example` (falso
positivo de la allowlist, no infectado); `127.0.0.1` eres tú con `dig`.
:::

## Verifica

```bash
cat ~/infectado.txt
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **El sinkhole contiene, no cura**: el puesto sigue infectado; aíslalo y
  analízalo. Lo que logra es cortar el C2 y delatarlo.
- **Normaliza los feeds** de threat intel; nunca los cargues tal cual.
- **Toda blocklist necesita allowlist con dueño**: un falso positivo en DNS
  rompe el negocio.
- **El malware puede evadir tu DNS** (DoH, DNS directo): bloquea el 53 saliente
  salvo desde dns-01 (lab 18) y vigila el DoH.

## Si te atascas

- Bloqueaste `localhost` o la allowlist → cargaste el feed sin normalizar.
- Los subdominios aleatorios siguen resolviendo → usa `address=/dom/`, no
  `/etc/hosts`.
- `infectado.txt` falla → metiste 10.76.76.21 (falso positivo) o 127.0.0.1.
