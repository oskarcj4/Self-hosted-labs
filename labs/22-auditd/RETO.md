# Lab 22 — Audita los cambios en /etc/passwd con auditd

## Escenario (tarea de detección)

Quieres saber **quién y cuándo** toca `/etc/passwd` en `audit-22` (crear usuarios,
backdoors UID 0 como en el lab 05…). El framework de auditoría del kernel Linux,
**auditd**, registra ese tipo de eventos. Configura una regla que vigile el
archivo, provoca un cambio y encuéntralo con `ausearch`.

## Objetivos

1. **Añade una regla de auditoría** que vigile escrituras/atributos sobre
   `/etc/passwd`, con la clave (`-k`) `passwd_changes`.
2. **Provoca un cambio** en `/etc/passwd` (por ejemplo, crea un usuario de prueba).
3. **Encuentra el evento** con `ausearch -k passwd_changes`.

## Comandos que te pueden servir

```bash
sudo auditctl -w /etc/passwd -p wa -k passwd_changes   # regla en caliente
sudo auditctl -l                                       # lista las reglas activas
sudo useradd probeuser                                 # provoca un cambio
sudo ausearch -k passwd_changes                        # busca los eventos
# persistente (se recarga al arrancar auditd):
echo '-w /etc/passwd -p wa -k passwd_changes' | sudo tee /etc/audit/rules.d/passwd.rules
sudo augenrules --load
```

> Nota: este lab depende del subsistema **audit del kernel**; por eso el
> contenedor corre en modo `privileged`. Si `auditctl` diera *"Operation not
> permitted"*, tu host no expone audit a los contenedores.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
