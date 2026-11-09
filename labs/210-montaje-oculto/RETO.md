# df dice lleno, du dice vacío

> df vs du · montaje que oculta datos · lsof +L1 · ficheros borrados abiertos

## Escenario

`/almacen` (el disco "raiz", 100 MiB) está al ~75 %, pero `du` apenas ve
datos. Cuando `df` y `du` no cuadran hay dos causas clásicas, y aquí están las dos:

1. **Datos ocultos bajo un punto de montaje.** Se escribió en
   `/almacen/datos` *antes* de montar encima el disco de datos. Esos ficheros
   siguen en el disco de abajo, invisibles.
2. **Ficheros borrados que un proceso mantiene abiertos.** El espacio no se
   libera hasta que el proceso cierra el fichero (o muere).

## Objetivos

1. Encuentra los ficheros ocultos **sin desmontar** el disco de datos
   (`mount --bind` te enseña lo que hay debajo).
2. Muévelos al disco de datos, que es donde pertenecen. No los borres.
3. Localiza el fichero borrado que sigue ocupando espacio (`lsof +L1`) y
   libéralo reiniciando su servicio (`colector`).
4. Deja `/almacen` por debajo de 20 MiB, con `clientes.db` intacto.

## Comandos que te pueden servir

```bash
df -h /almacen ; sudo du -shx /almacen
sudo mkdir -p /mnt/vista && sudo mount --bind /almacen /mnt/vista   # sin submontajes
ls -la /mnt/vista/datos
sudo lsof -nP +L1
sudo systemctl restart colector
```

> `mount --bind` (sin `--rbind`) no arrastra los submontajes: ves el directorio
> tal como está en el disco de abajo. Cuidado: reiniciar un servicio solo
> libera el espacio si el proceso es el único que tenía abierto el fichero.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
