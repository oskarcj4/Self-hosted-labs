# Pruebas de infraestructura

> Terraform · `terraform test` · contratos de módulo · `expect_failures` · pruebas de mutación · CI

## Escenario

`~/infra/modules/servicio` genera la configuración de nginx y el `.env` de
cada servicio de la tienda. Lo usan todos y no tiene **ni una prueba**. Ya
ha llegado a producción un bug: los `upstream` de nginx apuntan siempre a
8080, 8081… en vez de al puerto de cada servicio. Nadie lo vio en la
revisión.

Desde la versión 1.6, Terraform trae su propio marco de pruebas:
`terraform test` ejecuta ficheros `*.tftest.hcl` con bloques `run` que
planifican (o aplican) el módulo con distintas variables y comprueban
`assert` sobre el resultado, o que una validación **falla** cuando debe
(`expect_failures`).

## Objetivos

1. Arreglar el bug, sin reestructurar el módulo.
2. Pruebas en `modules/servicio/tests/` que cubran el contrato completo. La lista está en `~/TAREA.txt`.
3. El check mete fallos a propósito (mutantes) y tus pruebas deben detectar todos.
4. `~/infra/ci/test.sh` con fmt, init, validate y test, que falle si algo falla.
5. Commit.

## Pistas

```bash
cd ~/infra/modules/servicio
terraform test
terraform console     # prueba expresiones: strcontains(...), regexall(...)
```

Un `run` con `command = plan` no crea nada en disco. Los `variables {}` de
nivel superior valen para todos los `run` del fichero.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
