# Resolución guiada · DNS roto ("siempre es el DNS")

:::piensa Antes de tocar nada
Clave del lab: `dig` y las aplicaciones **no** resuelven por el mismo camino.
`dig` pregunta directo al servidor DNS; las apps usan la libc, que primero lee
`/etc/nsswitch.conf` para saber **dónde** buscar. Por eso `dig` puede ir y la
app no. Aquí hay dos fallos encadenados: un nameserver viejo y un nsswitch que
no consulta DNS.
:::

## Paso 1 · El síntoma exacto

```bash
curl -s http://127.0.0.1:8080/health
# checkout ERROR ... http://pagos:8080/health: Name or service not known
```

Es error de **nombre**, no de red ni de la API.

## Paso 2 · ¿Qué DNS usamos y responde?

**Pregúntate:** ¿el nameserver de `resolv.conf` sigue vivo?

:::pista Cómo comprobarlo
```bash
cat /etc/resolv.conf              # nameserver 10.76.61.250 -> retirado
dig pagos.interno                 # ;; connection timed out; no servers could be reached
dig @10.76.61.53 pagos.interno +short   # 10.76.61.30 -> el DNS bueno sí responde
```
Arréglalo (usa `nano`/`tee`, no `sed -i`: Docker monta `/etc/resolv.conf`):
```bash
sudo tee /etc/resolv.conf >/dev/null <<'EOF'
nameserver 10.76.61.53
search interno
options timeout:2 attempts:2
EOF
dig pagos.interno +short     # 10.76.61.30
dig +search pagos +short     # 10.76.61.30  (search completa el nombre corto)
```
:::

## Paso 3 · `dig` va y la app sigue sin resolver

**Pregúntate:** si el DNS ya responde, ¿por qué `getent hosts pagos` no da nada?
Porque nsswitch no consulta DNS.

:::pista Cómo verlo y arreglarlo
```bash
getent hosts pagos                 # (vacío)
grep ^hosts /etc/nsswitch.conf     # hosts: files   <- sólo /etc/hosts, nunca DNS
sudo sed -i 's/^hosts:.*/hosts:          files dns/' /etc/nsswitch.conf
getent hosts pagos                 # 10.76.61.30  pagos.interno
```
`getent` usa el mismo camino que la app (libc). Si `getent` resuelve, la app
resuelve.
:::

## Paso 4 · Verifica

```bash
getent hosts pagos ; getent hosts pagos.interno     # ambos 10.76.61.30
grep -q pagos /etc/hosts && echo "¡atajo prohibido!" || echo "sin atajo en hosts"
curl -s http://127.0.0.1:8080/health                # checkout ok
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Distingue herramientas**: `dig`/`nslookup` prueban el **servidor DNS**;
  `getent hosts` prueba **lo que ve la app** (nsswitch → files → dns).
- **Orden de diagnóstico**: `getent` → `cat /etc/resolv.conf` → `dig @servidor`
  → `grep ^hosts /etc/nsswitch.conf`.
- **No metas la IP en `/etc/hosts`**: "funciona" hasta el próximo despliegue y
  luego falla en silencio con una IP vieja (es el lab 56).
- Con `systemd-resolved`, usa `resolvectl status`: `resolv.conf` apunta a
  `127.0.0.53`.

## Si te atascas

- `dig` resuelve y `getent` no → nsswitch sin `dns` (`hosts: files dns`).
- Nada resuelve → nameserver muerto en `resolv.conf`; ponlo con `nano`/`tee`.
- `pagos` a secas no resuelve pero `pagos.interno` sí → falta `search interno`.
