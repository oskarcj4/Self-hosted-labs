# Resolución guiada · Lab 135

:::piensa Instalar es ejecutar
`npm install` no sólo descarga: ejecuta los scripts `preinstall`, `install` y
`postinstall` de **cada** dependencia, con tus permisos, tus variables de
entorno y tu `~/.npmrc` (con tu token del registro). Un nombre con una letra
cambiada (*typosquatting*) basta para que ese código sea de un atacante. Hay
que mirar antes de instalar.
:::

**El plan:** (1) ver las dependencias, (2) inspeccionarlas sin instalar,
(3) desactivar los scripts de instalación, (4) corregir la dependencia y fijar
versiones, y (5) instalar limpio.

## Paso 1 · ¿Qué dependencias hay?

:::pista Cómo hacerlo
```bash
cd /srv/app
cat package.json .npmrc
```
**Qué deberías ver:** entre las dependencias, `color-utilz`. El paquete
conocido se llama `color-utils`. Y `.npmrc` apunta al registro interno.
:::

## Paso 2 · Inspecciona sin instalar

**Pregúntate:** ¿cómo ves los scripts, el autor y la antigüedad de un paquete
sin ejecutar nada?

:::pista Cómo hacerlo
```bash
npm view color-utilz scripts author time
npm view color-utils scripts author time
```
`npm view <paquete> <campos>` consulta los metadatos del registro: no
descarga ni ejecuta nada.

**Qué deberías ver:** `color-utilz` publicado hace poco, por un autor
desconocido, con un `postinstall` que no tiene nada que ver con colores.
`color-utils`, con historial y sin scripts. Para leer el código sin
instalarlo:
```bash
cd /tmp && npm pack color-utilz && tar -tzf color-utilz-*.tgz
tar -xzOf color-utilz-*.tgz package/package.json
cd /srv/app
```
`npm pack` descarga el paquete como `.tgz` sin ejecutar sus scripts. `tar -t`
lista su contenido y `tar -xO` extrae un fichero a la pantalla (`-O`) en vez de
al disco.

Apúntalo:
```bash
printf 'paquete_malicioso=color-utilz\nscript=postinstall\nlegitimo=color-utils\n' > ~/npm.txt
```
:::

## Paso 3 · Que no se ejecuten scripts

:::pista Cómo hacerlo
```bash
echo 'ignore-scripts=true' >> /srv/app/.npmrc
npm config get ignore-scripts
```
Con `ignore-scripts=true` en el `.npmrc` del proyecto, npm no ejecuta ningún
script de instalación en este proyecto, sea quien sea quien lo instale.

**Qué deberías ver:** `true`.
:::

## Paso 4 · La dependencia correcta, con versiones fijadas

**Pregúntate:** ¿qué fichero fija la versión exacta y el hash de cada paquete?

:::pista Cómo hacerlo
```bash
npm pkg delete dependencies.color-utilz
npm pkg set 'dependencies.color-utils=^2.1.0'
npm install --package-lock-only
grep -c color-utilz package-lock.json
```
- `npm pkg delete` / `npm pkg set` editan `package.json` sin abrirlo.
- `^2.1.0` admite cualquier 2.x a partir de 2.1.0.
- `--package-lock-only` genera `package-lock.json` sin descargar ni instalar.
  El lockfile fija la versión **exacta** de cada paquete (también de las
  dependencias de las dependencias) y su hash `integrity`.

**Qué deberías ver:** `0`: el paquete malicioso no aparece en el lockfile.
:::

## Paso 5 · Instalación limpia

**Pregúntate:** ¿por qué `npm ci` y no `npm install`?

:::pista Cómo hacerlo
```bash
rm -rf node_modules
npm ci
node index.js
bash /opt/lab/check.sh
```
`npm ci` instala **exactamente** lo que dice el lockfile, comprueba el hash de
cada paquete y falla si `package.json` y el lockfile no coinciden.
`npm install` puede actualizar el lockfile por su cuenta.
:::

## Cómo actuar en una situación así

- Si el `postinstall` llegó a ejecutarse, trata la máquina como comprometida:
  busca sus restos (aquí, `/tmp/.color-cache`) y **rota** el token de
  `~/.npmrc`.
- `ignore-scripts` por defecto, y una lista blanca de los paquetes que de
  verdad necesitan scripts.
- `npm ci` en la CI, y revisa los cambios del lockfile en cada pull request.

## Si te atascas

- **`npm ci` falla:** el lockfile no coincide con `package.json`. Regenéralo con
  `npm install --package-lock-only`.
- **`npm view` no responde:** ejecútalo desde `/srv/app`, cuyo `.npmrc` apunta
  al registro interno.
