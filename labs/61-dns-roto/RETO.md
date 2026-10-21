# DNS roto ("siempre es el DNS")

> Operaciones · Redes · resolv.conf · nsswitch · dig vs getent

## Escenario

`checkout` en `app-03` no puede llamar a la API de pagos y su `/health`
devuelve 503. La configuración de `checkout` usa el nombre corto `pagos`, que
vive en la zona DNS interna `interno`. Lee `~/ticket/INC-6101.txt`.

El DNS interno vigente es `dns-01` (10.76.61.53). Que `dig` funcione no
significa que las aplicaciones resuelvan: siguen otro camino.

## Objetivos

1. `/etc/resolv.conf` usa `dns-01` como primer nameserver y completa los
   nombres cortos con la zona `interno`.
2. El sistema consulta el DNS para resolver nombres de máquina
   (`/etc/nsswitch.conf`).
3. `getent hosts pagos` y `getent hosts pagos.interno` devuelven 10.76.61.30.
4. Sin atajos: **nada de `pagos` en `/etc/hosts`**.
5. `checkout /health` responde 200.

## Comandos que te pueden servir

```bash
curl -s http://127.0.0.1:8080/health
cat /etc/resolv.conf ; grep ^hosts /etc/nsswitch.conf
getent hosts pagos            # lo que ven las aplicaciones (libc)
dig pagos.interno             # pregunta al DNS de resolv.conf
dig @10.76.61.53 pagos.interno +short
dig +search pagos             # usa el 'search' de resolv.conf
```

> `/etc/resolv.conf` es un fichero montado por Docker: edítalo con `nano` o
> `tee`, no con `sed -i`.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
