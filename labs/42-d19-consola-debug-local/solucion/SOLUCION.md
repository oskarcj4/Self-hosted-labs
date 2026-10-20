# Solución — Día 19: Consola de depuración sólo en local

## 1. Comprobar la exposición

```bash
cd ~/billing
docker port billing-api-1
# 5555/tcp -> 0.0.0.0:5555
# 5555/tcp -> [::]:5555
curl -s "http://$(hostname -i):5555/?eval=1+1"     # 2   <- RCE desde la red
```

`"5555:5555"` sin IP = publicar en **todas** las interfaces (IPv4 e IPv6).

## 2. Ligar el puerto a loopback

```yaml
    ports:
      - "8000:8000"                 # API pública
      - "127.0.0.1:5555:5555"       # consola: sólo desde este servidor
```

```bash
docker compose up -d
docker port billing-api-1           # 5555/tcp -> 127.0.0.1:5555
```

## 3. Verificar

```bash
curl -s --max-time 2 http://$(hostname -i):5555/ || echo "cerrado desde la red"
curl -s http://127.0.0.1:5555/                       # debug-console v0.3
curl -s http://$(hostname -i):8000/                  # billing-api ok
```

Si soporte trabaja desde su portátil: túnel SSH
(`ssh -L 5555:127.0.0.1:5555 servidor`), nunca publicar la consola.

## Lecciones

- `ports: "X:Y"` escucha en `0.0.0.0` **y** `[::]`. Pon siempre la IP si no es un servicio público.
- Además, Docker inserta sus propias reglas de iptables: un puerto publicado
  puede **saltarse el firewall del host** (ufw/firewalld).
- Lo correcto a medio plazo: que la consola no exista en producción.
