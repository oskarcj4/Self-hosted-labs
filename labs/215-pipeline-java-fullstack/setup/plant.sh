#!/usr/bin/env bash
# Lab 215: pipeline full stack Java (Spring Boot + front estático) en Gitea Actions.
# Plantado: forja y runner funcionando, repositorio Maven interno en :8081 ("Nexus").
# El pipeline lleva una semana en rojo y se despliega a mano:
#  - Maven intenta ir a Maven Central (no hay internet; falta el mirror interno);
#  - el pom pide Java 21 y el servidor de CI tiene JDK 17;
#  - los tests se saltan (-DskipTests) y esconden un bug de redondeo del IVA;
#  - despliega desde cualquier rama.
set -e
export HOME=/root
echo GITEA_PORT=4215 > /opt/lab/forja.env
source /opt/lab/setup/forja.sh
install -m 0644 /opt/lab/setup/forja.sh /opt/lab/forja.sh
install -m 0644 /opt/lab/setup/wf.py /opt/lab/wf.py
install -m 0755 /opt/lab/setup/ci-estado /opt/lab/setup/ci-log /usr/local/bin/
echo precios > /opt/lab/.repo-defecto

# --- Repositorio Maven interno (hace de Nexus/Artifactory) ---------------------
cat > /etc/systemd/system/repo-interno.service <<'U'
[Unit]
Description=Repositorio Maven interno (mirror de Maven Central)
After=network.target
[Service]
ExecStart=/usr/bin/python3 -m http.server 8081 --bind 127.0.0.1 --directory /opt/m2repo
Restart=always
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload
systemctl enable --now repo-interno

# --- Forja y runner ------------------------------------------------------------
forja_gitea true self
forja_espejo_checkout
forja_runner self-hosted:host
forja_sin_internet   # desde aquí, nada sale a internet

# --- Producción ----------------------------------------------------------------
id precios >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin precios
mkdir -p /srv/precios/releases
cat > /etc/systemd/system/precios.service <<'U'
[Unit]
Description=Servicio de precios (Spring Boot)
After=network.target
[Service]
User=precios
EnvironmentFile=/srv/precios/current.env
ExecStart=/usr/bin/java -Xmx256m -jar /srv/precios/current.jar --server.port=8000 --server.address=127.0.0.1
Restart=always
[Install]
WantedBy=multi-user.target
U
cat > /usr/local/bin/desplegar-precios <<'SH'
#!/usr/bin/env bash
# desplegar-precios JAR SHA — instala el jar como release SHA, cambia current.jar de
# forma atómica, reinicia y espera a que /api/version devuelva el SHA.
# El pipeline lo llama con sudo (regla en /etc/sudoers.d/act-runner).
set -euo pipefail
JAR=$1; SHA=$2
[[ $SHA =~ ^([0-9a-f]{40}|manual-[a-z0-9]+)$ ]] || { echo "SHA no válido: $SHA"; exit 2; }
[ -f "$JAR" ] || { echo "no existe el jar: $JAR"; exit 2; }
[ "$(unzip -Z1 "$JAR" | grep -c '^BOOT-INF/')" -gt 0 ] || { echo "$JAR no es un jar ejecutable de Spring Boot"; exit 2; }
install -m 0644 "$JAR" "/srv/precios/releases/$SHA.jar"
ln -sfn "/srv/precios/releases/$SHA.jar" /srv/precios/.current.tmp && mv -T /srv/precios/.current.tmp /srv/precios/current.jar
echo "APP_COMMIT=$SHA" > /srv/precios/current.env
systemctl restart precios
for _ in $(seq 1 90); do
  if curl -fs http://127.0.0.1:8000/api/version | grep -q "$SHA"; then
    echo "desplegado $SHA"
    ls -1t /srv/precios/releases/*.jar | tail -n +6 | xargs -r rm -f
    exit 0
  fi
  sleep 1
done
echo "la versión $SHA no responde"; journalctl -u precios -n 30 --no-pager; exit 1
SH
chmod 755 /usr/local/bin/desplegar-precios
echo 'act-runner ALL=(root) NOPASSWD: /usr/local/bin/desplegar-precios' > /etc/sudoers.d/act-runner
chmod 440 /etc/sudoers.d/act-runner
cat > /etc/nginx/sites-available/default <<'NG'
server {
    listen 8080 default_server;
    location / { proxy_pass http://127.0.0.1:8000; }
}
NG
systemctl enable precios >/dev/null 2>&1
systemctl enable --now nginx

# --- Repo analista/precios -------------------------------------------------------
R=/tmp/precios
P=$R/src/main/java/com/empresa/precios
T=$R/src/test/java/com/empresa/precios
mkdir -p $P $T $R/src/main/resources/static $R/.github/workflows
sed 's#<java.version>17</java.version>#<java.version>21</java.version>#' /opt/m2-plantilla/pom.xml > $R/pom.xml
cp /opt/m2-plantilla/src/main/java/com/empresa/precios/App.java $P/
cat > $P/Calculadora.java <<'JAVA'
package com.empresa.precios;

import java.util.Locale;

/** Cálculo de precios finales. */
public final class Calculadora {
    private Calculadora() {}

    /** Precio final con IVA (en %), redondeado a céntimos, como texto ("24.19"). */
    public static String total(double base, int iva) {
        double total = base * (1 + iva / 100);
        return String.format(Locale.ROOT, "%.2f", total);
    }
}
JAVA
cat > $P/PreciosController.java <<'JAVA'
package com.empresa.precios;

