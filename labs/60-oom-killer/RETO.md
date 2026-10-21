# El servicio que muere sin dejar rastro (OOM killer)

> Operaciones · systemd · memoria · cgroups · journalctl

## Escenario

`report-gen` no genera informes desde el despliegue de esta mañana. El guardia
dice que está `active`. Desarrollo dice que en su log no hay ni un error.
Lee `~/ticket/INC-6230.txt`.

Cuando un proceso muere de golpe, sin traza ni mensaje de error, casi siempre
lo ha matado alguien desde fuera. Averigua quién y por qué.

## Objetivos

1. Encuentra la evidencia de qué mata a `report-gen` y copia la línea del
   journal que lo demuestra en `~/incidente/causa.txt`.
2. Encuentra el cambio que lo provocó.
3. Deja `report-gen` **estable** y generando informes.
4. **Sin quitar el límite de memoria**: este host es compartido y el
   presupuesto del servicio es de 256 MB como mucho. Arreglar la causa vale
   más que subir el límite.

## Comandos que te pueden servir

```bash
systemctl status report-gen                       # fíjate en "Main PID" y en el tiempo activo
systemctl show report-gen -p NRestarts,Result,MemoryMax,MemoryCurrent
sudo journalctl -u report-gen --no-pager | tail -30
sudo journalctl -k | grep -i -E 'oom|killed'        # mensajes del kernel
sudo dmesg | grep -i oom
cat /etc/report-gen.conf
systemd-cgtop                                     # memoria por servicio (q para salir)
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
