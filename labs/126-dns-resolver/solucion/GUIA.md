# Resolución guiada · Lab 126

:::piensa ¿A quién le preguntas?
Cuando tu equipo resuelve un nombre, se cree lo que le responda su
**resolver** (el servidor DNS de `/etc/resolv.conf`). Si ese resolver es
falso, todas las respuestas pueden serlo: el usuario llega a un portal falso
que le pide la contraseña. `dig @servidor` permite preguntar a quien tú elijas
y comparar.
:::

**El plan:** (1) ver qué resolver usa el puesto, (2) comparar con el oficial,
(3) resolución inversa, (4) corregir el resolver y (5) comprobar DNSSEC.

## Paso 1 · ¿A quién pregunta el puesto?

:::pista Cómo hacerlo
```bash
cat /etc/resolv.conf
dig portal.empresa.lab
```
**dig** pregunta al servidor DNS y enseña la respuesta completa: la sección
`ANSWER` con la IP y, al final, `;; SERVER:` con quién respondió.

**Qué deberías ver:** `nameserver 10.126.0.99` (no es el oficial) y la IP que
da para el portal.
:::

## Paso 2 · Compara con el resolver oficial

:::pista Cómo hacerlo
```bash
dig +short portal.empresa.lab
dig +short @10.126.0.53 portal.empresa.lab
```
`@10.126.0.53` pregunta a ese servidor en vez de al de `resolv.conf`;
`+short` imprime sólo la respuesta.

**Qué deberías ver:** dos IP distintas. La del resolver oficial es la buena.
:::

## Paso 3 · Resolución inversa

**Pregúntate:** ¿qué nombre tiene la máquina `10.126.0.25`?

:::pista Cómo hacerlo
```bash
dig -x 10.126.0.25 @10.126.0.53 +short
```
`-x` hace la pregunta al revés: de IP a nombre (registro `PTR`).

**Qué deberías ver:** `backup-nas.empresa.lab.`. El punto final indica un
nombre completo, hasta la raíz del DNS (el validador lo acepta con o sin él).

Escribe lo averiguado:
```bash
nano ~/dns.txt
```
```
resolver_actual=10.126.0.99
portal_falso=<IP que da el resolver actual>
portal_real=<IP que da 10.126.0.53>
nombre_25=backup-nas.empresa.lab
```
:::

## Paso 4 · Corrige el resolver

:::pista Cómo hacerlo
```bash
echo 'nameserver 10.126.0.53' | sudo tee /etc/resolv.conf
getent hosts portal.empresa.lab
```
- `tee` (sin `-a`) sustituye el contenido. En un contenedor, Docker monta
  `/etc/resolv.conf` desde fuera; `tee` escribe dentro del mismo fichero, pero
  `sed -i` fallaría porque intenta sustituirlo por otro.
- `getent hosts` resuelve como lo hacen el navegador y las aplicaciones
  (`/etc/hosts` y luego DNS). `dig` no mira `/etc/hosts`: si sólo pruebas con
  `dig`, no sabes lo que ve el resto del sistema.

**Qué deberías ver:** la IP real del portal.
:::

## Paso 5 · DNSSEC

**Pregúntate:** ¿cómo sabes que la respuesta no se alteró por el camino?

:::pista Cómo hacerlo
```bash
dig +dnssec portal.empresa.lab @10.126.0.53 | tee ~/dnssec.txt
grep flags ~/dnssec.txt
bash /opt/lab/check.sh
```
- **DNSSEC** firma los registros de una zona. Un resolver que valida
  comprueba las firmas y descarta lo que no cuadra.
- `+dnssec` pide también las firmas (registros `RRSIG`).
- En la línea `flags:`, `ad` (*Authenticated Data*) significa que el resolver
  validó la firma.

**Qué deberías ver:** `flags: qr rd ra ad;`.
:::

## Cómo actuar en una situación así

- El resolver se fija por configuración gestionada (DHCP, systemd-resolved,
  netplan), no a mano.
- DNSSEC protege el **contenido**; DoT o DoH cifran el **camino** hasta el
  resolver. Son complementarios.
- Si un usuario metió la contraseña en el portal falso, está comprometida:
  cámbiala.

## Si te atascas

- **El check dice que `nombre_25` es incorrecto:** preguntaste al resolver
  falso. Usa `@10.126.0.53`.
- **No aparece `ad`:** estás preguntando al resolver falso; mira `;; SERVER:`.
- **`getent` sigue dando la IP falsa:** mira si hay una entrada en
  `/etc/hosts`.
