# Resolución guiada · Lab 135

:::piensa Antes de tocar nada
`npm install` ejecuta código de terceros en tu máquina: los scripts
`preinstall`/`postinstall` de cada dependencia. Un nombre con una letra cambiada
(typosquatting) basta para que ese código sea de un atacante.
:::

## Paso 1 · ¿Qué dependencias hay?

:::pista Cómo comprobarlo
```bash
cd /srv/app
cat package.json
```
`color-utilz` y `color-utils`: ¿cuál es el de verdad?
:::

## Paso 2 · Inspecciona sin instalar

**Pregúntate:** ¿cómo ves los scripts, el autor y la antigüedad de un paquete sin ejecutarlo?

:::pista Cómo comprobarlo
```bash
npm view color-utilz scripts author time
npm view color-utils
npm pack color-utilz && tar -xzOf color-utilz-*.tgz package/package.json
```
Paquete recién publicado + `postinstall` + nombre casi igual a uno popular = alarma.
:::

Escribe `paquete_malicioso=`, `script=` y `legitimo=` en `~/npm.txt`.

## Paso 3 · Que no se ejecuten scripts

:::pista Cómo hacerlo
```bash
echo 'ignore-scripts=true' >> /srv/app/.npmrc
npm config get ignore-scripts      # true
```
:::

## Paso 4 · Dependencia correcta y lockfile

**Pregúntate:** ¿qué fichero fija la versión exacta y el hash de cada paquete?

:::pista Cómo hacerlo
```bash
npm pkg delete dependencies.color-utilz
npm pkg set 'dependencies.color-utils=^2.1.0'
npm install --package-lock-only
grep -c color-utilz package-lock.json      # 0
```
:::

## Paso 5 · Instalación limpia

**Pregúntate:** ¿por qué `npm ci` y no `npm install`?

:::pista Cómo hacerlo
```bash
rm -rf node_modules
npm ci
node index.js
```
`npm ci` instala exactamente lo del lockfile y falla si no coincide con `package.json`.
:::

## Cómo actuar en una situación así

- **Si el postinstall ya se ejecutó**, trata la máquina como comprometida (`/tmp/.color-cache` es su rastro).
- `ignore-scripts` por defecto y lista blanca de los paquetes que de verdad lo necesitan.
- `npm ci` en CI; revisa diffs del lockfile en cada PR; `npm audit signatures`.

## Si te atascas

- `npm ci` falla: el lockfile no coincide; vuelve a generar con `npm install --package-lock-only`.
- `npm view` no responde: el registro está en el `.npmrc` del proyecto; ejecuta desde `/srv/app`.
