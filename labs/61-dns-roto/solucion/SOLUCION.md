# Solución — DNS roto

## 1. El síntoma exacto

```bash
curl -s http://127.0.0.1:8080/health
# checkout ERROR llamando a http://pagos:8080/health: <urlopen error [Errno -2] Name or service not known>
```

Es un error de **nombre**, no de red ni de la API.

## 2. ¿Qué DNS usamos?

```bash
cat /etc/resolv.conf
# nameserver 10.76.61.250        <- DNS retirado
dig pagos.interno                # ;; connection timed out; no servers could be reached
dig @10.76.61.53 pagos.interno +short    # 10.76.61.30  <- el DNS bueno sí responde
```

```bash
sudo tee /etc/resolv.conf >/dev/null <<'EOF'
nameserver 10.76.61.53
search interno
options timeout:2 attempts:2
EOF
dig pagos.interno +short         # 10.76.61.30
dig +search pagos +short         # 10.76.61.30
```

`search interno` hace que un nombre sin punto (`pagos`) se pruebe también como
`pagos.interno`.

## 3. dig funciona... y la app sigue sin resolver

```bash
getent hosts pagos               # (nada)
grep ^hosts /etc/nsswitch.conf   # hosts: files
```

`dig` habla directamente con el servidor DNS. Las aplicaciones (y `getent`,
`ping`, `curl`) usan la libc, que primero lee `/etc/nsswitch.conf` para saber
**dónde** buscar. Con `hosts: files` sólo mira `/etc/hosts` y nunca pregunta
al DNS.

```bash
sudo sed -i 's/^hosts:.*/hosts:          files dns/' /etc/nsswitch.conf
getent hosts pagos               # 10.76.61.30   pagos.interno
curl -s http://127.0.0.1:8080/health     # checkout ok -> pagos-api ok
```

## Lecciones

- Distingue las herramientas: `dig`/`nslookup` prueban **el servidor DNS**;
  `getent hosts` prueba **lo que ve la aplicación** (nsswitch + hosts + DNS).
- Orden de diagnóstico: `getent` → `cat /etc/resolv.conf` → `dig @servidor`
  → `grep ^hosts /etc/nsswitch.conf`.
- Meter la IP en `/etc/hosts` "funciona" hasta el próximo despliegue, y luego
  falla en silencio con una IP vieja (es lo que pasó en el lab 56).
- En servidores con `systemd-resolved`, `resolvectl status` enseña los DNS
  reales: `/etc/resolv.conf` apunta a `127.0.0.53`.
