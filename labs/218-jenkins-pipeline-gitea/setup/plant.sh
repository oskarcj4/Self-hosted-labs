#!/usr/bin/env bash
# Lab 218: Jenkins + Gitea. Jenkins ya está bien montado (JCasC, seguridad, agente),
# pero el job "tienda" es un pipeline pegado en la web de Jenkins:
#  - clona con usuario y contraseña de Gitea EN CLARO en el script;
#  - no hay Jenkinsfile en el repo (el pipeline no se versiona);
#  - nadie lo lanza: no hay webhook, se ejecuta a mano "cuando alguien se acuerda";
#  - no corre los tests (y hay uno que falla: el descuento del carrito).
set -e
export HOME=/root
echo GITEA_PORT=4218 > /opt/lab/forja.env
source /opt/lab/setup/forja.sh
install -m 0644 /opt/lab/setup/forja.sh /opt/lab/forja.sh
J=/var/lib/jenkins
JURL=http://localhost:8080

# --- Gitea (sin Actions: aquí el CI es Jenkins) ------------------------------------
forja_gitea false github
printf '\n[webhook]\nALLOWED_HOST_LIST = loopback\n' >> /etc/gitea/app.ini
systemctl restart gitea && forja_espera

# --- Producción: servicio tienda + script de despliegue -----------------------------
useradd -r -d /srv/tienda -s /usr/sbin/nologin tienda
mkdir -p /srv/tienda/releases
cat > /etc/systemd/system/tienda.service <<'U'
[Unit]
Description=Tienda (API + frontend)
[Service]
User=tienda
WorkingDirectory=/srv/tienda/current
Environment=PORT=9080
ExecStart=/usr/local/bin/node server.js
Restart=always
[Install]
WantedBy=multi-user.target
U
cat > /usr/local/bin/desplegar-tienda <<'SH'
#!/usr/bin/env bash
# desplegar-tienda DIR SHA — publica una build ya hecha (con dist/) de la tienda.
set -euo pipefail
SRC=$1; SHA=$2
[[ $SHA =~ ^[0-9a-f]{40}$ ]] || { echo "SHA no válido: $SHA"; exit 2; }
[ -f "$SRC/dist/index.html" ] || { echo "falta dist/: ¿se ha hecho npm run build?"; exit 2; }
R=/srv/tienda/releases/$SHA
rm -rf "$R"; mkdir -p "$R"
cp -r "$SRC/server.js" "$SRC/package.json" "$SRC/src" "$SRC/dist" "$R/"
echo "$SHA" > "$R/REVISION"
ln -sfn "$R" /srv/tienda/.current.tmp && mv -T /srv/tienda/.current.tmp /srv/tienda/current
systemctl restart tienda
ls -1dt /srv/tienda/releases/*/ | tail -n +6 | xargs -r rm -rf
for _ in $(seq 1 15); do
  curl -fs http://127.0.0.1:9080/api/version | grep -q "$SHA" && { echo "desplegado ${SHA:0:8}"; exit 0; }
  sleep 1
done
echo "la tienda no responde con ${SHA:0:8}"; exit 1
SH
chmod 755 /usr/local/bin/desplegar-tienda
systemctl daemon-reload && systemctl enable tienda

# --- Repo analista/tienda (Node 20, sin dependencias) -----------------------------
R=/tmp/tienda
mkdir -p $R/src $R/public $R/scripts $R/test
cat > $R/package.json <<'JSON'
{
  "name": "tienda",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "node --test",
    "build": "node scripts/build.mjs",
    "start": "node server.js"
  }
}
JSON
cat > $R/src/carrito.js <<'JS'
// Lógica del carrito. items: [{ precio, cantidad }], descuento en % (0-100).
const redondea = (n) => Math.round(n * 100) / 100;

export function subtotal(items) {
  return redondea(items.reduce((s, i) => s + i.precio * i.cantidad, 0));
}

export function total(items, descuento = 0) {
  if (descuento < 0 || descuento > 100) throw new RangeError('descuento fuera de rango');
  return redondea(subtotal(items) * (descuento / 100));
}

// "10x2,5.5x1" -> [{ precio: 10, cantidad: 2 }, { precio: 5.5, cantidad: 1 }]
export function parseItems(texto) {
  return String(texto || '').split(',').filter(Boolean).map((t) => {
    const [precio, cantidad] = t.split('x').map(Number);
    if (!(precio >= 0) || !Number.isInteger(cantidad) || cantidad < 1) throw new RangeError(`item no válido: ${t}`);
    return { precio, cantidad };
  });
}
JS
cat > $R/server.js <<'JS'
import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join } from 'node:path';
import { parseItems, total } from './src/carrito.js';

const raiz = new URL('.', import.meta.url).pathname;
const tipos = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.json': 'application/json' };
const json = (res, codigo, datos) => {
  res.writeHead(codigo, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(datos));
};

http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://x');
  if (url.pathname === '/api/version') {
    const rev = await readFile(join(raiz, 'REVISION'), 'utf8').catch(() => 'desarrollo');
    return json(res, 200, { version: rev.trim() });
  }
  if (url.pathname === '/api/total') {
    try {
      const items = parseItems(url.searchParams.get('items'));
      return json(res, 200, { total: total(items, Number(url.searchParams.get('descuento') || 0)) });
    } catch (e) {
      return json(res, 400, { error: e.message });
    }
  }
  const fichero = url.pathname === '/' ? 'index.html' : url.pathname.slice(1);
  if (fichero.includes('..')) return json(res, 400, { error: 'ruta' });
  try {
    const cuerpo = await readFile(join(raiz, 'dist', fichero));
    res.writeHead(200, { 'Content-Type': tipos[extname(fichero)] || 'application/octet-stream' });
    res.end(cuerpo);
  } catch {
    json(res, 404, { error: 'no encontrado' });
  }
}).listen(Number(process.env.PORT || 9080), () => console.log('tienda escuchando'));
JS
cat > $R/public/index.html <<'HTML'
<!doctype html>
<html lang="es">
<head><meta charset="utf-8"><title>Tienda</title></head>
<body>
  <h1>Tienda · calculadora del carrito</h1>
  <p>Artículos (precio x cantidad, separados por comas): <input id="items" value="20x2,10x1"></p>
  <p>Descuento %: <input id="desc" type="number" value="10" min="0" max="100"> <button id="calc">Calcular</button></p>
  <p>Total: <strong id="total">-</strong></p>
  <p><small>build <span id="build"></span></small></p>
  <script src="app.js"></script>
</body>
</html>
HTML
cat > $R/public/app.js <<'JS'
document.getElementById('calc').addEventListener('click', async () => {
  const q = new URLSearchParams({ items: document.getElementById('items').value, descuento: document.getElementById('desc').value });
  const r = await fetch(`/api/total?${q}`).then((x) => x.json());
  document.getElementById('total').textContent = r.total ?? r.error;
});
fetch('/build.json').then((r) => r.json()).then((b) => { document.getElementById('build').textContent = b.fecha; });
JS
cat > $R/scripts/build.mjs <<'JS'
// "Build" del frontend: copia public/ a dist/ y deja build.json.
import { cpSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
rmSync('dist', { recursive: true, force: true });
mkdirSync('dist');
cpSync('public', 'dist', { recursive: true });
writeFileSync('dist/build.json', JSON.stringify({ fecha: new Date().toISOString() }));
console.log('frontend construido en dist/');
JS
cat > $R/test/carrito.test.js <<'JS'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseItems, subtotal, total } from '../src/carrito.js';

test('subtotal suma precio x cantidad', () => {
  assert.equal(subtotal([{ precio: 10, cantidad: 2 }, { precio: 5.5, cantidad: 1 }]), 25.5);
});
test('total sin descuento es el subtotal', () => {
  assert.equal(total([{ precio: 10, cantidad: 3 }]), 30);
});
test('total con 10% de descuento', () => {
  assert.equal(total([{ precio: 50, cantidad: 2 }], 10), 90);
});
test('descuento fuera de rango', () => {
  assert.throws(() => total([], 120), RangeError);
});
test('parseItems entiende "precio x cantidad"', () => {
  assert.deepEqual(parseItems('10x2,5.5x1'), [{ precio: 10, cantidad: 2 }, { precio: 5.5, cantidad: 1 }]);
});
test('parseItems rechaza cantidades no enteras', () => {
  assert.throws(() => parseItems('10x1.5'), RangeError);
});
JS
printf 'node_modules/\ndist/\ninformes/\n' > $R/.gitignore
cat > $R/README.md <<'MD'
# tienda

API + frontend en Node 20, sin dependencias. `npm test`, `npm run build`, `npm start`.
CI/CD: Jenkins (http://localhost:8218).
MD
forja_repo tienda $R "tienda: API, frontend y tests" "$(date -d '-20 days' -Iseconds)"
rm -rf $R

# --- Jenkins ya bien montado (lo del lab 217): JCasC, seguridad, agente -------------
useradd -r -d $J -s /usr/sbin/nologin jenkins
useradd -r -m -d /var/lib/jenkins-agent -s /usr/sbin/nologin jenkins-agent
echo 'jenkins-agent ALL=(root) NOPASSWD: /usr/local/bin/desplegar-tienda *' > /etc/sudoers.d/jenkins-agent
chmod 440 /etc/sudoers.d/jenkins-agent
mkdir -p /etc/jenkins/secrets $J/plugins $J/jobs/tienda /var/cache/jenkins
printf 'Jenkins-218' > /etc/jenkins/secrets/admin
chown -R root:jenkins /etc/jenkins/secrets
chmod 640 /etc/jenkins/secrets/admin && chmod 750 /etc/jenkins/secrets
cp -r /opt/jenkins/plugins/. $J/plugins/
cat > /etc/jenkins/casc.yaml <<'YML'
jenkins:
  systemMessage: "CI de la empresa. Configuración en /etc/jenkins/casc.yaml."
  numExecutors: 0
  mode: EXCLUSIVE
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: admin
          password: "${readFile:/etc/jenkins/secrets/admin}"
  authorizationStrategy:
    loggedInUsersCanDoAnything:
      allowAnonymousRead: false
  nodes:
    - permanent:
        name: agente-linux
        labelString: linux
        numExecutors: 2
        remoteFS: /var/lib/jenkins-agent
        launcher:
          inbound:
            webSocket: true
        retentionStrategy: always
unclassified:
  location:
    url: http://localhost:8218/
YML
cat > /tmp/tienda.groovy <<'G'
pipeline {
    agent { label 'linux' }
    stages {
        stage('Todo') {
            steps {
                sh '''
                    rm -rf tienda
                    git clone http://analista:analista123@localhost:4218/analista/tienda.git
                    cd tienda
                    npm run build
                    sudo /usr/local/bin/desplegar-tienda "$PWD" "$(git rev-parse HEAD)"
                '''
            }
        }
    }
}
G
cat > $J/jobs/tienda/config.xml <<XML
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <description>Despliega la tienda. Lanzar a mano después de cada merge.</description>
  <keepDependencies>false</keepDependencies>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps">
    <script>$(sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g' /tmp/tienda.groovy)</script>
    <sandbox>true</sandbox>
  </definition>
  <disabled>false</disabled>
</flow-definition>
XML
rm -f /tmp/tienda.groovy
echo 2.580.2 > $J/jenkins.install.UpgradeWizard.state
echo 2.580.2 > $J/jenkins.install.InstallUtil.lastExecVersion
chown -R jenkins:jenkins $J /var/cache/jenkins
cat > /etc/systemd/system/jenkins.service <<'U'
[Unit]
Description=Jenkins
After=network.target
[Service]
User=jenkins
Group=jenkins
Environment=JENKINS_HOME=/var/lib/jenkins
Environment=CASC_JENKINS_CONFIG=/etc/jenkins/casc.yaml
ExecStart=/usr/local/bin/java -Djava.awt.headless=true -Djenkins.install.runSetupWizard=false -jar /opt/jenkins/jenkins.war --httpPort=8080 --webroot=/var/cache/jenkins/war
Restart=on-failure
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload && systemctl enable --now jenkins
A="admin:Jenkins-218"
for _ in $(seq 1 180); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' -u "$A" $JURL/api/json)" = 200 ] && break; sleep 2
done
mkdir -p /etc/jenkins-agent
curl -fs -u "$A" $JURL/computer/agente-linux/jenkins-agent.jnlp \
  | sed -n 's:.*<argument>\([0-9a-f]\{64\}\)</argument>.*:\1:p' | head -1 | tr -d '\n' > /etc/jenkins-agent/secret
chown -R jenkins-agent: /etc/jenkins-agent && chmod 600 /etc/jenkins-agent/secret
cat > /etc/systemd/system/jenkins-agent.service <<'U'
[Unit]
Description=Agente Jenkins agente-linux (WebSocket)
After=jenkins.service
[Service]
User=jenkins-agent
WorkingDirectory=/var/lib/jenkins-agent
ExecStart=/usr/local/bin/java -jar /opt/jenkins/agent.jar -url http://localhost:8080/ -name agente-linux -secret @/etc/jenkins-agent/secret -webSocket -workDir /var/lib/jenkins-agent
Restart=always
RestartSec=5
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload && systemctl enable --now jenkins-agent
for _ in $(seq 1 60); do
  curl -fs -u "$A" $JURL/computer/agente-linux/api/json | grep -q '"offline":false' && break; sleep 2
done

# Primer despliegue (con el bug: nadie pasa los tests).
CJ=$(mktemp)
CRUMB=$(curl -fs -u "$A" -c "$CJ" $JURL/crumbIssuer/api/json | python3 -c 'import json,sys;d=json.load(sys.stdin);print(d["crumbRequestField"]+":"+d["crumb"])')
curl -fs -u "$A" -b "$CJ" -H "$CRUMB" -X POST $JURL/job/tienda/build -o /dev/null
rm -f "$CJ"
for _ in $(seq 1 90); do
  curl -fs http://127.0.0.1:9080/api/version 2>/dev/null | grep -q '[0-9a-f]\{40\}' && break; sleep 2
done
echo "Primer despliegue: $(curl -fs http://127.0.0.1:9080/api/version || echo FALLO)"

runuser -u analista -- git clone -q "$GITEA_URL/analista/tienda.git" /home/analista/tienda
runuser -u analista -- git -C /home/analista/tienda config user.name analista
runuser -u analista -- git -C /home/analista/tienda config user.email analista@empresa.local
printf 'machine localhost login analista password analista123\n' > /home/analista/.netrc
chown analista:analista /home/analista/.netrc && chmod 600 /home/analista/.netrc

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Pipeline de Jenkins desde Gitea

Jenkins:  http://localhost:8218   (admin / Jenkins-218)
Gitea:    http://localhost:4218   (analista / analista123)
Tienda:   http://localhost:9218   (producción)

El job "tienda" es un pipeline pegado en la web de Jenkins: clona con la
contraseña de Gitea en claro, no pasa los tests y hay que lanzarlo a mano.
Producción calcula mal los descuentos (20x2 con 10% da 5).

Queremos:
  1. El pipeline en un Jenkinsfile del repo; el job "tienda" lo lee de Gitea
     (Pipeline script from SCM, rama main) con una credencial de Jenkins
     (mejor un token de Gitea que la contraseña).
  2. Tests (node --test) e informe JUnit publicado en Jenkins; tests y build
     del frontend en paralelo; sólo se despliega si todo pasa.
  3. Un webhook de Gitea que lance el job en cada push (sin clics).
  4. Arreglar el bug y que producción corra el último commit de main.

Pistas: /usr/local/bin/desplegar-tienda; /etc/jenkins/casc.yaml;
node --test --test-reporter=junit; API token de Jenkins (usuario > Security).
Comprueba: bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
forja_sin_internet
echo "Lab 218 plantado."
