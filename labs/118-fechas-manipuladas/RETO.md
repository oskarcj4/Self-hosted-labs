# Fechas manipuladas (forense de timestamps)

> Defensa del host · stat · mtime vs ctime · find -cnewer

## Escenario

El EDR vio una subida de datos desde `srv-118` hacia una IP externa
(`~/ticket/INC-118.txt`). En `/usr/local/bin` todo parece de 2023 con
`ls -l`. El intruso usó `touch` para copiar fechas de los vecinos.

Lo que `touch` **no** puede cambiar es el **ctime** (cambio de inodo): el
kernel lo pone a "ahora" en cada escritura o cambio de metadatos, incluido el
propio `touch`.

## Objetivos

1. El último cambio autorizado es el despliegue que registra
   `/var/log/deploy/ultimo.log`. Encuentra en `/usr/local/bin` lo creado o
   modificado **después**, aunque su mtime diga 2023. No metas los legítimos.
2. Anota en `~/fechas.txt` cada fichero tocado (ruta completa) y su ctime
   real.
3. Revierte: el script nuevo fuera de `/usr/local/bin` (a cuarentena, no lo
   destruyas) y el script modificado restaurado desde
   `/var/backups/usr-local-bin.tar.gz`, ejecutable.

## Comandos que te pueden servir

```bash
stat /usr/local/bin/*
ls -l --time=ctime --full-time /usr/local/bin
find /usr/local/bin -cmin -60
find /usr/local/bin -newer  /var/log/deploy/ultimo.log   # compara mtime
find /usr/local/bin -cnewer /var/log/deploy/ultimo.log   # compara ctime
find /usr/local/bin -printf '%C+  %T+  %p
' | sort      # línea de tiempo
tar -tzvf /var/backups/usr-local-bin.tar.gz
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```

> En contenedores, los ficheros que vienen en la imagen tienen el ctime del
> momento en que Docker la desempaquetó. Por eso aquí se compara contra una
> referencia (el log del despliegue) y no contra "hace N minutos".
