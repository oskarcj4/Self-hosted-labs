# Resolución guiada · Lab 215

:::piensa ¿Por qué el pipeline lleva una semana en rojo?
Lee el **primer** error, no el último. Maven se para en cuanto algo falla, así
que cada arreglo destapa el siguiente problema: primero no llega a sus
dependencias, luego el compilador no acepta la versión de Java, luego fallan
los tests que alguien estaba saltándose. Arréglalos de uno en uno, en orden.
:::

**El plan:** (1) leer el log del pipeline, (2) apuntar Maven al repositorio
interno, (3) alinear la versión de Java, (4) arreglar el bug que escondían los
tests, (5) reescribir el workflow y (6) subirlo y ver el pipeline en verde.

## Paso 1 · Lee el log del pipeline

**Objetivo:** saber exactamente qué falla, en lugar de suponerlo.

:::pista Cómo hacerlo
```bash
cd ~/precios
ci-estado
ci-log | grep -E 'ERROR|BUILD|Tests run' | head
```
`ci-estado` y `ci-log` son comandos del lab: el primero lista las últimas
ejecuciones del pipeline; el segundo imprime el log de la última (o de la que
le digas por número). El `grep -E` filtra las líneas que importan en un log
de Maven: errores, el resultado final (`BUILD SUCCESS`/`BUILD FAILURE`) y el
resumen de tests.

**Qué deberías ver:** `Could not transfer artifact … from/to central
(https://repo.maven.apache.org/…)`. Maven intenta descargar de Internet, y
este servidor no tiene salida.
:::

## Paso 2 · Maven contra el repositorio interno

**Objetivo:** que Maven descargue **todo** (dependencias y plugins) de
`http://localhost:8081/`, y que esa configuración viaje con el repositorio.

**Pregúntate:** ¿dónde lee Maven a qué servidor ir? ¿Cómo haces que cualquier
runner nuevo use la misma configuración sin tocar nada a mano?

:::pista Cómo hacerlo
Maven lee la lista de repositorios del `pom.xml` y de un fichero de
configuración, `settings.xml`. Un **mirror** dice: "cuando vayas a tal
repositorio, ve a este otro en su lugar". Créalo **dentro del repo**:
```bash
mkdir -p .mvn
cat > .mvn/settings.xml <<'EOF'
<settings>
  <mirrors>
    <mirror>
      <id>interno</id>
      <mirrorOf>*</mirrorOf>
      <url>http://localhost:8081/</url>
    </mirror>
  </mirrors>
</settings>
EOF
```

| Elemento | Qué significa |
|---|---|
| `<id>interno</id>` | Nombre del mirror. Aparece en el log: `Downloading from interno: …`. |
| `<mirrorOf>*</mirrorOf>` | Sustituye a **todos** los repositorios, no sólo a Maven Central. Los plugins (compilador, tests, empaquetado) también se descargan, y si alguno viniera de otro repositorio seguiría intentando salir a Internet. |
| `<url>` | A dónde ir en su lugar: el repositorio interno, que hace de Nexus/Artifactory. |

Maven **no** lee `.mvn/settings.xml` por su cuenta: hay que pasárselo con
`-s .mvn/settings.xml`. Pruébalo en local antes de tocar el pipeline:
```bash
mvn -B -s .mvn/settings.xml validate | grep -E 'Downloading from|BUILD'
```
`-B` (*batch mode*) quita colores y barras de progreso: es lo que se usa en
CI. `validate` es la fase más corta de Maven: sólo comprueba el proyecto, pero
para eso ya necesita descargar el `pom` padre de Spring Boot.

**Qué deberías ver:** `Downloading from interno: http://localhost:8081/…` (o
nada, si ya estaba en la caché local) y `BUILD SUCCESS`. Sin el `-s`, el mismo
comando falla buscando `repo.maven.apache.org`.
:::

## Paso 3 · La versión de Java

**Objetivo:** que el proyecto compile con el JDK que hay en el servidor.

:::pista Cómo hacerlo
```bash
java -version
grep -n 'java.version' pom.xml
```
**Qué deberías ver:** el servidor tiene **JDK 17** y el `pom.xml` pide 21.
Compilar para Java 21 con un JDK 17 es imposible: el compilador no conoce
esa versión (`release version 21 not supported`).

Cambia en `pom.xml`:
```xml
<java.version>17</java.version>
```
En un proyecto Spring Boot, la propiedad `java.version` la usa el plugin del
compilador para decidir para qué versión genera el código. (La alternativa,
instalar JDK 21 en CI y en producción, también es válida en la vida real: lo
que importa es que coincidan.)
:::

## Paso 4 · El bug que escondía `-DskipTests`

**Objetivo:** que pasen **todos** los tests, arreglando el código, no los tests.

**Pregúntate:** ¿por qué alguien añadió `-DskipTests` al pipeline?

:::pista Cómo hacerlo
Porque fallaban. Ejecútalos en local:
```bash
mvn -B -s .mvn/settings.xml test 2>&1 | grep -E 'Tests run|expected'
```
`2>&1` junta los errores con la salida normal para que el `grep` los vea
también. **Qué deberías ver:** `CalculadoraTest.ivaGeneral` espera `24.19` y
recibe `19.99`: no se suma el IVA. Mira el código:
```bash
cat src/main/java/com/empresa/precios/Calculadora.java
```
```java
double total = base * (1 + iva / 100);
```
`iva` es un `int`, y en Java `int / int` es **división entera**: `21 / 100`
da `0`, no `0.21`. El total queda en `base * 1`.

