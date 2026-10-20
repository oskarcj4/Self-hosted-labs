# Solución — Lab 22

## 1. Añadir la regla

```bash
sudo auditctl -w /etc/passwd -p wa -k passwd_changes
sudo auditctl -l        # confirma que aparece
```

`-w /etc/passwd` vigila el archivo, `-p wa` escrituras y cambios de atributos,
`-k passwd_changes` etiqueta los eventos para buscarlos luego.

Persistente (sobrevive a reinicios de auditd):

```bash
echo '-w /etc/passwd -p wa -k passwd_changes' | sudo tee /etc/audit/rules.d/passwd.rules
sudo augenrules --load
```

## 2. Provocar un cambio

```bash
sudo useradd probeuser
```

## 3. Encontrar el evento

```bash
sudo ausearch -k passwd_changes
# verás un registro SYSCALL/PATH con el comando (useradd), el uid y la hora
sudo ausearch -k passwd_changes | aureport -f -i   # resumen legible
```

## Verifica

```bash
bash /opt/lab/check.sh
```

## Lecciones

- auditd registra accesos a archivos y llamadas al sistema con una regla por
  clave; `ausearch -k` recupera exactamente esos eventos.
- Vigilar `/etc/passwd`, `/etc/shadow`, `/etc/sudoers`, binarios SUID y
  `~/.ssh/authorized_keys` detecta las persistencias de los labs 01, 05 y 10.
- Los logs de audit deben enviarse fuera de la máquina: un atacante con root
  podría intentar borrarlos (lab 09).
