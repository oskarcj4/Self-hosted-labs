# Solución — Sinkhole DNS (estilo Pi-hole)

## 1. Registrar las consultas

```bash
sudo tee /etc/dnsmasq.d/20-log.conf <<'EOF'
log-queries
log-facility=/var/log/dnsmasq.log
EOF
sudo dnsmasq --test && sudo systemctl restart dnsmasq
sudo tail -f /var/log/dnsmasq.log
# ... query[A] 3fa9c1d2.cdn-telemetria.xyz from 10.76.76.22
# ... forwarded 3fa9c1d2.cdn-telemetria.xyz to 10.76.76.2
```

Sin log no hay forma de saber qué puesto pregunta por el C2: todos salen a
Internet con la misma IP pública. El DNS interno es el **único** sitio donde
se ve la IP privada de cada puesto.

## 2. Limpiar el feed

```bash
cat -A /srv/threat-intel/feed-2026-10-20.txt | head -20
```

Manías del feed:

- Líneas con `\r` al final (`^M`), de un editor de Windows.
- Comentarios, también al final de la línea (`# botnet`).
- Dos formatos de IP: `0.0.0.0` y `127.0.0.1`.
- Mayúsculas y duplicados.
- `127.0.0.1 localhost`, `::1 localhost` y `0.0.0.0 0.0.0.0`: cabecera
  típica de los ficheros hosts. **No** son dominios maliciosos.
- `analytics.proveedor.example`, que la allowlist marca como falso positivo.

```bash
tr -d '\r' < /srv/threat-intel/feed-2026-10-20.txt \
  | sed 's/#.*//' \
  | awk 'NF >= 2 {print tolower($2)}' \
  | grep -vxE 'localhost|0\.0\.0\.0' \
  | grep -vxFf <(grep -v '^#' /srv/threat-intel/allowlist.txt | grep .) \
  | sort -u > /tmp/bloquear.txt
wc -l /tmp/bloquear.txt          # 162
```

dnsmasq perdona el `\r` y las mayúsculas, pero el resto de herramientas no:
`grep -x` contra la allowlist no casa `dominio\r` con `dominio`, y `sort -u`
deja duplicados. Normaliza **antes** de filtrar. Si cargas el feed tal cual,
bloqueas `localhost` y el falso positivo de la allowlist.

## 3. El sinkhole

```bash
sed 's|.*|address=/&/0.0.0.0|' /tmp/bloquear.txt | sudo tee /etc/dnsmasq.d/50-blocklist.conf >/dev/null
sudo dnsmasq --test && sudo systemctl restart dnsmasq
dig @127.0.0.1 +short panel.malsrv.top              # 0.0.0.0
dig @127.0.0.1 +short abc.cdn-telemetria.xyz        # 0.0.0.0 (subdominio)
dig @127.0.0.1 +short analytics.proveedor.example   # 203.0.113.10 (allowlist)
```

`address=/dominio/0.0.0.0` cubre el dominio **y todos sus subdominios**. Por
eso funciona contra el malware que genera subdominios aleatorios
(`3fa9c1d2.cdn-telemetria.xyz`): un `/etc/hosts` no podría, porque sólo
admite nombres exactos. Con `address=/dominio/` (sin IP) la respuesta es
NXDOMAIN.

## 4. ¿Quién es?

```bash
awk '/query\[/ && $NF != "127.0.0.1" {print $(NF-2), $NF}' /var/log/dnsmasq.log | sort -u \
  | while read -r d ip; do
      [ "$(dig +short @127.0.0.1 "$d" | tail -1)" = 0.0.0.0 ] && echo "$ip $d"
    done | sort -u
# 10.76.76.22 3fa9c1d2.cdn-telemetria.xyz
# 10.76.76.22 panel.malsrv.top
echo 10.76.76.22 > ~/infectado.txt
```

Trampas:

- `10.76.76.21` también pregunta por `analytics.proveedor.example`, que está
  en el feed. Pero es un falso positivo confirmado: no está infectado.
- `127.0.0.1` eres tú haciendo pruebas con `dig`.

## Lecciones

- El sinkhole **contiene**, no **cura**: pc-02 sigue infectado. Hay que
  aislarlo y analizarlo. Lo que sí consigue es cortar el canal de mando y
  avisar de que existe.
- Los feeds de threat intel hay que **normalizarlos**; nunca los cargues tal
  cual.
- Toda lista de bloqueo necesita una allowlist con dueño: un falso positivo
  en el DNS rompe el negocio.
- El malware puede saltarse tu DNS (DoH, DNS directo a 8.8.8.8). Bloquea el
  53 saliente salvo desde dns-01 (lab 18) y vigila el DoH.
