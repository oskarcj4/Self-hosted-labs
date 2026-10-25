# Resolución guiada · Lab 95

:::piensa
Quitar `unconfined` te devuelve al perfil de Docker, pensado para que
*cualquier* imagen arranque. Tu api no es cualquier imagen: sabes qué no
necesita. Parte del default y **resta**, no escribas una lista negra.
:::

## Paso 1 · Mide

`./probe.sh`: con unconfined, mismos filtros que el host del lab y todo permitido.

## Paso 2 · Encuentra las reglas

```bash
jq '.syscalls[] | select(.names | index("ptrace"))' profiles/docker-default.json
```

Aparecen en dos reglas: una con `minKernel: 4.8` y otra condicionada a
`CAP_SYS_PTRACE`. Hay que quitarlas de **todas**.

## Paso 3 · Resta con jq

```bash
jq '.syscalls |= (map(.names -= ["ptrace","process_vm_readv","process_vm_writev"])
                  | map(select(.names | length > 0)))' \
  profiles/docker-default.json > profiles/api.json
```

`defaultAction` sigue siendo `SCMP_ACT_ERRNO`: lo que no está permitido,
se deniega.

## Paso 4 · Aplica y comprueba

`security_opt: ["seccomp=./profiles/api.json"]`,
`docker compose up -d --force-recreate`, `./probe.sh` y `curl :8080`.
