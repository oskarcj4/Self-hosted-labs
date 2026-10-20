# Lab 09 — El log que el atacante borró

## Escenario

En `web-09` hubo una intrusión, pero cuando vas a `/var/log/auth.log`… está
**vacío**. El atacante lo truncó para borrar su rastro. En forense, un borrado
es en sí mismo una pista: casi siempre queda evidencia en **otra parte** (copias
rotadas, historial de la shell, procesos aún vivos). Tu trabajo es reconstruir
desde qué IP entró, usando fuentes que el atacante olvidó limpiar.

## Objetivos

1. **Confirma que `auth.log` fue manipulado** (está truncado) y encuentra la
   prueba del borrado.
2. **Recupera la IP del intruso** desde una fuente alternativa (una copia rotada
   del log, el historial de comandos de root, etc.).
3. **Documenta en `~/hallazgos.txt`** la IP del intruso **y** la fuente de donde
   la recuperaste.

## Comandos que te pueden servir

```bash
ls -la /var/log/auth.log*            # ¿tamaño 0? ¿hay un auth.log.1?
cat /var/log/auth.log.1              # la copia rotada que no borró
sudo cat /root/.bash_history         # ¿qué comandos corrió root?
last 2>/dev/null                     # sesiones (si hay wtmp)
```

## Escribe tu informe

```bash
cat > ~/hallazgos.txt <<EOF
IP del intruso: <la que recuperaste>
Fuente: <de donde la sacaste, p.ej. auth.log.1>
Evidencia de borrado: <el comando que vaci o el log>
EOF
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
