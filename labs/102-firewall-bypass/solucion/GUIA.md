# Resolución guiada · Lab 102 (vía BLUE)

:::piensa
Solo doy el blindaje (blue). La vía red (cómo saltarlo) es tuya; el servidor
valida las banderas que entregues.
:::

## Qué está mal

`/srv/fw/rules.sh` tiene política `INPUT DROP` (bien), pero dos reglas la abren:

```sh
# BUG 1
iptables -A INPUT -p tcp --sport 53 -j ACCEPT
# BUG 2
iptables -A INPUT -p tcp --dport 9002 -j ACCEPT
iptables -A INPUT -p tcp --dport 9002 -j DROP
```

- **BUG 1 — confiar en el puerto de origen.** El puerto de origen lo elige
  quien envía. Aceptar todo lo que venga con `--sport 53` deja entrar a
  cualquiera que fije ese puerto de origen. Las respuestas DNS legítimas ya
  entran por la regla de estado `ESTABLISHED,RELATED`, así que esta regla
  sobra entera.
- **BUG 2 — orden de reglas.** iptables evalúa de arriba a abajo y aplica la
  primera que coincide. El `ACCEPT` de "depuración" está **antes** del `DROP`,
  así que gana el ACCEPT y el `9002` queda abierto.

## El arreglo

Borra ambas reglas. Deja solo:

```sh
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -p tcp --dport 9001 -j DROP
iptables -A INPUT -p tcp --dport 9002 -j DROP
```

Aplica y comprueba:

```bash
fw-reload
bash /opt/lab/check.sh
```

## Principios de firewall que deja el lab

- Filtra por **estado**, no por puerto de origen. `ESTABLISHED,RELATED`
  resuelve el retorno de conexiones salientes sin abrir nada entrante.
- El **orden importa**: un `ACCEPT` ancho delante de un `DROP` anula el `DROP`.
  Pon las excepciones estrictas y antes que lo general.
- Política por defecto `DROP` y abre solo lo necesario (lista blanca).
