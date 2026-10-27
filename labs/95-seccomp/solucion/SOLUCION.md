# Solución — seccomp: del unconfined a un perfil propio

## 1. Qué hace seccomp

Un filtro BPF en el kernel que decide, syscall a syscall, si el proceso puede
hacerla. `unconfined` = Docker no añade ningún filtro.
El perfil de Docker es lista blanca: `defaultAction: SCMP_ACT_ERRNO` y unas
300+ syscalls permitidas, algunas sólo con cierta capability o kernel.

## 2. Perfil derivado

```bash
jq '.syscalls |= (map(.names -= ["ptrace","process_vm_readv","process_vm_writev"])
                  | map(select(.names | length > 0)))' \
  profiles/docker-default.json > profiles/api.json
```

```yaml
security_opt:
  - seccomp=./profiles/api.json
```

Compose lee el fichero y manda el JSON al daemon. Por eso `docker inspect`
muestra el perfil entero en `SecurityOpt`: comprueba el efecto con `probe.sh`.

## 3. ¿Por qué no `defaultAction: SCMP_ACT_ALLOW` + denegar tres?

Porque es lista negra: cada syscall nueva del kernel (y salen varias por
versión) queda permitida por defecto. `io_uring` pasó años saltándose
controles así. Lista blanca: lo nuevo está cerrado hasta que lo abras.

## Lecciones

- `unconfined` casi nunca es la respuesta. Si algo peta, busca la syscall
  (`strace -f`, o `SCMP_ACT_LOG` y `dmesg`/auditd) y ábrela sólo a ella.
- El perfil por defecto es un suelo genérico. Uno a medida por servicio
  quita superficie que esa imagen no usa.
- `ptrace` y `process_vm_*` permiten leer memoria de otros procesos del mismo
  usuario en el contenedor: secretos en RAM, tokens de sesión, inyección.
- Verifica en runtime (una syscall concreta da EPERM), no sólo en el YAML.
  Ojo con `Seccomp: 2` a secas: Docker Desktop y algunos hosts ya filtran
  todo, así que hasta un contenedor `unconfined` lo muestra. Compara
  `Seccomp_filters` con el del proceso padre.
- Kubernetes: `securityContext.seccompProfile: {type: Localhost, localhostProfile: ...}`;
  `RuntimeDefault` es el equivalente al perfil por defecto de Docker.
