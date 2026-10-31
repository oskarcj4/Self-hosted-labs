# Resolución guiada · Lab 116

:::piensa Antes de tocar nada
Un SUID root o una capability `cap_setuid` en el binario equivocado es una
puerta para volver a ser root. Tienes una referencia de cómo era el sistema:
la diferencia es lo que hay que explicar.
:::

## Paso 1 · ¿Qué SUID hay ahora?

**Pregúntate:** ¿qué busca `-perm -4000` y por qué `-xdev`?

:::pista Cómo comprobarlo
```bash
find / -xdev -perm -4000 -type f 2>/dev/null | sort > /tmp/actual.txt
diff ~/auditoria/referencia-suid.txt /tmp/actual.txt
```
:::

## Paso 2 · ¿Y capabilities?

**Pregúntate:** un binario sin SUID puede hacerse root igual. ¿Con qué?

:::pista Cómo comprobarlo
```bash
getcap -r / 2>/dev/null
```
Un `python3` con `cap_setuid+ep` hace `os.setuid(0)` y abre una shell de root.
:::

## Paso 3 · ¿De dónde viene cada uno?

**Pregúntate:** ¿es un fichero de un paquete con un bit añadido, o una copia que no pertenece a ningún paquete?

:::pista Cómo comprobarlo
```bash
dpkg -S /tmp/.cache/.dbus-helper     # sin paquete: copia
dpkg -S /usr/bin/vim.basic           # paquete legítimo, bit añadido
```
Consulta GTFOBins: `find`, `vim` y `python` dan shell si son SUID o tienen capability.
:::

## Paso 4 · Quita y pon en cuarentena

:::pista Cómo hacerlo
```bash
sudo mkdir -p /root/cuarentena
sudo chmod u-s /tmp/.cache/.dbus-helper; sudo mv /tmp/.cache/.dbus-helper /root/cuarentena/
sudo chmod u-s /usr/bin/vim.basic
sudo setcap -r /usr/local/lib/.pyhelper; sudo mv /usr/local/lib/.pyhelper /root/cuarentena/
nano ~/auditoria/informe.txt
```
No quites el SUID de `passwd`, `su` o `sudo`: están en la referencia por algo.
:::

## Cómo actuar en una situación así

- **Ten una referencia** de SUID/capabilities y compárala periódicamente.
- **Monta /tmp, /home y /var/tmp con `nosuid`**.
- Un SUID nuevo casi nunca es un accidente: busca cómo llegó y quién lo usó.

## Si te atascas

- `diff` saca mucho: ordena ambas listas con `sort`.
- `getcap` no existe: está en `libcap2-bin`, ya instalado como `/usr/sbin/getcap`.
