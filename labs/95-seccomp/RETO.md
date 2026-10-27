# seccomp: del unconfined a un perfil propio

> Pipeline / runtime · seccomp · security_opt · syscalls

## Escenario

`api` (stack `seccomp`, `~/seccomp`) sirve HTTP en `:8080` con
`security_opt: [seccomp:unconfined]` ("un syscall raro petaba en 2019";
nadie recuerda cuál). Sin filtro, el proceso puede hacer cualquier syscall
que el kernel le permita.

```bash
cd ~/seccomp && ./probe.sh
```

Quitar `unconfined` te deja en el perfil por defecto de Docker. Es un buen
suelo, pero permite `ptrace` y `process_vm_readv`/`process_vm_writev`: leer y
escribir la memoria de otro proceso del contenedor (tokens, claves de sesión).
Esta api no depura a nadie. Seguridad quiere un perfil **propio**: el de Docker
menos esas tres syscalls.

Tienes el perfil por defecto en `profiles/docker-default.json`.

## Objetivos

1. Nada de `unconfined` (ni en `compose.yaml` ni en el contenedor).
2. `profiles/api.json`: perfil de **lista blanca** (`defaultAction` deniega)
   derivado del de Docker, sin `ptrace`, `process_vm_readv` ni
   `process_vm_writev`.
3. `api` corre con ese perfil: el contenedor tiene un filtro seccomp más que
   el host del lab (`Seccomp_filters` en `/proc/self/status`), y `ptrace` y
   `process_vm_readv` dan `Operation not permitted`.
4. `curl :8080` → `api ok`.

## Comandos que te pueden servir

```bash
cd ~/seccomp
jq '.defaultAction, (.syscalls | length)' profiles/docker-default.json
jq '.syscalls[] | select(.names | index("ptrace"))' profiles/docker-default.json
# en compose.yaml:  security_opt: ["seccomp=./profiles/api.json"]
docker compose up -d --force-recreate && ./probe.sh
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
