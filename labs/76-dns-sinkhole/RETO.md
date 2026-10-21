# Sinkhole DNS (estilo Pi-hole)

> Operaciones · dnsmasq · threat intel · logs de DNS · respuesta a incidentes

## Escenario

El proveedor avisa: desde la oficina salen consultas DNS a dominios de una
botnet. Todos los puestos usan `dns-01` (este servidor, dnsmasq) como DNS,
así que la pista está aquí... si alguien la registrara. Lee
`~/ticket/SEC-7610.txt`.

| Máquina   | IP                | Papel                         |
|-----------|-------------------|-------------------------------|
| `dns-01`  | 10.76.76.53       | esta terminal                 |
| proveedor | 10.76.76.2        | DNS de "Internet"             |
| puestos   | 10.76.76.21–23    | PCs de la oficina             |

## Objetivos

1. dnsmasq **registra** cada consulta (quién pregunta qué).
2. **Sinkhole**: los dominios de `/srv/threat-intel/feed-2026-10-20.txt`,
   **y sus subdominios**, responden `0.0.0.0` (o NXDOMAIN). Ojo con el
   formato del feed: es un fichero real, con sus manías.
3. La **allowlist** (`/srv/threat-intel/allowlist.txt`) sigue resolviendo.
4. `~/infectado.txt` con la IP del puesto infectado (una IP por línea).
5. Todo persiste tras `systemctl restart dnsmasq`.

## Comandos que te pueden servir

```bash
ls /etc/dnsmasq.d/ ; cat /etc/dnsmasq.d/*.conf
less /srv/threat-intel/feed-2026-10-20.txt
cat -A /srv/threat-intel/feed-2026-10-20.txt | head -20    # caracteres ocultos
man dnsmasq            # log-queries, log-facility, address=/dominio/IP
sudo dnsmasq --test
sudo systemctl restart dnsmasq
dig @127.0.0.1 www.periodico.example +short
sudo tail -f /var/log/dnsmasq.log
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
