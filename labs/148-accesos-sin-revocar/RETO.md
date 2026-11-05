# Accesos que nadie revocó

> Mr. Robot · IAM · cuentas huérfanas · llaves SSH · sudoers.d · joiner/mover/leaver

## Escenario

RRHH avisa: hay personal dado de baja que quizá conserva acceso a `allsafe-148`.
Es el fallo más común y más barato de explotar: la cuenta del que se fue, la
llave del contratista, el `sudoers.d` que nadie borró. El acceso se da con
ceremonia y se revoca... nunca.

- La fuente de verdad de quién debe tener acceso es RRHH:
  `/etc/iam/altas-bajas.txt`. Lo que haya en el sistema y no esté de ALTA, sobra.
- Las llaves SSH aprobadas están en `/etc/iam/llaves-aprobadas.txt` (por
  comentario). Cualquier otra llave en un `authorized_keys` es acceso no
  autorizado.
- Revocar no es sólo borrar la cuenta: hay que barrer **llaves** y **sudo**.

## Objetivos

1. Revoca las cuentas de quienes están de **BAJA** (bloquear con `passwd -l` o
   eliminar con `userdel`). No toques las de ALTA (`deploy`, `analista`).
2. Quita toda llave SSH que no esté aprobada, de cualquier `authorized_keys`.
   Conserva la aprobada (`ops@allsafe`).
3. Elimina cualquier regla `sudoers.d` de personal que ya no está.
4. `~/revocados.txt`: una línea por cosa revocada.

## Comandos que te pueden servir

```bash
cat /etc/iam/altas-bajas.txt /etc/iam/llaves-aprobadas.txt
cut -d: -f1,7 /etc/passwd | grep -vE 'nologin|/false'    # cuentas con shell
sudo passwd -S tyrell
sudo grep -rl 'darkarmy@exfil' /home /root               # ¿dónde está la llave no aprobada?
sudo grep -rn '' /home/*/.ssh/authorized_keys 2>/dev/null
sudo passwd -l tyrell scripted          # o: sudo userdel -r tyrell
sudo sed -i '/darkarmy@exfil/d' /home/deploy/.ssh/authorized_keys
sudo rm /etc/sudoers.d/tyrell && sudo visudo -c
```

> En una organización real esto es un proceso **joiner/mover/leaver**
> automatizado contra el IdP (LDAP/SSO): la baja en RRHH dispara la revocación
> en todos los sistemas. El lab entrena el reflejo manual.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
