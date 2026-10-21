# Game day: varias averías a la vez

> Operaciones · triage · journalctl · PostgreSQL · postmortem

## Escenario

Simulacro SEV1. El equipo de resiliencia ha roto cosas en `app-05` a
propósito y la tienda responde `503 error interno`. Lee
`~/ticket/GAMEDAY-73.txt`.

Nadie te va a decir qué está roto, ni cuántas cosas. Al cliente sólo le
llega "error interno"; el detalle está en los logs.

## Objetivos

1. `curl -s http://127.0.0.1:8080/health` responde `tienda ok (240 productos)`.
2. Sin perder datos: las subidas de clientes (`pedido-*.pdf`) se quedan.
3. Sin deshacer cambios legítimos: si un cambio estaba mal escrito, se
   corrige, no se borra.
4. `~/postmortem.md` con las secciones `## Resumen`, `## Cronología`,
   `## Impacto`, `## Causa raíz` y `## Acciones`. Menciona **todas** las
   causas.

## Método (no te saltes pasos)

1. **Síntoma**: qué ve el cliente.
2. **Logs** del servicio afectado: el primer error concreto.
3. Arregla **una** cosa, verifica y vuelve al paso 1.
4. Apunta la hora de cada hallazgo: la cronología del postmortem sale de ahí.

## Comandos que te pueden servir

```bash
curl -s http://127.0.0.1:8080/health
sudo journalctl -u tienda -n 20 --no-pager
systemctl --failed
df -h ; sudo du -sh /srv/app/uploads/* | sort -h
systemctl status postgresql postgresql@15-main
sudo journalctl -u postgresql@15-main -n 20 --no-pager
sudo tail -n 20 /var/log/postgresql/postgresql-15-main.log
getent hosts db.interno
date '+%H:%M'                          # para tu cronología
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
