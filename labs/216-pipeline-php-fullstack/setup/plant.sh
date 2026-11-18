#!/usr/bin/env bash
# Lab 216: pipeline full stack PHP (php-fpm + Composer + SQLite) con despliegue atómico.
# Plantado: forja y runner funcionando. El pipeline "despliega" con un rsync en
# caliente sobre /var/www/reservas:
#  - copia .git, tests, el .env con secretos (versionado en el repo) y vendor con dev;
#  - rsync --delete BORRA data/ (la base SQLite) en cada despliegue;
#  - sin tests (y hay uno que falla: reservas consecutivas rechazadas);
#  - opcache.validate_timestamps=0: sin recargar php-fpm sigue el código viejo;
#  - despliega desde cualquier rama.
set -e
export HOME=/root
echo GITEA_PORT=4216 > /opt/lab/forja.env
source /opt/lab/setup/forja.sh
install -m 0644 /opt/lab/setup/forja.sh /opt/lab/forja.sh
install -m 0644 /opt/lab/setup/wf.py /opt/lab/wf.py
install -m 0755 /opt/lab/setup/ci-estado /opt/lab/setup/ci-log /usr/local/bin/
echo reservas > /opt/lab/.repo-defecto

# --- Composer sin internet: caché interna ---------------------------------------
cat > /etc/profile.d/composer.sh <<'SH'
export COMPOSER_CACHE_DIR=/opt/composer-cache COMPOSER_DISABLE_NETWORK=1
SH

# --- Forja y runner --------------------------------------------------------------
forja_gitea true self
forja_espejo_checkout
forja_runner self-hosted:host
forja_sin_internet   # desde aquí, nada sale a internet
mkdir -p /etc/systemd/system/act_runner.service.d
printf '[Service]\nEnvironment=COMPOSER_CACHE_DIR=/opt/composer-cache COMPOSER_DISABLE_NETWORK=1\n' \
  > /etc/systemd/system/act_runner.service.d/composer.conf
systemctl daemon-reload && systemctl restart act_runner

# --- Producción: nginx + php-fpm con opcache de producción ------------------------
cat > /etc/php/8.2/fpm/conf.d/90-produccion.ini <<'INI'
; Producción: opcache no mira si los ficheros cambian (rendimiento).
; Tras cada despliegue hay que recargar php-fpm.
opcache.enable=1
opcache.validate_timestamps=0
INI
mkdir -p /var/www/reservas
chown www-data:www-data /var/www/reservas
cat > /etc/nginx/sites-available/default <<'NG'
server {
    listen 8080 default_server;
    root /var/www/reservas/public;
    index index.php;
    location / { try_files $uri /index.php$is_args$args; }
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        fastcgi_param DOCUMENT_ROOT $realpath_root;
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
    }
}
NG
# El script de despliegue "de toda la vida".
cat > /usr/local/bin/publicar-reservas <<'SH'
#!/usr/bin/env bash
# publicar-reservas DIR [SHA] — publica el código de DIR en /var/www/reservas.
# Lo llama el pipeline con sudo (regla en /etc/sudoers.d/act-runner).
set -euo pipefail
rsync -a --delete "$1/" /var/www/reservas/
chown -R www-data:www-data /var/www/reservas
echo "publicado"
SH
chmod 755 /usr/local/bin/publicar-reservas
echo 'act-runner ALL=(root) NOPASSWD: /usr/local/bin/publicar-reservas *' > /etc/sudoers.d/act-runner
chmod 440 /etc/sudoers.d/act-runner
systemctl enable --now php8.2-fpm nginx

# --- Repo analista/reservas ---------------------------------------------------------
R=/tmp/reservas
mkdir -p $R/src $R/public $R/tests $R/.github/workflows
cp /opt/composer-plantilla/composer.json /opt/composer-plantilla/composer.lock $R/
cat > $R/src/Reservas.php <<'PHP'
<?php

declare(strict_types=1);

