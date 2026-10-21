# Resolución guiada · Día 01

:::piensa Antes de tocar nada
Una auditoría **no cambia nada**: observa y documenta. Y la documentación que te pasaron es una pista, no la verdad. La verdad es lo que el kernel dice que está escuchando *ahora*. Tu trabajo es construir esa foto y compararla con lo que te contaron.
:::

## Paso 1 · La foto real

**Pregúntate:** ¿qué comando le pregunta al kernel por los sockets TCP en escucha y su proceso? ¿Por qué hace falta `sudo`?

**Por qué importa:** sin `sudo` sólo ves el proceso de tus propios sockets; los de otros usuarios salen sin nombre.

:::pista Cómo comprobarlo
```bash
sudo ss -tlnp
```
- `-t` TCP, `-l` en escucha, `-n` números (sin resolver nombres), `-p` proceso.
:::

## Paso 2 · Aprende a leer la dirección local

**Pregúntate:** en `0.0.0.0:80` y `127.0.0.1:8081`, ¿qué significa la parte antes de los dos puntos?

**Por qué importa:** es **dónde** escucha. Esa es la diferencia entre "cualquiera de la red puede llegar" y "sólo esta máquina".

- `0.0.0.0`, `*`, `[::]` → todas las interfaces → **publico**.
- `127.0.0.1`, `[::1]` → sólo la propia máquina → **local**.
- Una IP concreta que no es loopback → accesible desde esa red → **publico**.

## Paso 3 · Filtra el ruido del laboratorio

**Pregúntate:** ¿qué sockets no son del escenario? El enunciado lo dice: el `7681` (terminal web) y lo que escucha en `127.0.0.11` (DNS de Docker).

## Paso 4 · Construye el inventario

**Pregúntate:** ¿lo escribo a mano o lo genero? A mano está bien para 6 líneas; generarlo evita errores y te enseña `awk`.

:::pista Plantilla
```bash
mkdir -p ~/audit
cat > ~/audit/listeners.csv <<'EOF'
puerto,exposicion,proceso
<puerto>,<publico|local>,<proceso>
EOF
```
El nombre del proceso es el que aparece en `users:(("nombre",...))`.
:::

## Paso 5 · Compara con la documentación

**Pregúntate:** ¿qué dice `~/handoff/servicios.md` que no coincide con lo que ves? Busca tres tipos de diferencia: algo "local" que en realidad es público, algo "dado de baja" que sigue corriendo y algo que no aparece documentado.

```bash
cat ~/handoff/servicios.md
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Primero la línea base, luego los cambios.** Si cambias algo antes de documentar, pierdes la foto del "antes".
- **El runtime manda**; la documentación se corrige con lo que encuentras.
- **Lo que hay que reportar son las diferencias**: un servicio "interno" que escucha en `0.0.0.0` y un servicio "retirado" que sigue vivo son riesgos reales.
- Herramienta alternativa: `sudo lsof -iTCP -sTCP:LISTEN -P -n`.

## Si te atascas

- No ves nombres de proceso: falta `sudo`.
- El validador marca un puerto: revisa si es `publico` o `local` mirando sólo la parte antes de `:`.
