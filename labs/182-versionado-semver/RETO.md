# Versionado semántico y releases

> DevOps · SemVer · Conventional Commits · CHANGELOG · etiquetas anotadas

## Escenario

El SDK de la tienda (`~/tienda-sdk`) se publica "cuando alguien se acuerda" y
la versión se decide a ojo. Ahora alguien propone sacar la **1.5.0**.

**SemVer** (`MAJOR.MINOR.PATCH`) es un contrato con quien usa tu código:

| Sube | Cuándo | Para quien te usa |
|------|--------|-------------------|
| PATCH | correcciones | actualiza sin miedo |
| MINOR | funciones nuevas compatibles | actualiza sin miedo |
| MAJOR | cambios **incompatibles** | revisa su código antes de actualizar |

Con **Conventional Commits** (`fix:`, `feat:`, `tipo!:`, pie
`BREAKING CHANGE:`) la versión siguiente sale del historial, sin opiniones.
Si se calcula mal, alguien actualiza una "minor" y su producción se rompe.

## Objetivos

1. `~/tienda-sdk/scripts/siguiente-version` (Bash o Python) que imprime la
   siguiente versión según las reglas de `~/TAREA.txt`. El check lo prueba con
   repos que no has visto.
2. La release correcta: `VERSION`, `CHANGELOG.md` con su sección, commit
   `chore(release): X.Y.Z` y etiqueta **anotada** `vX.Y.Z`.

## Pistas

```bash
cd ~/tienda-sdk
git log --oneline --decorate
git tag --list 'v*' | sort -V
git log v1.4.2..HEAD --format='--- %s%n%b'      # ¡lee también los cuerpos!
git log -z --format=%B v1.4.2..HEAD              # un mensaje completo por registro, separados por NUL
git tag -a v9.9.9 -m "Release v9.9.9"
git cat-file -t v9.9.9                           # "tag" = anotada; "commit" = ligera
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
