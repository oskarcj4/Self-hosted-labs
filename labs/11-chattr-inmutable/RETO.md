# Lab 11 — El archivo que `rm` no puede borrar

## Escenario

En `host-11` encontraste un payload del atacante en `/data/.payload`, pero
cuando intentas borrarlo, `rm` falla con *"Operation not permitted"* aunque seas
root. El atacante lo protegió con el atributo **inmutable** del sistema de
archivos (`chattr +i`): mientras ese atributo esté puesto, el archivo no se puede
modificar ni borrar, ni siquiera por root. Hay que quitarlo primero.

## Objetivos

1. **Diagnostica por qué `rm` falla**: inspecciona los atributos extendidos del
   archivo con `lsattr`.
2. **Quita el atributo inmutable** con `chattr -i`.
3. **Borra el payload.**

## Comandos que te pueden servir

```bash
ls -la /data/.payload
sudo rm -f /data/.payload          # falla: Operation not permitted
lsattr /data/.payload              # verás una 'i' -> inmutable
sudo chattr -i /data/.payload      # quita el atributo
sudo rm -f /data/.payload          # ahora sí
```

> `lsattr`/`chattr` son de `e2fsprogs` y funcionan sobre ext4. El bit inmutable
> es un truco de persistencia clásico: un simple `rm` no basta.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
