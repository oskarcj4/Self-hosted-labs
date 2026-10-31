# Cadena de suministro npm: mira antes de instalar

> Hardening web · npm view · ignore-scripts · package-lock · npm ci

## Escenario

Un compañero añadió una dependencia de colores a `/srv/app` y el build
"hace cosas raras" (`~/ticket/SEC-135.txt`). El registro es interno
(`http://registry:4873`). **No ejecutes `npm install` a ciegas**: un
`npm install` ejecuta los scripts `preinstall`/`install`/`postinstall` de
**todas** las dependencias, con tus permisos, tus variables de entorno y
tu `~/.npmrc` (con tu token).

Trucos habituales: **typosquatting** (un nombre casi igual al popular),
paquetes recién publicados por autores desconocidos y scripts de
instalación que no tienen nada que ver con lo que el paquete dice hacer.

## Objetivos

1. Inspecciona cada dependencia **antes** de instalar: autor, fecha,
   scripts. Compara con el paquete que realmente se quería.
2. Rellena `~/npm.txt`: `paquete_malicioso=`, `script=`, `legitimo=`.
3. Haz que npm no ejecute scripts de instalación en este proyecto.
4. Corrige la dependencia, genera `package-lock.json` (fija versiones y
   hashes de integridad) e instala con `npm ci`. Comprueba que la app arranca.
5. Si en algún momento se ejecutó el script malicioso, limpia sus restos y
   considera comprometido el token de `~/.npmrc`.

## Comandos que te pueden servir

```bash
cd /srv/app ; cat package.json .npmrc
npm view color-utilz ; npm view color-utilz scripts author time
npm view color-utils
npm config get ignore-scripts
npm pkg delete dependencies.<x> ; npm pkg set 'dependencies.<y>=^<versión>'
npm install --package-lock-only
npm ci                         # instala EXACTAMENTE lo del lockfile
npm audit signatures           # en npmjs.org verifica firmas; aquí verás que el registro interno no firma
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
