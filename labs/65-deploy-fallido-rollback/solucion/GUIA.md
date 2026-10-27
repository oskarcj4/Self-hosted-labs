# Resolución guiada · Deploy fallido y rollback

:::piensa Antes de tocar nada
Es un SEV1: restaura primero, investiga después, y **no destruyas la evidencia**
(la r43). El patrón `current -> releases/X` permite cambiar de versión al
instante. Dos trampas: el `deploy.sh rollback` elige mal la release, y un
`ln -sf` sin `-n` corrompe el enlace. Y ojo con volver **demasiado atrás**: una
release anterior a una migración de BD tampoco arranca bien.
:::

## Paso 1 · Confirma el fallo (dos minutos)

```bash
sudo journalctl -u shop -n 5 --no-pager        # ModuleNotFoundError: No module named 'pricing'
ls /srv/shop/releases/2026-10-20_0915-r43/     # falta pricing.py -> artefacto incompleto
```

## Paso 2 · No te fíes del script de rollback

**Pregúntate:** ¿qué release elige `deploy.sh`? Léelo antes de ejecutarlo.

:::pista Qué tiene de malo
```bash
cat /usr/local/bin/deploy.sh
#   prev=$(ls -1 "$R" | head -1)     <- la release MÁS ANTIGUA (r41), no la anterior
ls -1 /srv/shop/releases            # r41, r42, r43
```
Si lo ejecutas, vuelves a la r41, que no entiende el esquema 13 de la BD (llegó
con la r42). Volver demasiado atrás es otro incidente.
:::

## Paso 3 · Rollback a mano, atómico, a la r42

**Pregúntate:** ¿cómo cambio `current` sin que deje de existir ni un instante?
Con un enlace temporal + `mv -T` (rename atómico).

:::pista Cómo hacerlo
```bash
cd /srv/shop
sudo ln -s releases/2026-10-12_1105-r42 current.tmp
sudo mv -T current.tmp current        # rename(2): atómico
readlink -f current                   # .../2026-10-12_1105-r42
sudo systemctl restart shop           # el proceso ya tenía resuelto el dir real de r43
curl -s http://127.0.0.1:8500/health  # ok r42 esquema=13
```
- `mv -T`: `current` siempre apunta a una release completa.
- **No** `ln -sf releases/r42 current` sin `-n`: como `current` apunta a un
  directorio, `ln` lo sigue y crea el enlace **dentro** de la r43; `current`
  seguiría en r43 y encima la modificas.
:::

## Paso 4 · Arregla el script para la próxima

```bash
cur=$(basename "$(readlink -f /srv/shop/current)")
prev=$(ls -1 "$R" | grep -B1 -x "$cur" | head -1)
[ "$prev" != "$cur" ] || { echo "no hay release anterior" >&2; exit 1; }
```
Mejor: guardar `previous` en cada deploy y que el rollback compruebe `/health`.

## Paso 5 · Verifica (y deja todo limpio)

```bash
readlink -f /srv/shop/current               # r42
ls /srv/shop/releases/ | grep r43           # r43 intacta
ls /srv/shop                                # sin current.tmp/current.bak
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Un rollback no probado es otra apuesta.** Ensáyalo.
- **`current -> releases/X`**: cambio y vuelta atrás instantáneos; conserva 2–3
  releases.
- **Las migraciones de BD limitan hasta dónde puedes volver.** Hazlas
  compatibles hacia atrás (expand/contract).
- **Restaura primero, investiga después**, sin destruir la evidencia.

## Si te atascas

- `current` apunta dentro de r43 → usaste `ln -sf` sin `-n`; rehaz con
  `ln -s ... current.tmp` + `mv -T`.
- Arranca pero `/health` falla con r41 → volviste demasiado atrás (esquema de
  BD); apunta a r42.
