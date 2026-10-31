# Resolución guiada · Lab 126

:::piensa Antes de tocar nada
Cuando preguntas un nombre, confías en quien responde. Si el resolver que usas
es falso, todas las respuestas pueden serlo. `dig @servidor` te deja preguntar a
quien tú elijas y comparar.
:::

## Paso 1 · ¿A quién preguntas?

:::pista Cómo comprobarlo
```bash
cat /etc/resolv.conf
dig portal.empresa.lab        # mira la línea ";; SERVER:"
```
:::

## Paso 2 · Compara con el resolver oficial

**Pregúntate:** el ticket dice cuál es el resolver de la empresa. ¿Dan la misma IP?

:::pista Cómo comprobarlo
```bash
dig +short portal.empresa.lab
dig +short @10.126.0.53 portal.empresa.lab
```
:::

## Paso 3 · Resolución inversa

**Pregúntate:** ¿qué nombre tiene la máquina `10.126.0.25`?

:::pista Cómo comprobarlo
```bash
dig -x 10.126.0.25 @10.126.0.53 +short
```
Escribe `resolver_actual`, `portal_falso`, `portal_real` y `nombre_25` en `~/dns.txt`.
:::

## Paso 4 · Corrige el resolver

:::pista Cómo hacerlo
```bash
echo 'nameserver 10.126.0.53' | sudo tee /etc/resolv.conf
dig portal.empresa.lab
```
:::

## Paso 5 · DNSSEC

**Pregúntate:** ¿cómo sabes que la respuesta no se alteró por el camino? El flag `ad` (Authenticated Data) indica que el resolver validó las firmas.

:::pista Cómo comprobarlo
```bash
dig +dnssec portal.empresa.lab | tee ~/dnssec.txt
grep flags ~/dnssec.txt          # debe incluir "ad"
```
:::

## Cómo actuar en una situación así

- **Fija el resolver** por configuración gestionada (DHCP, systemd-resolved, netplan), no a mano.
- **DNSSEC** firma las zonas; un resolver que valida descarta respuestas falsas.
- DoT/DoH cifran el camino hasta el resolver; DNSSEC protege el contenido.

## Si te atascas

- No aparece `ad`: estás preguntando al resolver falso; revisa `;; SERVER:`.
- `dig -x` sin respuesta: añade `@10.126.0.53`.
