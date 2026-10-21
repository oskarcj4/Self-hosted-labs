# Servicio en bucle de reinicios

> Operaciones · systemd · journalctl · puertos ocupados

## Escenario

La cola de cobros de `pay-01` no avanza: `payments-worker` está en `failed`.
El guardia ha hecho `systemctl restart` tres veces: "arranca y se cae". Lee
`~/ticket/INC-6303.txt`.

`Restart=always` no arregla nada si el servicio no puede arrancar: sólo
reintenta deprisa hasta que systemd se rinde (`start-limit-hit`). Antes de
reiniciar otra vez, lee **por qué** se cae.

## Objetivos

1. Encuentra las causas en el journal. Puede haber más de una: cuando
   arregles la primera, mira otra vez.
2. La unit carga la configuración desde `/etc/payments/payments.env`. **No**
   metas la URL ni el token dentro de la unit.
3. Lo que bloquea el puerto del worker, apagado (y que no vuelva).
4. `payments-worker` **activo, estable**, con el puerto 9090 y habilitado.

## Comandos que te pueden servir

```bash
systemctl status payments-worker
sudo journalctl -u payments-worker -n 30 --no-pager
systemctl cat payments-worker                      # la unit efectiva
ls -l /etc/payments/
sudo ss -ltnp 'sport = :9090'
systemctl status <PID>                              # ¿a qué unit pertenece un proceso?
sudo systemctl reset-failed payments-worker         # borra el contador de arranques
sudo systemctl daemon-reload                        # tras editar una unit
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
