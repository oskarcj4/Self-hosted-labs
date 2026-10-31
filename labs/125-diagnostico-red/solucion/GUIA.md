# Resolución guiada · Lab 125

:::piensa Antes de tocar nada
"Va lento" no es un diagnóstico. Hay que demostrar en qué salto empieza el
problema, y con datos que el proveedor no pueda discutir.
:::

## Paso 1 · ¿Hasta dónde va bien?

**Pregúntate:** si haces ping al primer router y va bien, ¿qué descartas?

:::pista Cómo comprobarlo
```bash
ping -c 5 10.125.1.2       # tu router
ping -c 10 10.125.3.10     # el servidor
```
Fíjate en `packet loss` y en `rtt min/avg/max`.
:::

## Paso 2 · ¿Por dónde pasa?

:::pista Cómo comprobarlo
```bash
traceroute -n 10.125.3.10
```
:::

## Paso 3 · ¿En qué salto empieza?

**Pregúntate:** traceroute es una foto. ¿Qué herramienta mide cada salto muchas veces?

:::pista Cómo comprobarlo
```bash
mtr -rwnc 40 10.125.3.10 | tee ~/mtr.txt
```
Si la pérdida aparece en un salto **y sigue en todos los siguientes**, empieza ahí.
Pérdida sólo en un salto intermedio y no en el final suele ser el router que limita ICMP: no es problema.
:::

## Paso 4 · Diagnóstico

Escribe `~/diagnostico.txt` con `culpable=` (`proveedor` o `local`) y `salto=` (la IP).

## Paso 5 · Reprodúcelo

**Pregúntate:** ¿cómo demuestras que entiendes el síntoma? Créalo tú en tu interfaz.

:::pista Cómo hacerlo
```bash
sudo tc qdisc add dev eth0 root netem delay 200ms
ping -c 4 10.125.1.2 | tee ~/simulacion.txt
sudo tc qdisc del dev eth0 root       # ¡quítalo!
```
:::

## Cómo actuar en una situación así

- **De cerca a lejos**: tu equipo, tu router, el proveedor, el destino.
- **mtr con muchas muestras** y en ambos sentidos si puedes (desde el servidor hacia ti).
- `tc netem` sirve para probar cómo se comporta tu app con latencia y pérdida antes de que pase.

## Si te atascas

- `mtr` sin `-n` tarda: resuelve nombres. Añade `-n`.
- El check dice que queda netem: `tc qdisc show dev eth0` y bórralo.
