# Resolución guiada · Lab 09

:::piensa Antes de tocar nada
Un log vacío en un servidor que lleva tiempo funcionando **no es normal**. No significa "no pasó nada": significa "alguien no quiere que lo veas". Y borrar todo rastro es muy difícil: los sistemas guardan la misma información en varios sitios. Tu pregunta guía: **¿dónde más quedó escrito?**
:::

## Paso 1 · Confirma la manipulación

**Pregúntate:** ¿cómo distingo un log vacío "porque sí" de uno vaciado? Mira tamaños y fechas, y busca quién ejecutó qué.

**Por qué importa:** la prueba del borrado es evidencia por sí misma (y tiene que ir en el informe).

:::pista Cómo comprobarlo
```bash
ls -la /var/log/auth.log*
sudo cat /root/.bash_history
```
Un `auth.log` de 0 bytes con su copia rotada llena es sospechoso. En el historial de root, busca comandos que vacíen ficheros (`: >`, `> fichero`, `truncate`) o borren el propio historial (`history -c`).
:::

## Paso 2 · Busca fuentes alternativas

**Pregúntate:** ¿qué hace `logrotate` con los logs viejos? Los renombra (`.1`, `.2.gz`…). ¿El atacante se acordó de esos?

**Por qué importa:** el atacante suele limpiar lo obvio y olvidar lo redundante.

:::pista Dónde mirar
```bash
cat /var/log/auth.log.1
zcat /var/log/auth.log.*.gz 2>/dev/null | head
last 2>/dev/null | head
```
Busca `Accepted` en la copia rotada: ahí estará la IP que borró del log actual.
:::

## Paso 3 · Documenta con fuente

**Pregúntate:** si alguien revisa tu informe, ¿puede repetir cómo llegaste al dato?

**Por qué importa:** en forense, un dato sin fuente no vale. "La IP es X" debe ir con "sacado de Y".

:::pista Formato
```bash
cat > ~/hallazgos.txt <<EOF
IP del intruso: <IP>
Fuente: <fichero de donde la sacaste>
Evidencia de borrado: <comando que encontraste en el historial>
EOF
bash /opt/lab/check.sh
```
:::

## Cómo actuar en una situación así

- **No trabajes sobre el original**: copia los logs (`cp -a`) antes de analizarlos.
- **Lista de fuentes redundantes**: logs rotados, `wtmp`/`btmp` (`last`, `lastb`), historiales de shell de cada usuario, `journalctl`, y el syslog central si existe.
- **El borrado es un hallazgo**: indica que el atacante tenía root y sabía lo que hacía.
- Prevención: enviar logs a un servidor central en tiempo real. Lo que ya salió de la máquina no se puede borrar desde ella.

## Si te atascas

- No ves el historial de root: necesitas `sudo`.
- No encuentras la IP: `grep -h Accepted /var/log/auth.log*`.