namespace Reservas;

use InvalidArgumentException;
use PDO;

/** Reservas de salas por franjas horarias (horas enteras, 8-20). */
final class Reservas
{
    public function __construct(private PDO $db)
    {
        $this->db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $this->db->exec('CREATE TABLE IF NOT EXISTS reservas (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sala TEXT NOT NULL, dia TEXT NOT NULL,
            desde INTEGER NOT NULL, hasta INTEGER NOT NULL, quien TEXT NOT NULL)');
    }

    /** @return list<array<string, mixed>> */
    public function listar(): array
    {
        return $this->db->query('SELECT * FROM reservas ORDER BY dia, sala, desde')->fetchAll(PDO::FETCH_ASSOC);
    }

    /** @return array<string, mixed> */
    public function reservar(string $sala, string $dia, int $desde, int $hasta, string $quien): array
    {
        if ($desde < 8 || $hasta > 20 || $desde >= $hasta) {
            throw new InvalidArgumentException('franja no válida (8-20, desde < hasta)');
        }
        if ($this->seSolapa($sala, $dia, $desde, $hasta)) {
            throw new Ocupada("$sala ya está reservada el $dia entre $desde y $hasta");
        }
        $st = $this->db->prepare('INSERT INTO reservas (sala, dia, desde, hasta, quien) VALUES (?, ?, ?, ?, ?)');
        $st->execute([$sala, $dia, $desde, $hasta, $quien]);
        return ['id' => (int) $this->db->lastInsertId(), 'sala' => $sala, 'dia' => $dia,
                'desde' => $desde, 'hasta' => $hasta, 'quien' => $quien];
    }

    private function seSolapa(string $sala, string $dia, int $desde, int $hasta): bool
    {
        $st = $this->db->prepare('SELECT COUNT(*) FROM reservas
                                  WHERE sala = ? AND dia = ? AND desde <= ? AND hasta >= ?');
        $st->execute([$sala, $dia, $hasta, $desde]);
        return (int) $st->fetchColumn() > 0;
    }
}
PHP
cat > $R/src/Ocupada.php <<'PHP'
<?php

declare(strict_types=1);

namespace Reservas;

final class Ocupada extends \RuntimeException
{
}
PHP
cat > $R/src/Config.php <<'PHP'
<?php

declare(strict_types=1);

namespace Reservas;

/** Lee un fichero .env sencillo (CLAVE=valor). */
final class Config
{
    /** @return array<string, string> */
    public static function cargar(string $fichero): array
    {
        $c = [];
        foreach (is_readable($fichero) ? file($fichero, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) : [] as $l) {
            if ($l[0] !== '#' && str_contains($l, '=')) {
                [$k, $v] = explode('=', $l, 2);
                $c[trim($k)] = trim($v);
            }
        }
        return $c;
    }
}
PHP
cat > $R/public/index.php <<'PHP'
<?php

declare(strict_types=1);

require __DIR__ . '/../vendor/autoload.php';

use Reservas\Config;
use Reservas\Ocupada;
use Reservas\Reservas;

$raiz = dirname(__DIR__);
$cfg = Config::cargar($raiz . '/.env');
$ruta = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);

function json(mixed $datos, int $codigo = 200): never
{
    http_response_code($codigo);
    header('Content-Type: application/json');
    echo json_encode($datos, JSON_UNESCAPED_UNICODE);
    exit;
}

if ($ruta === '/api/version') {
    $rev = is_readable("$raiz/REVISION") ? trim((string) file_get_contents("$raiz/REVISION")) : 'desconocida';
    json(['version' => $rev, 'entorno' => $cfg['APP_ENV'] ?? '?']);
}

$app = new Reservas(new PDO('sqlite:' . ($cfg['DB_PATH'] ?? "$raiz/data/reservas.sqlite")));

