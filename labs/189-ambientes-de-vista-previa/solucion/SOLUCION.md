# Solución — Vistas previas por PR

## Problemas y arreglos

| Problema | Arreglo |
|----------|---------|
| mismo proyecto, imagen y puerto | `-p pr-N`, `tienda:pr-N`, puerto `9000+N` |
| `git checkout` en la copia de trabajo | `git archive pr-N \| tar -x` a `~/.previews/pr-N` |
| copia de producción | volumen nuevo por PR, sembrado con `datos/semilla.sql` |
| `down` deja datos | `down -v --remove-orphans` + `image rm` |
| PRs cerrados para siempre | `gc` contra `/srv/prs-abiertos.txt` |

`ci/preview.sh` y `ci/preview.compose.yaml` completos están en `solve.sh`.

## Detalles que importan

- El compose de las vistas previas está en `ci/` de `main`, no en la rama:
  así un PR no puede cambiar cómo se despliega su propia vista previa (puertos, volúmenes del host).
- `gc` mira también los **volúmenes**: un proyecto con los contenedores
  borrados a mano sigue teniendo datos.
- `${VAR:?}` en el compose: si falta una variable, falla en vez de usar un valor vacío.

## Más allá del lab

- En Kubernetes: un namespace por PR (Argo CD ApplicationSet con generador de PRs) y TTL.
- Coste: apaga las vistas previas inactivas, o usa escalado a cero.
