# Solución — Auditoría de SUID y capabilities

## Qué pasaba

Tres puertas traseras respecto a la referencia:

| Fichero | Qué es |
|---|---|
| `/tmp/.cache/.dbus-helper` | copia de `find` con SUID root, sin paquete |
| `/usr/bin/vim.basic` (o `vim.tiny`) | binario legítimo con SUID añadido |
| `/usr/local/lib/.pyhelper` | copia de `python3` con `cap_setuid+ep` |

## Arreglo

```bash
find / -xdev -perm -4000 -type f 2>/dev/null | sort > /tmp/actual.txt
diff ~/auditoria/referencia-suid.txt /tmp/actual.txt
getcap -r / 2>/dev/null
VIM=$(ls /usr/bin/vim.basic /usr/bin/vim.tiny 2>/dev/null | head -1)

sudo mkdir -p /root/cuarentena
sudo chmod u-s /tmp/.cache/.dbus-helper && sudo mv /tmp/.cache/.dbus-helper /root/cuarentena/
sudo chmod u-s "$VIM"
sudo setcap -r /usr/local/lib/.pyhelper && sudo mv /usr/local/lib/.pyhelper /root/cuarentena/
nano ~/auditoria/informe.txt     # una línea por hallazgo: ruta, qué era, qué hiciste
bash /opt/lab/check.sh
```

## Más allá del lab

- `nosuid` en los puntos de montaje escribibles por usuarios.
- Integra la comparación en tu monitor de integridad (AIDE la hace).
- Si hubo SUID de root, asume que el atacante fue root: revisa persistencia.
