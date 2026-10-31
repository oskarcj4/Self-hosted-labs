# Solución — Cadena de suministro npm

## Qué pasaba

`package.json` dependía de `color-utilz` (typosquat de `color-utils`) publicado
en el registro interno, con un `postinstall` que escribe `/tmp/.color-cache`.
Sin `ignore-scripts` ni lockfile, cada `npm install` lo ejecutaba.

## Arreglo

```bash
cd /srv/app
npm view color-utilz scripts author time
npm view color-utils
printf 'paquete_malicioso=color-utilz\nscript=postinstall\nlegitimo=color-utils\n' > ~/npm.txt
echo 'ignore-scripts=true' >> .npmrc
npm pkg delete dependencies.color-utilz
npm pkg set 'dependencies.color-utils=^2.1.0'
npm install --package-lock-only
rm -rf node_modules
npm ci
node index.js
bash /opt/lab/check.sh
```

## Más allá del lab

- Herramientas como Socket o `npm audit signatures` detectan scripts y paquetes sospechosos.
- Usa un proxy de registro (Verdaccio, Artifactory) con lista de paquetes aprobados.
- Si el script llegó a ejecutarse, rota los secretos accesibles desde esa máquina.