Para dinero, además, no se usa `double` (no representa exactamente los
céntimos). Se usa `BigDecimal`. Deja el fichero así:
```java
package com.empresa.precios;

import java.math.BigDecimal;
import java.math.RoundingMode;

/** Cálculo de precios finales. */
public final class Calculadora {
    private Calculadora() {}

    /** Precio final con IVA (en %), redondeado a céntimos, como texto ("24.19"). */
    public static String total(double base, int iva) {
        return BigDecimal.valueOf(base)
                .multiply(BigDecimal.valueOf(100L + iva))
                .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP)
                .toPlainString();
    }
}
```
- Los dos `import` son imprescindibles: sin ellos, `cannot find symbol
  BigDecimal`.
- La cuenta es `base × (100 + iva) / 100`: multiplicar antes de dividir evita
  la división entera.
- `.divide(…, 2, RoundingMode.HALF_UP)`: divide dejando 2 decimales y
  redondeando "como en el colegio" (0,005 sube).
- `toPlainString()` devuelve `"24.19"` sin notación científica.

```bash
mvn -B -s .mvn/settings.xml test 2>&1 | grep -E 'Tests run:|BUILD'
```
**Qué deberías ver:** `Tests run: 5, Failures: 0, Errors: 0` y `BUILD SUCCESS`.
:::

## Paso 5 · El workflow: probar siempre, desplegar sólo desde main

**Objetivo:** que el pipeline compile y pase los tests en cada push, y que
sólo despliegue lo que viene de `main` y ha pasado los tests.

:::pista Cómo hacerlo
Sustituye `.github/workflows/ci.yml` por:
```yaml
name: ci
on:
  push:
    branches: [main]
  pull_request:

jobs:
  build:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4

      - name: Compilar y probar
        run: mvn -B -s .mvn/settings.xml verify

      - name: Desplegar
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        run: sudo /usr/local/bin/desplegar-precios target/precios-*.jar "${{ github.sha }}"
```

| Pieza | Qué hace |
|---|---|
| `on: push: branches: [main]` | El pipeline arranca con cada push a `main`. |
| `pull_request:` | Y también con cada pull request, para probar los cambios **antes** de fusionarlos (sin desplegar). |
| `mvn … verify` | Ejecuta las fases de Maven en orden hasta `verify`: compila, pasa los tests, empaqueta el jar y lo verifica. Si un test falla, se para ahí y no hay jar. |
| `if: github.event_name == 'push' && github.ref == 'refs/heads/main'` | El paso de despliegue sólo corre si el evento es un push y la rama es `main`. En un pull request se salta. |
| `${{ github.sha }}` | El commit exacto que se está construyendo. `desplegar-precios` lo usa como versión, y producción lo enseña en `/api/version`. |

Los pasos de un job se ejecutan en orden y, si uno falla, los siguientes no
corren. Por eso basta con que el despliegue vaya **después** de `verify`: nunca
se despliega un jar que no pasó los tests.
:::

## Paso 6 · Súbelo y mira el pipeline

**Objetivo:** que el pipeline corra con tus cambios. Sin `push` no pasa nada:
el pipeline vive en la forja, no en tu carpeta.

:::pista Cómo hacerlo
```bash
git add -A
git status                       # revisa: .mvn/settings.xml, pom.xml, Calculadora.java, ci.yml
git commit -m "ci: repo Maven interno, Java 17, tests y despliegue sólo desde main; fix IVA"
git push origin main
ci-estado                        # repite hasta que acabe (tarda un par de minutos)
```
**Qué deberías ver:** la última ejecución en verde. Y luego:
```bash
curl -s localhost:8080/api/version                        # el SHA de tu commit, no "manual-portatil"
curl -s 'localhost:8080/api/precio?base=19.99&iva=21'     # "total":"24.19"
bash /opt/lab/check.sh
```
Si sale en rojo, `ci-log` y vuelta al paso que toque.
:::

## Cómo actuar en una situación así

- Un pipeline en rojo "temporalmente" acaba en despliegues a mano: arréglalo
  antes que nada.
- Nunca despliegues un artefacto compilado fuera de la CI: no sabes con qué
  código ni con qué dependencias se hizo.
- `-DskipTests` para "ir más rápido" esconde exactamente los bugs que acaban
  llegando a clientes.
- Si el repositorio interno pidiera credenciales, irían en los secretos de la
  forja (`${env.NEXUS_PASS}` en el `settings.xml`), nunca escritas en el repo.

## Si te atascas

- **El log sigue diciendo `repo.maven.apache.org`:** el workflow no pasa
  `-s .mvn/settings.xml`, o el fichero no está en el commit (`git status`).
- **`cannot find symbol BigDecimal`:** faltan los `import`.
- **Pipeline en verde pero `/api/version` sigue en `manual-portatil`:** el
  paso de despliegue no se ejecutó. Revisa la condición `if:` (las comillas y
  `refs/heads/main`) y que empujaste a `main`.
- **`ci-estado` no muestra ejecuciones nuevas:** no has hecho `git push`.