import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class PreciosController {

    @Value("${APP_COMMIT:dev}")
    private String commit;

    @GetMapping("/version")
    public Map<String, String> version() {
        return Map.of("version", commit);
    }

    @GetMapping("/precio")
    public Map<String, Object> precio(@RequestParam double base, @RequestParam(defaultValue = "21") int iva) {
        return Map.of("base", base, "iva", iva, "total", Calculadora.total(base, iva));
    }
}
JAVA
cp /opt/m2-plantilla/src/test/java/com/empresa/precios/AppTest.java $T/
cat > $T/CalculadoraTest.java <<'JAVA'
package com.empresa.precios;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class CalculadoraTest {

    @Test
    void ivaGeneral() {
        assertEquals("24.19", Calculadora.total(19.99, 21));
    }

    @Test
    void ivaReducido() {
        assertEquals("110.00", Calculadora.total(100, 10));
    }

    @Test
    void sinIva() {
        assertEquals("5.50", Calculadora.total(5.5, 0));
    }
}
JAVA
cat > $T/PreciosControllerTest.java <<'JAVA'
package com.empresa.precios;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(PreciosController.class)
class PreciosControllerTest {

    @Autowired
    MockMvc mvc;

    @Test
    void precioConIva() throws Exception {
        mvc.perform(get("/api/precio").param("base", "10").param("iva", "21"))
           .andExpect(status().isOk())
           .andExpect(jsonPath("$.total").value("12.10"));
    }
}
JAVA
cat > $R/src/main/resources/application.properties <<'PROP'
spring.application.name=precios
management.endpoints.web.exposure.include=health
PROP
cat > $R/src/main/resources/static/index.html <<'HTML'
<!doctype html>
<html lang="es">
<head><meta charset="utf-8"><title>Calculadora de precios</title></head>
<body>
  <h1>Calculadora de precios</h1>
  <form id="f">
    <input name="base" type="number" step="0.01" value="19.99">
    <select name="iva"><option>21</option><option>10</option><option>4</option><option>0</option></select>
    <button>Calcular</button>
  </form>
  <p>Total: <strong id="total">-</strong></p>
  <footer>versión <span id="version">?</span></footer>
  <script>
    const f = document.getElementById('f');
    f.addEventListener('submit', async (e) => {
      e.preventDefault();
      const q = new URLSearchParams(new FormData(f));
      const r = await fetch('/api/precio?' + q).then((r) => r.json());
      document.getElementById('total').textContent = r.total + ' €';
    });
    fetch('/api/version').then((r) => r.json()).then((v) => {
      document.getElementById('version').textContent = v.version.slice(0, 8);
    });
  </script>
</body>
</html>
HTML
printf 'target/\n*.class\n.idea/\n' > $R/.gitignore
cat > $R/.github/workflows/ci.yml <<'YML'
name: ci
on: push

jobs:
  build:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4

      - name: Compilar
        run: mvn -B package -DskipTests   # los tests "tardan mucho"

      - name: Desplegar
        run: sudo /usr/local/bin/desplegar-precios target/precios-*.jar "${{ github.sha }}"
YML
cat > $R/README.md <<'MD'
# precios

Spring Boot 3 (Java) + frontend estático en `src/main/resources/static`.
Un solo artefacto: `target/precios-<versión>.jar`.

Despliegue: `sudo desplegar-precios <jar> <sha>` (lo hace el pipeline).
MD
forja_repo precios $R "precios: API, frontend y pipeline" "$(date -d '-8 days' -Iseconds)"
SHA=$(git -C $R rev-parse HEAD)
echo "Primer pipeline (debe fallar): $(forja_espera_sha precios "$SHA" 300)"

# Lo que hay en producción: compilado "a mano" en un portátil, sin tests.
mkdir -p /tmp/m2-manual
printf '<settings><localRepository>/tmp/m2-manual/repo</localRepository><mirrors><mirror><id>interno</id><mirrorOf>*</mirrorOf><url>http://localhost:8081/</url></mirror></mirrors></settings>\n' > /tmp/m2-manual/settings.xml
sed -i 's#<java.version>21</java.version>#<java.version>17</java.version>#' $R/pom.xml
( cd $R && mvn -B -q -s /tmp/m2-manual/settings.xml package -DskipTests )
/usr/local/bin/desplegar-precios $R/target/precios-1.4.0.jar manual-portatil
rm -rf $R /tmp/m2-manual

runuser -u analista -- git clone -q "$GITEA_URL/analista/precios.git" /home/analista/precios
runuser -u analista -- git -C /home/analista/precios config user.name analista
runuser -u analista -- git -C /home/analista/precios config user.email analista@empresa.local
printf 'machine localhost login analista password analista123\n' > /home/analista/.netrc
chown analista:analista /home/analista/.netrc && chmod 600 /home/analista/.netrc

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Pipeline full stack (Java)

El pipeline de ~/precios lleva una semana en rojo. Mientras, alguien compila
el jar en su portátil, sin tests, y lo sube a mano. Y hay quejas de clientes:
"la calculadora no suma el IVA" (http://localhost:8080 en el servidor).

Datos:
  - El servidor de CI no tiene internet. Maven debe bajar todo del repositorio
    interno: http://localhost:8081/  (un mirror de Maven Central, como Nexus).
  - JDK del servidor de CI y de producción: el que diga `java -version`.
  - Despliegue: sudo /usr/local/bin/desplegar-precios <jar> <sha>.

Objetivo: pipeline en verde que compila, pasa TODOS los tests, y despliega
sólo desde main; producción corre el commit de main y calcula bien el IVA.

Ayudas: ci-estado, ci-log [nº], journalctl -u precios
Comprueba: bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 215 plantado."
