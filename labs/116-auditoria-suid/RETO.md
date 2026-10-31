# Auditoría de binarios SUID

> Defensa del host · find -perm · dpkg -S · capabilities

## Escenario

Auditoría mensual de privilegios en `srv-116`. En `~/auditoria/` tienes la
**referencia** que se guardó con el sistema recién instalado: la lista de
SUID y la de capabilities de fichero. Toca comparar con el estado actual.
Un SUID root inesperado es un atajo a root para cualquiera que lo ejecute.

## Objetivos

1. Saca la lista actual de SUID y compárala con la referencia.
2. Para cada diferencia, averigua si pertenece a un paquete (`dpkg -S`) y qué
   es en realidad.
3. Revisa también las **capabilities** de fichero: no salen con
   `-perm -4000` y dan privilegios igual.
4. Corrige sin romper el sistema: los SUID legítimos (`sudo`, `passwd`,
   `su`...) se quedan; a un binario de paquete se le quita el bit, no se
   borra; las copias sueltas se retiran de su sitio (a cuarentena).
5. Documenta cada hallazgo en `~/auditoria/informe.txt` (ruta completa).

## Comandos que te pueden servir

```bash
sudo find / -xdev -perm -4000 -type f 2>/dev/null | sort > /tmp/actual.txt
diff ~/auditoria/referencia-suid.txt /tmp/actual.txt
dpkg -S /ruta/binario ; file /ruta/binario ; sha256sum /ruta/binario
sudo chmod u-s /ruta/binario
sudo getcap -r / 2>/dev/null ; sudo setcap -r /ruta/binario
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
