# Resolución guiada · Lab 151

:::piensa Lo aprobado está en el historial
Con `/etc` en git, no hay que adivinar qué cambió: `git status` y `git diff` lo
dicen. Tu trabajo es devolver `/etc` a la última base aprobada.
:::

## Paso 1 · ¿Qué cambió?

:::pista Cómo comprobarlo
```bash
sudo git -C /etc status      # M = modificado, ?? = añadido sin seguir
sudo git -C /etc diff
```
Sale `sshd_config` modificado y `cron.d/stage2` nuevo.
:::

## Paso 2 · Revertir a la base

**Pregúntate:** ¿se revierte igual un fichero *modificado* que uno *nuevo*?

:::pista Cómo hacerlo
```bash
sudo git -C /etc checkout -- ssh/sshd_config   # modificado -> vuelve a la base
sudo rm /etc/cron.d/stage2                      # nuevo (untracked) -> se borra
```
`git checkout` no quita lo que no sigue: el fichero añadido se elimina a mano.
:::

## Paso 3 · Deja el árbol limpio y documenta

:::pista Cómo comprobarlo
```bash
sudo etckeeper commit "revert cambios sin ticket" || true
sudo git -C /etc status --porcelain     # vacío
```
`~/cambios.txt` con los dos cambios y qué hiciste con cada uno.
:::

## Cómo actuar en una situación así

- Versiona `/etc` desde el día 1: sin base, no hay "antes" contra el que comparar.
- Cambios por PR + ticket; el commit automático de etckeeper es la red de
  seguridad, no el proceso.

## Si te atascas

- `git` se queja de "dubious ownership": `sudo git config --global --add
  safe.directory /etc`.
- El árbol no queda limpio: ¿quedó algún fichero `??` sin borrar, o revertiste
  el fichero equivocado? Mira `git status` otra vez.
