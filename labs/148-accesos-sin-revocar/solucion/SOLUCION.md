# Solución — Accesos que nadie revocó

## Qué pasaba

Según RRHH (`/etc/iam/altas-bajas.txt`), `tyrell` y `scripted` están de BAJA pero
seguían con cuenta y shell. La llave `darkarmy@exfil` (no aprobada) estaba en
`authorized_keys` de `deploy` y de `tyrell`, y había un `sudoers.d/tyrell` con
NOPASSWD. `deploy` y `analista` son cuentas de ALTA: no se tocan.

## Arreglo

```bash
cat /etc/iam/altas-bajas.txt /etc/iam/llaves-aprobadas.txt

# 1) Cuentas de baja (bloquear; userdel -r si se quiere borrar del todo)
sudo passwd -l tyrell scripted
sudo passwd -S tyrell          # L

# 2) Llave no aprobada, fuera de todos los authorized_keys
sudo find /home /root -name authorized_keys | xargs sudo grep -l darkarmy@exfil
sudo sed -i '/darkarmy@exfil/d' /home/deploy/.ssh/authorized_keys /home/tyrell/.ssh/authorized_keys
grep ops@allsafe /home/deploy/.ssh/authorized_keys     # la aprobada sigue

# 3) sudoers.d olvidado
sudo rm /etc/sudoers.d/tyrell && sudo visudo -c

# 4) Documentar
cat > ~/revocados.txt <<'R'
cuenta tyrell: bloqueada (BAJA 2015)
cuenta scripted: bloqueada (BAJA 2016)
llave SSH darkarmy@exfil: eliminada de deploy y tyrell
sudoers.d/tyrell: eliminado
R
bash /opt/lab/check.sh
```

## Más allá del lab

- Automatiza el **leaver**: la baja en el IdP revoca cuenta, llaves y grupos en
  todos los sistemas; nada manual que se olvide.
- Audita `authorized_keys` y `sudoers.d` periódicamente contra un inventario;
  una llave sin dueño es una puerta sin cerradura.
- `userdel -r` borra el home (y sus llaves); `passwd -l` sólo bloquea el login:
  elige según tu política de retención.
