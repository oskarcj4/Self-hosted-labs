# Runner de CI propio

> DevSecOps · CI · self-hosted runners · aislamiento · sandbox de systemd

## Escenario

Para no pagar minutos de CI, la empresa instaló su propio runner en un
servidor. Funciona... y ejecuta **el código de cualquier pull request**,
también de forks de desconocidos. Un PR malicioso es código arbitrario
corriendo en tu servidor, con lo que el runner le dé:

- corre como **root**;
- el job hereda el entorno del runner, con el **token del registro**;
- todos los jobs comparten directorio: lo que deja uno lo ve el siguiente;
- puede leer `/home` y dejar cosas en el `/tmp` del servidor;
- sin límite de tiempo: un minero de criptomonedas puede quedarse corriendo para siempre;
- acepta trabajos con cualquier etiqueta.

Así se han comprometido runners reales: un PR de un fork, un job que
lee secretos o deja persistencia, y el siguiente job de `main` ya corre
contaminado.

## Objetivos

1. Usuario de sistema `ci-runner`.
2. Espacio de trabajo **efímero** por job.
3. Sin herencia de entorno, y el token en un fichero `0600` (`EnvironmentFile`), no en la unidad.
4. Timeout ≤ 60 s, que mata también los procesos hijos.
5. Sólo etiquetas `linux` y `x64`.
6. Sandbox: `NoNewPrivileges`, `PrivateTmp`, `ProtectSystem`, `ProtectHome` y `MemoryMax`.

## Pistas

```bash
cat /etc/runner/runner.ini; sed -n 1,20p /opt/runner/runner.py
ci-job 'id; env; pwd; ls -la'          # manda un job y muestra el resultado
journalctl -u runner -f
systemd-analyze security runner        # puntuación de exposición de la unidad
```

`ProtectSystem=strict` deja todo en sólo lectura: el runner necesita
`ReadWritePaths=` para su directorio.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
