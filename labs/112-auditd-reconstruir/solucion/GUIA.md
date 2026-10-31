# Resolución guiada · Lab 112

:::piensa Antes de tocar nada
auditd registra dos identidades: el `uid` con el que corre el proceso y el
`auid`, el usuario que **inició sesión**. Un `sudo` cambia el primero, nunca el
segundo. Esa diferencia es la que te dice quién fue.
:::

## Paso 1 · ¿Qué claves hay en el log?

**Pregúntate:** las reglas de auditoría llevan una etiqueta (`-k`). ¿Qué etiquetas aparecen en `audit.log`?

:::pista Cómo comprobarlo
```bash
sudo aureport -k --summary
sudo aureport -x --summary        # ejecutables
sudo aureport -au                 # autenticaciones
```
:::

## Paso 2 · ¿Quién tocó shadow y sudoers?

**Pregúntate:** dos personas usaron root esa noche. ¿Qué campo separa al operador del intruso?

:::pista Cómo comprobarlo
```bash
sudo ausearch -k claves -i   | grep -E 'auid=|exe=|proctitle'
sudo ausearch -k sudoers -i  | grep -E 'auid=|exe=|proctitle'
```
`-i` traduce uids a nombres. Mira `auid=` y `proctitle=` (la línea de comando).
:::

## Paso 3 · Escribe los hallazgos

**Pregúntate:** ¿qué necesita alguien que no estuvo aquí para entender el incidente? Quién, qué, cuándo, desde dónde.

:::pista Qué anotar
En `~/hallazgos.txt`: el `auid` del intruso y su IP, el `usermod` sobre `backup`,
la línea añadida a `/etc/sudoers`, y qué cambio era del operador legítimo (`chage`).
:::

## Paso 4 · Deshaz sólo lo malicioso

**Pregúntate:** ¿cómo editas sudoers sin dejar el sistema sin sudo si te equivocas?

:::pista Cómo hacerlo
```bash
sudo sed -i '/^backup .*NOPASSWD/d' /etc/sudoers
sudo visudo -c
sudo usermod -s /usr/sbin/nologin -p '*' backup
```
No deshagas el `chage` del operador.
:::

## Paso 5 · Reglas persistentes

**Pregúntate:** `auditctl -w` se pierde al reiniciar. ¿Dónde viven las reglas que sobreviven?

:::pista Cómo hacerlo
```bash
sudo tee /etc/audit/rules.d/50-claves.rules <<'R'
-w /etc/shadow -p wa -k claves
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers
R
sudo augenrules --load; sudo augenrules --check
```
En Docker Desktop `--load` puede dar `EPERM`: el fichero `audit.rules` se genera igual, que es lo que se valida.
:::

## Cómo actuar en una situación así

- **Busca por clave y por auid**, no por uid: todo lo que pasa por sudo es uid 0.
- **Separa intruso de operador** antes de revertir: deshacer un cambio legítimo también es un incidente.
- **Reglas en `rules.d/`**, versionadas y revisadas como cualquier otra configuración.

## Si te atascas

- `ausearch` no devuelve nada: falta `sudo` o te equivocaste de clave (`aureport -k`).
- `visudo -c` falla: no reinicies nada; vuelve a editar hasta que pase.
