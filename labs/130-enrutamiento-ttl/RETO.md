# Enrutamiento y TTL: el router que no enruta

> Redes · ip route · ip_forward · traceroute · TTL

## Escenario

Eres `router-130`, el router de la oficina. Los PCs (10.130.1.0/24) no
llegan al servidor `srv-dmz` (10.130.3.30), que está detrás de otro router,
`r2-dmz` (`~/ticket/NET-130.txt`).

```
pc-oficina ──► router-130 (tú) ──► r2-dmz ──► srv-dmz
10.130.1.20    .1.254 | .2.254     .2.253 | .3.253   10.130.3.30
```

Para que un equipo Linux haga de router hacen falta dos cosas:
reenviar paquetes que no son para él (`net.ipv4.ip_forward`) y saber por
dónde mandar cada red (tabla de rutas). Cada router que atraviesa un paquete
le resta 1 al **TTL**; por eso `traceroute` puede descubrir el camino y por
eso, mirando el TTL de una respuesta, sabes cuántos saltos hay.

## Objetivos

1. Haz que este equipo reenvíe paquetes, también tras reiniciar.
2. Añade la ruta que falta hacia la DMZ y guárdala para el arranque
   (`rutas-router.service` está preparado para ello).
3. Comprueba que `pc-oficina` ya llega: `/srv/estado/pc.txt` se actualiza
   cada 5 s.
4. Responde en `~/ttl.txt`: `ttl_respuesta=` (TTL de las respuestas de
   ping desde aquí a 10.130.3.30) y `saltos_pc=` (routers entre el PC y el
   servidor).

## Comandos que te pueden servir

```bash
ip -br addr ; ip route ; ip route get 10.130.3.30
sysctl net.ipv4.ip_forward ; grep -r ip_forward /etc/sysctl.conf /etc/sysctl.d/
sudo sysctl --system
sudo ip route add 10.130.3.0/24 via 10.130.2.253
systemctl cat rutas-router.service
ping -c 3 10.130.3.30 ; traceroute -n 10.130.3.30
sudo tcpdump -ni any icmp            # ¿entran del PC y no salen?
cat /srv/estado/pc.txt
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
