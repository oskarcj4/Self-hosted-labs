# Lab 02 — 60 segundos para echar a un hacker

Inspirado en los videos de @terminalcero *"Tienes 60 segundos para echar a un hacker"* y *"Tu servidor está al 100% pero el monitor dice 0%"*.

## Escenario

Son las 3 de la mañana y salta una alerta: `db-prod-02` está enviando gigas de
datos a una IP desconocida por el puerto **4444**… pero el panel de monitoreo
dice que no hay nadie conectado. Tienes que entrar por consola y cazarlo antes
de que vacíen la base de datos.

Cuidado: este atacante dejó **persistencia**. Si matas el proceso sin desarmar
primero su mecanismo de persistencia, **resucitará solo en menos de un minuto**.

## Objetivos

1. **Encuentra la conexión oculta**: ¿qué proceso está escuchando en el puerto 4444?
2. **Identifica al impostor**: mira desde qué ruta se ejecuta. Un proceso del
   sistema no corre desde `/tmp`.
3. **Desarma la persistencia primero**: busca la tarea programada que lo revive
   y elimínala.
4. **Mata el proceso y borra el binario impostor.**
5. Comprueba que el puerto 4444 ya no escucha y que el proceso **no vuelve**.

## Comandos que te pueden servir

```bash
ss -tulpn                      # conexiones y puertos en escucha (+ proceso)
ls -la /proc/<PID>/exe         # ruta real del binario de un proceso
ls -la /tmp                    # ¿binarios raros aquí?
ls -la /etc/cron.d/ ; cat /etc/cron.d/*
crontab -l ; sudo crontab -l   # tareas programadas
cat /var/log/syslog            # la alerta original
```

> Orden recomendado: **persistencia → proceso → binario**. Si lo haces al revés,
> el beacon vuelve a aparecer. Espera ~60s tras limpiar y vuelve a mirar `ss`.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
