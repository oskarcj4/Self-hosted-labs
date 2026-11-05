# Stage 2: cambios sin ticket

> Mr. Robot · gestión del cambio · etckeeper · git en /etc · auditoría de config

## Escenario

En la "stage 2" del plan, el atacante ya está dentro y toca configuración para
quedarse: abre root por SSH, deja un cron oculto. Nada de esto pasó por un
ticket de cambio. La defensa: `/etc` versionado con **etckeeper**, de modo que
cualquier modificación sin aprobar salta en el `git diff`.

- **etckeeper** mantiene `/etc` en un repositorio git y commitea en cada
  cambio de paquetes y a diario. Lo aprobado está en el historial; lo que
  aparezca como pendiente (`git status`) es cambio sin ticket.
- Revertir no es "deshacer a ciegas": es volver a la **línea base aprobada**.
  Lo modificado se restaura con `git checkout --`; lo añadido se elimina.

## Objetivos

1. Averigua qué cambió en `/etc` respecto a la base aprobada (git).
2. Revierte lo no autorizado: `sshd_config` a la base y elimina lo añadido sin
   ticket. El árbol de `/etc` debe quedar **limpio**.
3. `~/cambios.txt`: lista cada cambio no autorizado que encontraste.

## Comandos que te pueden servir

```bash
sudo git -C /etc status                 # modificado + sin seguir
sudo git -C /etc diff                    # qué se tocó exactamente
sudo git -C /etc log --oneline           # historial de cambios aprobados
sudo git -C /etc checkout -- ssh/sshd_config   # revertir un fichero a la base
sudo rm /etc/cron.d/stage2               # eliminar lo añadido sin ticket
sudo etckeeper commit "revert cambios sin ticket"
sudo git -C /etc status --porcelain      # vacío = árbol limpio
```

> En producción, `git status` de `/etc` no debería mostrar nada: todo cambio
> entra por un pull request con su ticket. Un diff inesperado a las 02:38 es,
> por sí solo, un incidente.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
