# Resolución guiada · Lab 215

:::piensa ¿Por qué el pipeline lleva una semana en rojo?
Lee el primer error, no el último. Maven falla pronto: o no llega a un
repositorio, o el compilador no acepta la versión de Java. Arréglalos de uno
en uno: cada arreglo destapa el siguiente.
:::

## Paso 1 · El repositorio de artefactos

:::pista Cómo hacerlo
Sin internet, Maven tiene que ir al mirror interno para **todo** (`mirrorOf *`):
```xml
<!-- .mvn/settings.xml -->
<settings>
  <mirrors>
    <mirror>
      <id>interno</id>
      <mirrorOf>*</mirrorOf>
      <url>http://localhost:8081/</url>
    </mirror>
  </mirrors>
</settings>
```
y `mvn -B -s .mvn/settings.xml ...` en el workflow. En el log verás
`Downloading from interno: http://localhost:8081/...`.
:::

## Paso 2 · La versión de Java

:::pista Cómo hacerlo
`error: release version 21 not supported`: el servidor tiene JDK 17.
`<java.version>17</java.version>` en el pom. (La otra opción, instalar JDK 21
en el CI y en producción, también es válida en la vida real: lo importante es
que coincidan.)
:::

## Paso 3 · Los tests

:::piensa ¿Por qué alguien añadió -DskipTests?
Porque fallaban. Quítalo y mira cuál falla: `CalculadoraTest.ivaGeneral`
espera `24.19` y recibe `19.99`.
:::

:::pista Cómo hacerlo
`iva / 100` con `iva` entero es **división entera**: `21 / 100 = 0`. Usa
`BigDecimal` para dinero:
```java
return BigDecimal.valueOf(base)
        .multiply(BigDecimal.valueOf(100L + iva))
        .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP)
        .toPlainString();
```
Y en el workflow, `mvn verify` (compila, pasa los tests y empaqueta).
:::

## Paso 4 · Desplegar sólo lo probado, sólo desde main

:::pista Cómo hacerlo
```yaml
on:
  push:
    branches: [main]
  pull_request:
jobs:
  build:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - run: mvn -B -s .mvn/settings.xml verify
      - if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        run: sudo /usr/local/bin/desplegar-precios target/precios-*.jar "${{ github.sha }}"
```
:::

## Cómo actuar en una situación así

- Un pipeline en rojo "temporalmente" acaba en despliegues a mano: arréglalo antes que nada.
- Nunca despliegues un artefacto compilado fuera de la CI: no sabes qué lleva.
- `-DskipTests` para "ir más rápido" esconde exactamente los bugs que llegan a clientes.
