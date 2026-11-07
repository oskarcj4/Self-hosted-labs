# Verde, pero fallando

> SRE · diagnóstico · pool de conexiones · CPU throttling · DNS · health checks honestos

## Escenario

El monitor del equipo (`monitor-verde`) dice **VERDE**: `/health` responde 200.
Pero soporte tiene quejas: `/comprar` tarda segundos y a veces devuelve
`503 pool agotado`.

Hay **tres causas** a la vez, en tres capas distintas:

- la aplicación (`~/tienda/app.py`),
- su unidad systemd (`/etc/systemd/system/tienda.service`),
- la resolución de nombres del sistema.

Ninguna tumba el servicio; juntas lo hacen inservible. `/health` no mira
ninguna de ellas.

## Objetivos

1. `~/causas.txt`: una línea por causa (qué es y cómo la viste).
2. El pool no pierde conexiones (ni con pagos rechazados).
3. La tienda no está estrangulada de CPU.
4. `pagos.interno` resuelve al instante.
5. Resultado: 30 compras con 5 en paralelo, todas 200 y p95 < 0.5 s.

## Pistas

```bash
curl -s -w ' %{http_code} %{time_total}s\n' 'localhost:8080/comprar'
curl -s localhost:8080/pool                        # conexiones en uso
time getent hosts pagos.interno
cat /etc/resolv.conf
systemctl show tienda -p CPUQuotaPerSecUSec
cat /sys/fs/cgroup/system.slice/tienda.service/cpu.stat   # nr_throttled
sudo strace -f -tt -e trace=connect,sendto,recvfrom -p "$(systemctl show -p MainPID --value tienda)"
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
