# Solución — Pipeline full stack: Java

## Qué fallaba y cómo se arregla

| Problema | Síntoma en el log | Arreglo |
|----------|-------------------|---------|
| Sin internet, Maven va a Central | `Could not transfer artifact ... repo.maven.apache.org` | `.mvn/settings.xml` con mirror `*` a `http://localhost:8081/`, y `mvn -s` |
| pom con Java 21, JDK 17 | `release version 21 not supported` | `<java.version>17</java.version>` |
| `-DskipTests` | `Tests are skipped.` | `mvn verify` |
| División entera en el IVA | `expected: <24.19> but was: <19.99>` | `BigDecimal` con `RoundingMode.HALF_UP` |
| Despliegue desde cualquier rama | — | `on.push.branches: [main]` o `if:` en el paso |
| Jar del portátil en producción | `/api/version` = `manual-portatil` | dejar que despliegue el pipeline |

El workflow y los cambios completos están en `solve.sh`.

## Por qué así

- **Mirror `*`**: también los plugins de Maven (surefire, compiler, spring-boot)
  vienen de un repositorio. Con `mirrorOf` en `central` sólo, los plugins de
  otros repositorios seguirían saliendo a internet.
- **`settings.xml` en el repo**: cualquier runner nuevo compila igual, sin
  configuración a mano en su `~/.m2`. Si el repositorio interno pidiera
  credenciales, irían en secretos (`${env.NEXUS_PASS}` en el settings).
- **`verify`, no `package -DskipTests`**: el jar que se despliega es el mismo
  que pasó los tests, en el mismo job.
- **`BigDecimal` para dinero**: `double` no representa exactamente los
  céntimos; y la división entera ni siquiera llega a ser un `double`.

## Más allá del lab

- Repositorio de artefactos de verdad: Nexus o Artifactory (proxy de Central, y
  también donde publicar tus propios jars con `mvn deploy`).
- Caché de `~/.m2` entre ejecuciones (aquí ya persiste porque el runner es fijo).
- Informes de JUnit visibles en la forja, y cobertura con JaCoCo.
- Versión del jar con el SHA (`-Drevision=`) y *tags* para releases (lab 182).
