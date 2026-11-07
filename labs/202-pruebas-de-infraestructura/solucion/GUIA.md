# Resolución guiada · Lab 202

:::piensa ¿Qué promete el módulo?
Lee `variables.tf` y `main.tf` como si fueran una especificación. Cada
validación es una promesa ("rechazo X") y cada salida otra ("genero Y").
Una buena prueba rompe en cuanto se rompe una promesa, y sólo entonces.
:::

## Paso 1 · El bug

:::pista Dónde
`locals.puertos` usa `8080 + i`. Debe ser `var.puerto + i`.
:::

## Paso 2 · Pruebas de salida

:::pista Cómo
```hcl
run "una_replica_por_puerto" {
  command = plan
  variables { nombre = "pagos", puerto = 7000, entorno = "prod", replicas = 3 }
  assert {
    condition     = strcontains(output.nginx_conf, "server 127.0.0.1:7001;")
    error_message = "réplica i en puerto + i"
  }
}
```
Comprueba también el `server_name` y el `.env` completo. Comparar el `.env`
entero con `==` detecta cualquier línea que falte.
:::

## Paso 3 · Pruebas de rechazo

:::pista Cómo
`expect_failures = [var.puerto]` hace que el `run` pase sólo si esa
validación falla. Prueba los dos lados del rango (80 y 70000), prod con 1
réplica y nombres con mayúsculas o que empiezan por número. Añade también
casos que **deben aceptarse** (puerto 1024, dev con 1 réplica): una
validación demasiado estricta también es un bug.
:::

## Paso 4 · ¿Detectan los mutantes?

:::pista Cómo comprobarlo tú
Rompe el módulo a mano (por ejemplo, `var.puerto + i` → `var.puerto`),
ejecuta `terraform test` y comprueba que falla. Deshaz el cambio. Si sigue
en verde, te falta una prueba.
:::

## Cómo actuar en una situación así

- Prueba los módulos en su propio directorio. La raíz que los usa se valida con `plan` en CI.
- `command = apply` con proveedores reales sirve para integración (más lento y con coste). `plan` sirve para la lógica.
- Fuera de Terraform se usan Terratest (Go), checkov o tflint. Cada uno cubre otra capa.
