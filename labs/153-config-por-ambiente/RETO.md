# Configuración por ambiente

> Imagen y ejecución · 12-factor · variables de entorno · EnvironmentFile · secretos

## Escenario

`allsafe-api` (en `/opt/allsafe/app.py`) tiene la configuración **y un secreto
quemados en el código**: `APP_ENV`, `DB_HOST`, `SECRET_KEY`... Así no puedes usar
la misma imagen en dev y en prod (tendrías que recompilar para cambiar un valor),
y el secreto acaba en el repositorio.

El principio **12-factor**: la configuración vive en el entorno, no en el código.
La misma imagen corre en cualquier ambiente; solo cambian las variables.

## Objetivos

1. Refactoriza `app.py` para leer toda la config del entorno (`os.environ`):
   `APP_ENV`, `LOG_LEVEL`, `DB_HOST`, `SECRET_KEY`. Sin secretos en el código.
2. Crea `/etc/allsafe/app.env` con esas variables (`APP_ENV=prod`), permisos `600`.
3. Haz que el servicio lo cargue: `EnvironmentFile=/etc/allsafe/app.env`.
4. Recarga y reinicia. Verifica:

```bash
curl -s localhost:8080/        # {"env":"prod", ..., "secret_set":true}
```

## Pistas

```bash
sudo systemctl cat allsafe-api            # ver el unit actual
sudo systemctl edit --full allsafe-api    # o editar el fichero directamente
sudo systemctl daemon-reload && sudo systemctl restart allsafe-api
```

> La misma imagen en dev y prod: cambiar `app.env` a `APP_ENV=dev` y reiniciar
> bastaría para correr en dev, sin tocar una línea de código.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
