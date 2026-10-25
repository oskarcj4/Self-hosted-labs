# Solución — Capabilities y no-new-privileges

## 1. Qué privilegio tiene hoy

```bash
cd ~/caps
docker inspect caps-api-1 --format 'add={{.HostConfig.CapAdd}} drop={{.HostConfig.CapDrop}} sec={{.HostConfig.SecurityOpt}}'
```

`CAP_ALL` + `SYS_ADMIN` es casi privileged: montajes, módulos, pivote de
namespaces.

## 2. Mínimo para un HTTP

La app no toca la red del host ni el kernel. `cap_drop: ALL` y
`no-new-privileges:true` bastan. No sustituyas `cap_add: ALL` por una lista
igual de ancha.

```yaml
services:
  api:
    image: shop/api:1.0
    build: ./api
    cap_drop:
      - ALL
    security_opt:
      - no-new-privileges:true
    ports:
      - "8080:8080"
    restart: unless-stopped
```

```bash
docker compose up -d
curl -s localhost:8080
```

## Lecciones

- `cap_add: ALL` es privileged con otro nombre.
- `no-new-privileges` impide que un binario SUID dentro del contenedor gane caps.
- Empieza en cero y añade **una** cap si un syscall concreto lo exige (casi nunca).
