# Solución — Deploy fallido y rollback

## 1. Confirma el fallo (dos minutos, no más: es un SEV1)

```bash
sudo journalctl -u shop -n 5 --no-pager
# ModuleNotFoundError: No module named 'pricing'
ls /srv/shop/releases/2026-10-20_0915-r43/      # app.py VERSION uploads   <- falta pricing.py
```

Artefacto incompleto: la r43 importa un módulo que no se empaquetó. El
análisis puede esperar; primero, restaurar el servicio.

## 2. No te fíes del script

```bash
cat /usr/local/bin/deploy.sh
#    prev=$(ls -1 "$R" | head -1)      <- ¡la release MÁS ANTIGUA, no la anterior!
ls -1 /srv/shop/releases
# 2026-09-28_1830-r41    <- head -1 elige esta
# 2026-10-12_1105-r42
# 2026-10-20_0915-r43
```

Si lo ejecutas, vuelves a la r41. Arranca, pero `/health` falla: la r41 no
entiende el esquema 13 de la BD (la migración llegó con la r42). Volver
"demasiado atrás" también es un incidente.

## 3. Rollback a mano, de forma atómica

```bash
cd /srv/shop
sudo ln -s releases/2026-10-12_1105-r42 current.tmp
sudo mv -T current.tmp current         # rename(2): atómico
readlink -f current                    # .../2026-10-12_1105-r42
sudo systemctl restart shop
curl -s http://127.0.0.1:8500/health   # ok r42 esquema=13
```

- Con `mv -T`, `current` siempre existe y siempre apunta a una release
  completa. `ln -sfn` funciona pero no es atómico: hace `unlink` y luego
  `symlink`, y entre una cosa y otra `current` no existe.
- **Error clásico:** `ln -sf releases/r42 current` (sin `-n`). Como `current`
  es un enlace a un directorio, `ln` lo sigue y crea el enlace **dentro** de
  la r43 (`releases/r43/2026-10-12_1105-r42`). `current` sigue apuntando a la
  r43, y además la has modificado.
- Hay que reiniciar: el proceso ya cargó el código y tiene su
  `WorkingDirectory` resuelto al directorio real de la r43.

## 4. Arregla el script (para la próxima)

```bash
# la anterior a la activa:
cur=$(basename "$(readlink -f /srv/shop/current)")
prev=$(ls -1 "$R" | grep -B1 -x "$cur" | head -1)
[ "$prev" != "$cur" ] || { echo "no hay release anterior" >&2; exit 1; }
```

Mejor aún: guarda la release previa en cada deploy (`/srv/shop/previous`) y
haz que el rollback compruebe `/health` antes de dar el trabajo por bueno.

## Lecciones

- Un rollback que nunca se ha probado es otra apuesta. Ensáyalo.
- `current -> releases/X` permite cambiar de versión en un instante, y volver
  atrás igual de rápido. Conserva al menos 2–3 releases.
- Los cambios de esquema de la BD limitan hasta dónde puedes volver atrás.
  Por eso las migraciones se hacen compatibles hacia atrás (expand/contract).
- Restaura primero, investiga después, y **no destruyas la evidencia** (la
  r43).
