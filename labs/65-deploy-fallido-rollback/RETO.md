# Deploy fallido y rollback

> Operaciones · releases + symlink · rollback · SEV1

## Escenario

La tienda (`shop` en `shop-02`) está caída desde el deploy de la **r43**.
El responsable de guardia decide: **rollback a la r42**, que estaba en
producción hasta esta mañana. Lee `~/ticket/INC-6505.txt`.

Las releases viven en `/srv/shop/releases/` y la activa es la que señala el
enlace `/srv/shop/current`. El procedimiento oficial es `deploy.sh rollback`.
Antes de fiarte de él, lee qué hace.

## Objetivos

1. `/srv/shop/current` (sigue siendo un **enlace**) apunta a la **r42**.
2. La **r43 queda intacta**: desarrollo la necesita.
3. `shop` activo, estable y corriendo **desde la r42**:
   `curl -s http://127.0.0.1:8500/health` responde `ok r42 ...`.
4. Sin restos en `/srv/shop` (nada de `current.tmp`, `current.bak`...).

## Comandos que te pueden servir

```bash
systemctl status shop ; sudo journalctl -u shop -n 20 --no-pager
ls -l /srv/shop /srv/shop/releases
readlink -f /srv/shop/current
cat /usr/local/bin/deploy.sh
ln -sfn DESTINO ENLACE             # -n: no entres en el directorio al que apunta el enlace
mv -T NUEVO ENLACE                 # renombrado atómico
sudo ls -l /proc/$(systemctl show -p MainPID --value shop)/cwd
curl -s http://127.0.0.1:8500/health
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
