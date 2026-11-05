# El pipeline que hoy falla

> DevOps · Gitea · Woodpecker · lockfiles · pip --require-hashes · caché de CI

## Escenario

El pipeline de `main` pasó ayer (#41). Hoy (#42) falla, y el único commit
nuevo cambia una palabra del README (`~/ticket/CI-140.txt`). Nadie tocó el
código. Lo que sí cambió está **fuera** del repositorio.

- Repo en **Gitea** (`http://127.0.0.1:3000`, `analista` / `analista123`),
  copia de trabajo en `~/api`. Cada push a `main` lanza el pipeline.
- El CI es **Woodpecker** (`.woodpecker.yaml`) con backend local.
- Los paquetes Python vienen del mirror interno `http://127.0.0.1:8081/simple`.

Dos conceptos:

- **Lockfile**: `fastjson>=1.0` acepta cualquier versión futura. Un
  lockfile fija la versión exacta **y su hash**: el build de hoy instala
  byte a byte lo mismo que el de ayer, o falla de forma explícita.
- **Clave de caché**: la caché del CI se reutiliza mientras la clave no
  cambie. Si la clave es sólo la rama, la caché puede servir dependencias
  que ya no corresponden a tu lockfile.

## Objetivos

1. Compara los pipelines #41 y #42 y escribe en `~/causa.txt`:
   `paquete=` y `version_rota=`.
2. Crea `requirements.lock` con la versión buena **y su hash sha256**, e
   instala con `pip install --require-hashes -r requirements.lock`.
3. Cambia la clave de caché de `ci/deps.sh`: debe cambiar cuando cambia
   `requirements.lock`.
4. Haz push a `main` y deja el pipeline en verde.

## Comandos que te pueden servir

```bash
ci-logs -l                 # historial de pipelines
ci-logs 41; ci-logs 42     # logs de cada uno
cd ~/api && git log --stat
curl -s http://127.0.0.1:8081/simple/fastjson/ ; ls -l --time-style=full-iso /srv/pypi/simple/fastjson/
cat /var/log/ci/cache-clean.log; ls /var/cache/ci/
pip download fastjson==X.Y.Z --no-deps -d /tmp/w && python3 -m pip hash /tmp/w/*.whl   # o: sha256sum
sha256sum requirements.lock | cut -c1-16
git add -A && git commit -m "..." && git push
ci-run                     # lanza el pipeline a mano sobre main
```

> `python3 -m pip` no existe fuera de un venv en Debian 12: crea uno
> (`python3 -m venv /tmp/v && /tmp/v/bin/pip ...`) o usa `sha256sum`.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
