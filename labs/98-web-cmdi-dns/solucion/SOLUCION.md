# Solución — Command injection (vía BLUE)

> Solo el arreglo. La captura (RED) la resuelves tú.

## Causa

El parámetro `host` se concatena en una cadena que ejecuta `/bin/sh -c`.
Con `shell=True`, cualquier metacaracter de shell en la entrada se interpreta:
`;` encadena, `|` canaliza, `$(...)` y `` `...` `` sustituyen, `&&`/`||`
condicionan.

## Arreglo

1. **Sin shell.** `subprocess.run(["getent", "hosts", host], shell=False)`:
   `host` es un `argv[]`, nunca código.
2. **Validación de formato** (lista blanca): un hostname/IP encaja en
   `^[A-Za-z0-9._-]+$`. Lo que no, se rechaza.

## Qué NO arregla el problema

- Escapar o quitar `;`, `|`, `&`… a mano: siempre falta un caso
  (`$()`, saltos de línea, `-opciones` que cambian el binario).
- Mantener `shell=True` y "limpiar" la entrada: el enfoque correcto es no
  darle una shell que interpretar.

## Lecciones

- Ejecuta comandos con lista de argumentos, nunca construyendo una línea de
  shell con entrada del usuario.
- Mínimo privilegio: la app corre como `app`, no root; aun con RCE el daño se
  acota. La flag 600 app:app lo demuestra.
- Valida el formato esperado (allowlist), no el prohibido (blocklist).
