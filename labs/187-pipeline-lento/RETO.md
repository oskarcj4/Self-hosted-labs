# Pipeline lento

> DevOps · CI · caché de capas de Docker · .dockerignore · caché de dependencias por hash

## Escenario

Cada push a la API de entregas tarda casi **un minuto** en CI, aunque sólo
cambie una línea. Con 30 commits al día y 6 personas esperando, son horas
perdidas, y la gente empieza a juntar cambios para "no lanzar tanto CI".

Mira dónde se va el tiempo:

```bash
cd ~/api
ci-logs        # log del último pipeline
ci-logs -l     # historial con duraciones
```

En el lab hay Docker propio y Woodpecker CLI: `ci-run` lanza el pipeline
sobre el commit HEAD.

## Objetivos

1. Un commit que **sólo toca código** tarda **menos de 25 s**.
2. La imagen `api:<sha>` sigue llevando el código nuevo.
3. Si cambia `requirements.txt`, las dependencias se reinstalan, en los
   tests y en la imagen. Una caché que no se invalida es un bug.
4. Un test roto sigue poniendo el pipeline en rojo.
5. `datos/` se queda en el repo, pero ni se envía al build ni entra en la imagen.

## Pistas

- Docker reutiliza una capa si no ha cambiado nada **de lo que se copió antes**.
- `transferring context: 150MB`: todo lo que no está en `.dockerignore` se
  envía al daemon en cada build.
- Una caché de dependencias se identifica por el **hash** del fichero que las
  define: `sha256sum requirements.txt`.
- Woodpecker sustituye `$VARIABLES` en el YAML antes de ejecutar: la lógica
  con variables de shell, mejor en un script (`ci/…`).

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
