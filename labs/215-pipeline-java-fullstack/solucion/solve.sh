#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cd ~/precios
git pull -q

# 1. Maven contra el repositorio interno: settings.xml versionado en el repo.
mkdir -p .mvn
cat > .mvn/settings.xml <<'XML'
<settings>
  <mirrors>
    <mirror>
      <id>interno</id>
      <name>Repositorio interno (mirror de Maven Central)</name>
      <mirrorOf>*</mirrorOf>
      <url>http://localhost:8081/</url>
    </mirror>
  </mirrors>
</settings>
XML

# 2. Java del pom = JDK del servidor.
sed -i 's#<java.version>21</java.version>#<java.version>17</java.version>#' pom.xml

# 3. El bug que escondía -DskipTests: iva / 100 es división entera (21 / 100 = 0).
python3 - <<'PY'
p = "src/main/java/com/empresa/precios/Calculadora.java"
s = open(p).read()
s = s.replace("import java.util.Locale;", "import java.math.BigDecimal;\nimport java.math.RoundingMode;")
s = s.replace('''        double total = base * (1 + iva / 100);
        return String.format(Locale.ROOT, "%.2f", total);''',
'''        return BigDecimal.valueOf(base)
                .multiply(BigDecimal.valueOf(100L + iva))
                .divide(BigDecimal.valueOf(100), 2, RoundingMode.HALF_UP)
                .toPlainString();''')
open(p, "w").write(s)
PY

# 4. Workflow: verify (compila + todos los tests) y despliegue sólo desde main.
cat > .github/workflows/ci.yml <<'YML'
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
YML
git add -A
git commit -qm "ci: repo Maven interno, Java 17, tests y despliegue sólo desde main; fix IVA"
git push -q origin main

SHA=$(git rev-parse HEAD)
echo "Esperando al pipeline de ${SHA:0:8}..."
for _ in $(seq 1 240); do
  curl -fs http://127.0.0.1:8080/api/version | grep -q "$SHA" && break
  sleep 2
done
ci-estado
echo "solve.sh completado."
