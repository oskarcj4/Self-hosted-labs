# Pipeline full stack: Java

> DevOps · CI/CD · Gitea Actions · Spring Boot · Maven · repositorio de artefactos

## Escenario

El servicio de precios (**Spring Boot 3**, con su frontend estático dentro del
mismo jar) tiene el pipeline **en rojo desde hace una semana**. Como "no da
tiempo", alguien compila el jar en su portátil con `-DskipTests` y lo sube a
producción a mano. Y llegan quejas: *"la calculadora no suma el IVA"*.

El servidor de CI:

- **no tiene internet**: Maven no puede ir a Maven Central. Hay un repositorio
  interno en `http://localhost:8081/` (hace de Nexus/Artifactory);
- tiene el JDK que dice `java -version`, y el `pom.xml` pide otro;
- ejecuta un workflow que se salta los tests y despliega desde cualquier rama.

Forja: <http://localhost:4215> (`analista` / `analista123`) · App: <http://localhost:8215>

## Objetivos

1. Pipeline de `main` en verde.
2. Maven descarga todo del repositorio interno (configuración versionada en el repo).
3. El `pom.xml` compila para el JDK del servidor.
4. Todos los tests se ejecutan en el pipeline, sin fallos.
5. Sólo se despliega un jar que pasó los tests, y sólo desde `main`.
6. Producción corre el commit de `main` (no el jar del portátil) y calcula bien el IVA.

## Pistas

```bash
cat ~/TAREA.txt
ci-log | grep -E 'ERROR|BUILD|Tests run' | head
curl -s localhost:8081/ | head          # el repositorio interno
mvn -v; java -version
cat ~/precios/.github/workflows/ci.yml
```

Maven lee la configuración de mirrors de un `settings.xml`; puedes versionarlo
en el repo y pasárselo con `-s`.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
