# Solución — Lab 08

## 1. Auditar las reglas

```bash
sudo iptables -S INPUT
```

Verás:

```
-A INPUT -i lo -j ACCEPT
-A INPUT -p tcp --dport 80 -j ACCEPT
-A INPUT -p tcp --dport 9000 -j ACCEPT   <-- panel interno expuesto a todos
```

Compruébalo:

```bash
curl -s localhost:9000   # responde: el panel interno es accesible
```

## 2 y 3. Quitar la regla mala y bloquear 9000

```bash
sudo iptables -D INPUT -p tcp --dport 9000 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 9000 -j DROP
```

(Como `lo` ya está aceptado antes, la máquina sigue pudiendo hablar consigo
misma en 9000; los orígenes externos reciben DROP.)

## 4. Verificar que 80 sigue abierto

```bash
sudo iptables -S INPUT
bash /opt/lab/check.sh
```

## Lecciones

- Segmentar = cada servicio accesible sólo desde donde debe. El panel interno
  nunca debió aceptar tráfico que no fuera de loopback / red de administración.
- En Target y en el casino, un sistema trivial (HVAC, termómetro) alcanzó la red
  interna por falta de segmentación. El firewall es la frontera.
- En producción, define política por defecto `DROP` y abre sólo lo necesario.
