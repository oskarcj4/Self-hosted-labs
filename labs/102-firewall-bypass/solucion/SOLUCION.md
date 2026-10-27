# Solución — Firewall que se puede saltar (vía BLUE)

> Solo el blindaje. La explotación (RED) la resuelves tú.

## Causa

Política `INPUT DROP` correcta, pero dos reglas la vacían:

1. **`--sport 53 -j ACCEPT`** — filtrar por puerto de origen no sirve de
   control: el emisor elige su puerto de origen. Es el error clásico de
   "abrir para que vuelva el DNS", cuando el retorno ya lo cubre el estado
   `ESTABLISHED,RELATED`.
2. **`--dport 9002 -j ACCEPT` antes de `--dport 9002 -j DROP`** — iptables
   usa la primera coincidencia; el ACCEPT gana y el DROP nunca se evalúa.

## Arreglo

Eliminar ambas reglas. El conjunto correcto es lista blanca + estado:

```sh
iptables -P INPUT DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 9001 -j DROP
iptables -A INPUT -p tcp --dport 9002 -j DROP
```

(Los dos `DROP` finales son redundantes con la política por defecto, pero
documentan la intención; puedes dejarlos o quitarlos.)

## Más allá del lab

- **nftables / firewalld**: el mismo principio. Evita `ct state` abierto por
  puerto de origen; usa `ct state established,related accept`.
- **Defensa en capas**: el firewall de red no sustituye a que el servicio no
  escuche en `0.0.0.0` si solo lo necesita localhost (`bind 127.0.0.1`).
- **Orden y por defecto**: política `drop`, reglas específicas primero,
  revisadas en CI contra un conjunto de paquetes de prueba (como hace el
  validador de este lab).

## Lecciones

- El puerto de origen no autentica nada.
- En iptables, el orden es la lógica: primera coincidencia manda.
- Prueba el firewall simulando el paquete del atacante, no solo leyéndolo.