if ($ruta === '/api/reservas' && $_SERVER['REQUEST_METHOD'] === 'GET') {
    json($app->listar());
}
if ($ruta === '/api/reservas' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $d = json_decode((string) file_get_contents('php://input'), true) ?: [];
    try {
        json($app->reservar((string) ($d['sala'] ?? ''), (string) ($d['dia'] ?? ''),
            (int) ($d['desde'] ?? 0), (int) ($d['hasta'] ?? 0), (string) ($d['quien'] ?? '')), 201);
    } catch (Ocupada $e) {
        json(['error' => $e->getMessage()], 409);
    } catch (InvalidArgumentException $e) {
        json(['error' => $e->getMessage()], 422);
    }
}
?>
<!doctype html>
<html lang="es">
<head><meta charset="utf-8"><title>Reservas de salas</title></head>
<body>
  <h1>Reservas de salas</h1>
  <form id="f">
    <input name="sala" placeholder="Sala" required> <input name="dia" type="date" required>
    <input name="desde" type="number" min="8" max="19" value="10"> - <input name="hasta" type="number" min="9" max="20" value="11">
    <input name="quien" placeholder="Quién" required> <button>Reservar</button>
  </form>
  <p id="msg"></p>
  <ul id="lista"></ul>
  <script>
    const pinta = async () => {
      const rs = await fetch('/api/reservas').then((r) => r.json());
      document.getElementById('lista').innerHTML = rs.map((r) =>
        `<li>${r.dia} · ${r.sala} · ${r.desde}-${r.hasta} h · ${r.quien}</li>`).join('');
    };
    document.getElementById('f').addEventListener('submit', async (e) => {
      e.preventDefault();
      const d = Object.fromEntries(new FormData(e.target));
      const r = await fetch('/api/reservas', { method: 'POST', body: JSON.stringify(d) });
      document.getElementById('msg').textContent = r.ok ? 'Reservado' : (await r.json()).error;
      pinta();
    });
    pinta();
  </script>
</body>
</html>
PHP
cat > $R/tests/ReservasTest.php <<'PHP'
<?php

declare(strict_types=1);

namespace Reservas\Tests;

use InvalidArgumentException;
use PDO;
use PHPUnit\Framework\TestCase;
use Reservas\Ocupada;
use Reservas\Reservas;

final class ReservasTest extends TestCase
{
    private Reservas $r;

    protected function setUp(): void
    {
        $this->r = new Reservas(new PDO('sqlite::memory:'));
    }

    public function testReservaYLista(): void
    {
        $this->r->reservar('Ada', '2026-12-01', 10, 11, 'ana');
        $this->assertCount(1, $this->r->listar());
    }

    public function testSolapeRechazado(): void
    {
        $this->r->reservar('Ada', '2026-12-01', 10, 12, 'ana');
        $this->expectException(Ocupada::class);
        $this->r->reservar('Ada', '2026-12-01', 11, 13, 'luis');
    }

    public function testReservasConsecutivasNoSeSolapan(): void
    {
        $this->r->reservar('Ada', '2026-12-01', 10, 11, 'ana');
        $this->r->reservar('Ada', '2026-12-01', 11, 12, 'luis');
        $this->assertCount(2, $this->r->listar());
    }

    public function testOtraSalaNoSeSolapa(): void
    {
        $this->r->reservar('Ada', '2026-12-01', 10, 11, 'ana');
        $this->r->reservar('Turing', '2026-12-01', 10, 11, 'luis');
        $this->assertCount(2, $this->r->listar());
    }

    public function testFranjaInvalida(): void
    {
        $this->expectException(InvalidArgumentException::class);
        $this->r->reservar('Ada', '2026-12-01', 21, 22, 'ana');
    }
}
PHP
cat > $R/phpunit.xml <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<phpunit bootstrap="vendor/autoload.php" colors="true">
  <testsuites>
    <testsuite name="reservas"><directory>tests</directory></testsuite>
  </testsuites>
</phpunit>
XML
cat > $R/phpstan.neon <<'NEON'
parameters:
  level: 6
  paths: [src, public]
