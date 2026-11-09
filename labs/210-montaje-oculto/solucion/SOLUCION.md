# Solución — df vs du

## Qué pasaba

- 25 MiB de subidas escritas en `/almacen/datos` antes de montar el disco de datos encima.
- `colector` había borrado su log (45 MiB) sin cerrarlo.

## Arreglo

```bash
sudo mkdir -p /mnt/vista && sudo mount --bind /almacen /mnt/vista
ls -la /mnt/vista/datos
sudo mv /mnt/vista/datos/subida-2025-*.bin /almacen/datos/
sudo umount /mnt/vista
sudo lsof -nP +L1
sudo systemctl restart colector
df -h /almacen
bash /opt/lab/check.sh
```

## Más allá del lab

- `findmnt` + `lsblk` para saber qué hay en cada punto; `ncdu -x` ayuda a ver el uso real por sistema de ficheros.
- Alertas: porcentaje de `df` frente a suma de `du` como señal de ficheros borrados abiertos.
