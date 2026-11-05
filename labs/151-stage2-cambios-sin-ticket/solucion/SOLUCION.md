# Solución — Stage 2: cambios sin ticket

## Qué pasaba

Sobre la base aprobada de `/etc` (versionada con etckeeper) aparecieron dos
cambios sin ticket, hechos de madrugada (~02:38):

- `ssh/sshd_config`: `PermitRootLogin yes` (root abierto por SSH) — modificación.
- `cron.d/stage2`: cron oculto que ejecutaba `/usr/local/bin/.stage2` — fichero
  nuevo sin seguir.

## Arreglo

```bash
sudo git -C /etc status           #  M ssh/sshd_config   ?? cron.d/stage2
sudo git -C /etc diff             # el PermitRootLogin yes

# Revertir lo modificado a la base y borrar lo añadido sin ticket
sudo git -C /etc checkout -- ssh/sshd_config
sudo rm /etc/cron.d/stage2
sudo etckeeper commit "revert: cambios sin ticket" || true

sudo git -C /etc status --porcelain   # vacío = limpio

# Documentar
cat > ~/cambios.txt <<'C'
- /etc/ssh/sshd_config: PermitRootLogin yes (root por SSH). Revertido a la base.
- /etc/cron.d/stage2: cron oculto (/usr/local/bin/.stage2). Eliminado.
C
bash /opt/lab/check.sh
```

## Más allá del lab

- `git status` de `/etc` debería estar siempre vacío: todo cambio entra por un
  PR con su ticket. Un diff no explicado es un incidente, no una curiosidad.
- Combina etckeeper con AIDE (huellas fuera de `/etc`) y con alertas: que el
  commit automático dispare una notificación al canal de guardia.
- Si el cambio fuera legítimo pero sin ticket, el proceso es el mismo: se abre
  el ticket retroactivo y se commitea; la trazabilidad es el objetivo.
