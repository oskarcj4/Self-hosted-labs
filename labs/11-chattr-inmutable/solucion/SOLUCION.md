# Solución — Lab 11

## 1. Por qué `rm` falla

```bash
sudo rm -f /data/.payload
# rm: cannot remove '/data/.payload': Operation not permitted
lsattr /data/.payload
# ----i--------------- /data/.payload   <- la 'i' = inmutable
```

Ni root puede borrar un archivo inmutable: el atributo lo impone el sistema de
archivos, por encima de los permisos Unix.

## 2 y 3. Quitar el atributo y borrar

```bash
sudo chattr -i /data/.payload
lsattr /data/.payload          # ya sin la 'i'
sudo rm -f /data/.payload      # ahora sí
```

## Verifica

```bash
bash /opt/lab/check.sh
```

## Lecciones

- `chattr +i` es persistencia/anti-borrado de libro. Si un `rm` falla siendo
  root, revisa `lsattr` antes de pelearte con los permisos.
- El mismo truco se usa en sentido defensivo: proteger archivos críticos
  (`/etc/passwd`, binarios) con `+i` para que un atacante no los modifique.
- Audita atributos: `lsattr -R /etc /bin /usr/bin 2>/dev/null | grep ' i'`.
