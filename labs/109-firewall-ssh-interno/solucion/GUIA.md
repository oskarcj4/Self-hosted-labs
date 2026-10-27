# Resolución guiada · Lab 109 (vía BLUE)

:::piensa
Solo doy el blindaje (blue). La vía red (cómo saltarlo) es tuya; el servidor
valida las banderas que entregues.
:::

## Qué está mal

`/srv/fw/rules.sh` dice bloquear 22 y 8080 y dejar solo 80, pero dos errores lo
dejan saltar:

```sh
# BUG 1
iptables -P INPUT ACCEPT
...
# BUG 2
iptables -A INPUT -p udp --dport 22 -j DROP
```

- **BUG 1 — política por defecto permisiva.** `INPUT ACCEPT` convierte el
  firewall en lista negra: entra todo lo que no tenga un `DROP` explícito que
  coincida. Un olvido o una regla que falle = puerto expuesto.
- **BUG 2 — protocolo equivocado.** La regla que "cierra" el 22 es `-p udp`,
  pero SSH es **TCP**. Nunca coincide con un paquete TCP a 22. Con la política
  en `ACCEPT`, el `22/tcp` queda abierto. El atacante entra por SSH y, ya
  dentro, llega por `localhost` a la consola admin del `8080` (que sin salir
  del nodo no está filtrada y no pide clave) → bandera root.

## El arreglo

Dale la vuelta: lista blanca. Política `DROP` y un solo `ACCEPT` para el 80.
El 22 y el 8080 quedan bloqueados por defecto, sin reglas frágiles.

```sh
iptables -P INPUT DROP
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
```

Aplica y comprueba:

```bash
fw-reload
bash /opt/lab/check.sh
```

## Principios de firewall que deja el lab

- **Lista blanca.** Política `DROP` y abre solo lo necesario. Enumerar lo que
  prohíbes deja huecos; enumerar lo que permites, no.
- **Una regla debe coincidir con el tráfico que bloquea.** Protocolo y sentido
  correctos, o no protege. Prueba simulando el paquete del atacante.
- **Defensa en capas.** El firewall no sustituye a atar el servicio a
  `127.0.0.1` ni a pedir autenticación: la consola del 8080 se fiaba de que
  "solo se alcanza desde dentro", y el SSH es justo la forma de entrar.
