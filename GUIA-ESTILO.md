# Cómo se escribe una resolución guiada (`solucion/GUIA.md`)

La guía no es la solución con más pasos. La solución (`SOLUCION.md`) ya le da
al alumno los comandos para copiar. La guía tiene que hacer algo que la
solución no hace: **que entienda por qué cada paso es ese y qué le dice cada
resultado**, para que la próxima vez lo pueda hacer sin ayuda.

Si un paso de la guía es "aquí tienes 3 comandos" sin más, sobra: es la
solución con otro formato. El lab de referencia es
[`labs/143-fsociety-ddos-distraccion/solucion/GUIA.md`](labs/143-fsociety-ddos-distraccion/solucion/GUIA.md).

## Estructura

```markdown
# Resolución guiada · Lab NN

:::piensa <La idea clave del lab>
2–4 frases: qué está pasando de verdad y qué mentalidad hace falta.
:::

**El plan:** (1) … (2) … (3) …        ← el mapa, para que no se pierda

## Paso N · <Pregunta o acción concreta>

**Objetivo:** qué consigues con este paso y para qué lo necesitas después.

**Pregúntate:** la pregunta que tendría que hacerse para dar con el paso
por sí mismo. Si la responde, no necesita abrir la pista.

:::pista Cómo hacerlo
comando(s)
+ qué hace cada parte, si no es un comando de uso diario
+ **Qué deberías ver:** cómo es un resultado correcto
:::

## Comprueba
## Cómo actuar en una situación así    ← lo que se lleva a un caso real
## Si te atascas                         ← síntoma → causa → arreglo
```

## Las cuatro reglas

### 1. Cada paso dice para qué sirve

**Objetivo:** une el paso con el problema. "Sacar la IP y la hora de inicio:
la hora abre la ventana que investigarás en el paso 3" explica por qué ese
dato importa. "Mira el log" no.

### 2. Explica los comandos que no son de uso diario

No hace falta explicar `cat`, `ls`, `cd`, `nano`, `sudo` o `systemctl
restart`. **Sí** hay que explicar:

- **Tuberías** de más de dos piezas (`awk … | sort | uniq -c | sort -rn`).
- **Opciones que cambian el sentido del comando**: `find -newermt`,
  `grep -m1`, `-xdev`, `!`, `2>/dev/null`, `<<'EOF'` frente a `<<EOF`.
- **Directivas de configuración** (nginx, sshd, systemd, YAML de k8s…):
  qué hace cada línea que el alumno escribe y por qué ese valor.
- **Trucos** que parecen magia: `sudo tee` en vez de `sudo echo >`, el
  `[f]oo` en `pgrep -f`, `cut -d' ' -f1`…

El formato depende de cuánto hay que explicar:

| Caso | Formato |
|---|---|
| Una opción suelta | Una frase justo debajo del bloque de código. |
| 2–3 opciones | Lista corta (`- \`-m1\` hace que…`). |
| Tubería o fichero de configuración | Tabla `Parte \| Qué hace`, una fila por pieza. |

La explicación dice **qué hace y por qué está ahí**, no repite el manual.
"`sort` antes de `uniq` porque `uniq` sólo junta líneas contiguas" enseña algo;
"`sort` ordena líneas" no.

### 3. Di qué tiene que salir

Después de cada comando de diagnóstico, **Qué deberías ver:** con el aspecto
del resultado correcto o la cifra clave. Sin eso el alumno no sabe si el
comando funcionó, si lo escribió mal o si ya puede pasar al siguiente paso.

### 4. Todos los comandos se prueban en el lab

Cada comando de la guía, del RETO y de la solución se ejecuta en el lab
levantado antes de publicarlo. Errores que ya nos han pasado:

- `sudo pkill -f nombre` mata a su propio `sudo` (su línea de comandos también
  contiene `nombre`). Usa `pkill -f '[n]ombre'`, o mejor: comprueba con `pgrep`
  si de verdad hay proceso.
- `head -1` / `grep -m1` sobre un log que un proceso en vivo ya estaba
  escribiendo antes de que `plant.sh` añadiera el histórico: devuelve la hora
  actual, no la del incidente. El histórico se escribe **antes** de arrancar el
  servicio.
- Bloques comentados "de ejemplo" en una config que, al descomentarlos,
  duplican una sección y rompen `nginx -t`.
- Comandos de `/usr/sbin` (`nginx`, `iptables`, `nft`, `losetup`…) escritos
  sin `sudo` ni ruta completa: `/usr/sbin` no está en el `PATH` de `analista`
  y dan `command not found`.
- Leer ficheros de root (`/etc/restic/pass`, `/proc/<PID>/environ` de otro
  usuario, `/var/log/apache2/`) sin `sudo`. Y ojo: `sudo` no pasa tus
  variables de entorno al comando; usa `sudo env VAR=valor comando`.
- Un `check.sh` que sólo funciona con un usuario: el botón **Validar** lo
  ejecuta como root, y la terminal como `analista`. Pruébalo de las dos formas.
- Fragmentos con `# ...` o `curl ...` en lugar del fichero completo (workflows,
  Dockerfiles, compose, scripts): si el alumno lo copia, no funciona.
- Pasos que el reto exige y la guía nunca dice cómo hacer (escribir el fichero
  de respuestas, hacer `git push`, `terraform apply`).
- Afirmaciones sobre el orden en que aparecen los errores que no coinciden con
  el log real. Si la guía enseña a seguir el log, tiene que seguirlo.

## Qué no hacer

- Pistas que son sólo un bloque de código.
- Explicar todo: si cada `cd` lleva su párrafo, nadie lee los que importan.
- Pistas tipo "Exporta cada una y quédate con `spec`" sin el comando: si el
  paso necesita un comando, se escribe.
- Dar la respuesta en el **Pregúntate**. La pregunta orienta; la pista resuelve.