NEON
cat > $R/.env <<'ENV'
# Configuración de producción
APP_ENV=produccion
DB_PATH=/var/www/reservas/data/reservas.sqlite
SMTP_USER=reservas@empresa.local
SMTP_PASS=Smtp-Reservas-2026!
ENV
printf 'vendor/\ndata/\n' > $R/.gitignore
cat > $R/.github/workflows/deploy.yml <<'YML'
name: deploy
on: push

jobs:
  deploy:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4

      - name: Dependencias
        run: composer install --no-interaction

      - name: Publicar
        run: sudo /usr/local/bin/publicar-reservas "$PWD"
YML
cat > $R/README.md <<'MD'
# reservas

Reservas de salas. PHP 8.2 + SQLite, servido por nginx + php-fpm.
Tests: `vendor/bin/phpunit`. Análisis estático: `vendor/bin/phpstan analyse`.
MD
forja_repo reservas $R "reservas: app, tests y despliegue" "$(date -d '-30 days' -Iseconds)"
SHA=$(git -C $R rev-parse HEAD)
rm -rf $R
echo "Primer pipeline: $(forja_espera_sha reservas "$SHA" 300)"

# Reservas reales de producción (y la copia de anoche).
mkdir -p /var/www/reservas/data
php -r '
$db = new PDO("sqlite:/var/www/reservas/data/reservas.sqlite");
$db->exec("CREATE TABLE IF NOT EXISTS reservas (id INTEGER PRIMARY KEY AUTOINCREMENT, sala TEXT NOT NULL, dia TEXT NOT NULL, desde INTEGER NOT NULL, hasta INTEGER NOT NULL, quien TEXT NOT NULL)");
foreach ([["Ada","2026-12-02",9,11,"direccion"],["Turing","2026-12-02",10,12,"rrhh"],["Hopper","2026-12-03",16,18,"comite-seguridad"]] as $r) {
  $db->prepare("INSERT INTO reservas (sala, dia, desde, hasta, quien) VALUES (?,?,?,?,?)")->execute($r);
}'
chown -R www-data:www-data /var/www/reservas/data
mkdir -p /var/backups
cp /var/www/reservas/data/reservas.sqlite "/var/backups/reservas-$(date -d yesterday +%F).sqlite"

runuser -u analista -- git clone -q "$GITEA_URL/analista/reservas.git" /home/analista/reservas
runuser -u analista -- git -C /home/analista/reservas config user.name analista
runuser -u analista -- git -C /home/analista/reservas config user.email analista@empresa.local
printf 'machine localhost login analista password analista123\n' > /home/analista/.netrc
chown analista:analista /home/analista/.netrc && chmod 600 /home/analista/.netrc

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Pipeline full stack (PHP)

La app de reservas (~/reservas, http://localhost:8080 en el servidor) se
"despliega" con un rsync en caliente (/usr/local/bin/publicar-reservas).
Problemas conocidos:
  - en producción están .git, los tests, phpunit y el .env con la contraseña
    SMTP (que además está versionado en git);
  - "cada vez que desplegamos desaparecen las reservas";
  - "no se puede reservar una sala justo cuando acaba otra reserva";
  - a veces despliegan y "no cambia nada" hasta que alguien reinicia algo;
  - cualquier rama despliega, y no se pasa ni un test.

Montad despliegues atómicos (estilo Capistrano/Deployer):
  /var/www/reservas/releases/<sha>   una carpeta por despliegue
  /var/www/reservas/shared/          .env y data/ (sobreviven a los despliegues)
  /var/www/reservas/current -> releases/<sha>   (cambio atómico del enlace)

Composer funciona sin internet (caché interna). Copia de seguridad de la base
de anoche en /var/backups/. publicar-reservas es vuestro: reescribidlo
(el runner lo puede llamar con sudo).

Ayudas: ci-estado, ci-log [nº]
Comprueba: bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 216 plantado."
