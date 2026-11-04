# Rollback en menos de 2 minutos

> DevOps · blue/green · HAProxy · health checks · runtime API

## Escenario

Hace 7 minutos salió `shop 1.5.0` al slot **green**. El checkout devuelve
**500** y HAProxy sigue mandando todo el tráfico a green, porque su health
check dice que está sano (`~/ticket/INC-141.txt`). El acuerdo de servicio
es volver a la versión buena (**blue**, 1.4.0) en **menos de 2 minutos**.

- **Blue/green**: dos versiones vivas a la vez; el balanceador decide cuál
  recibe tráfico. El rollback es mover el tráfico, no redesplegar.
- **Health check**: si comprueba `/` (una página estática), una app con la
  base de datos rota parece sana. Debe comprobar lo que de verdad importa.
- **Runtime API**: HAProxy acepta órdenes por su socket (`set server ...
  state maint`) sin recargar ni cortar conexiones. Sólo con `level admin`.

## Objetivos

1. Confirma qué versión responde y qué falla (cabecera `X-App-Version`).
2. Vuelve a blue **sin reiniciar** HAProxy (`systemctl reload` sí vale;
   `restart` no).
3. Cambia el health check a `/health` para que un green roto salga solo.
4. Escribe `~/rollback.sh`: deja green en mantenimiento y blue sirviendo,
   por el socket. Debe poder ejecutarse varias veces y tardar < 2 min.
5. Anota `version_mala=` y `version_buena=` en `~/incidente.txt`.

## Comandos que te pueden servir

```bash
curl -si http://127.0.0.1/api/checkout | head -5
echo "show servers state shop" | sudo socat stdio /run/haproxy/admin.sock
echo "show stat" | sudo socat stdio /run/haproxy/admin.sock | cut -d, -f1,2,18 | column -ts,
echo "set server shop/green state maint" | sudo socat stdio /run/haproxy/admin.sock
sudo nano /etc/haproxy/haproxy.cfg
sudo haproxy -c -f /etc/haproxy/haproxy.cfg && sudo systemctl reload haproxy
```

> El primer rollback se hace a mano por el socket; el segundo, con el
> script. Un runbook que nadie ejecutó nunca no es un runbook.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
