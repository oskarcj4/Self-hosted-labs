# Solución — Día 01: Auditar servicios en escucha

## 1. Foto del estado real

```bash
sudo ss -tlnp
```

Verás algo parecido a:

```
LISTEN 0 128   0.0.0.0:22     0.0.0.0:*  users:(("sshd",pid=..))
LISTEN 0 511   0.0.0.0:80     0.0.0.0:*  users:(("nginx",pid=..))
LISTEN 0 5     0.0.0.0:6379   0.0.0.0:*  users:(("cache-svc",pid=..))
LISTEN 0 5   127.0.0.1:8081   0.0.0.0:*  users:(("inventory-api",pid=..))
LISTEN 0 5     0.0.0.0:8873   0.0.0.0:*  users:(("legacy-sync",pid=..))
LISTEN 0 5   127.0.0.1:9100   0.0.0.0:*  users:(("metrics-exp",pid=..))
LISTEN 0 4096  0.0.0.0:7681   ...        users:(("ttyd",...))   <- terminal del lab, se ignora
```

La columna 4 (`Local Address:Port`) dice **dónde** escucha: `0.0.0.0` = todas
las interfaces (público), `127.0.0.1` = sólo la propia máquina (local).

## 2. Inventario

```bash
cat > ~/audit/listeners.csv <<'EOF'
puerto,exposicion,proceso
22,publico,sshd
80,publico,nginx
6379,publico,cache-svc
8081,local,inventory-api
8873,publico,legacy-sync
9100,local,metrics-exp
EOF
```

O generado directamente desde `ss`:

```bash
sudo ss -H -tlnp | awk '{port=$4; sub(/.*:/,"",port); host=$4; sub(/:[0-9]+$/,"",host);
  proc=$0; sub(/.*users:\(\("/,"",proc); sub(/".*/,"",proc);
  if (port!=7681 && host!="127.0.0.11") print port "," (host ~ /^127\./ ? "local" : "publico") "," proc}' | sort -un
```

## 3. Diferencias con la documentación (lo que importa reportar)

| Hallazgo | Documentado | Real |
|---|---|---|
| `cache-svc` 6379 | local | **público** (0.0.0.0) |
| `legacy-sync` 8873 | "dado de baja" | **sigue corriendo y es público** |
| `metrics-exp` 9100 | sin documentar | local |

Los dos primeros son hallazgos de riesgo: un caché de sesiones y un servicio
legacy olvidado expuestos a la red.

## Lecciones

- `sudo ss -tlnp` es la fuente de verdad: el kernel no miente, la wiki sí.
- `0.0.0.0` / `[::]` = todas las interfaces. Un servicio "interno" que escucha ahí es público.
- Una auditoría **no** modifica el sistema: primero la línea base, después los cambios (días 02-03).
