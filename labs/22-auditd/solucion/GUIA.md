# Resolución guiada · Lab 22

:::piensa Antes de tocar nada
En los labs 01, 05 y 10 descubriste persistencia **después** de que ocurriera. auditd te permite saber **quién y cuándo** tocó un fichero en el momento en que ocurre. La idea: pon una "cámara" sobre los ficheros críticos y etiqueta lo que graba para encontrarlo luego.
:::

## Paso 1 · Define qué vigilar

**Pregúntate:** ¿qué me interesa de `/etc/passwd`? No las lecturas (pasan constantemente), sino las **escrituras** y los cambios de **atributos**.

**Por qué importa:** vigilar demasiado llena el log de ruido y nadie lo mira.

:::pista Cómo hacerlo
```bash
sudo auditctl -w /etc/passwd -p wa -k passwd_changes
sudo auditctl -l
```
- `-w`: fichero a vigilar.
- `-p wa`: w = escritura, a = cambio de atributos.
- `-k`: etiqueta para buscar después.
:::

## Paso 2 · Provoca un evento

**Pregúntate:** ¿cómo compruebo que la cámara graba? Haz algo que **deba** quedar registrado.

:::pista Cómo hacerlo
```bash
sudo useradd probeuser
```
:::

## Paso 3 · Encuéntralo

**Pregúntate:** ¿qué datos me da el evento? Busca el comando, el usuario (`auid` = quién inició sesión, aunque luego usara sudo) y la hora.

:::pista Cómo comprobarlo
```bash
sudo ausearch -k passwd_changes -i
bash /opt/lab/check.sh
```
`-i` traduce UIDs y llamadas al sistema a texto legible.
:::

## Paso 4 · Hazlo persistente

**Pregúntate:** `auditctl` aplica la regla **en caliente**. ¿Qué pasa si se reinicia auditd? Se pierde.

```bash
echo '-w /etc/passwd -p wa -k passwd_changes' | sudo tee /etc/audit/rules.d/passwd.rules
sudo augenrules --load
```

## Cómo actuar en una situación así

- **Vigila lo que usan los atacantes para persistir**: `/etc/passwd`, `/etc/shadow`, `/etc/sudoers*`, `authorized_keys`, `/etc/cron*`, `/etc/systemd/system`.
- **Etiqueta cada regla** con una clave clara: buscar es tan importante como registrar.
- **Saca los logs de la máquina**: un atacante con root puede borrar el log de audit (lab 09).

## Si te atascas

- `auditctl` dice "Operation not permitted": el host no expone audit al contenedor (lo avisa el enunciado).
- `ausearch` no encuentra nada: confirma con `auditctl -l` que la regla está y repite el cambio.
