# Solución — Fechas manipuladas (timestomping)

## Qué pasaba

El intruso añadió `backup-sync` y modificó `rotate-logs` en `/usr/local/bin`,
y luego les puso con `touch -d` una mtime antigua. `ls -l` y `find -newer` no
ven nada; el ctime de ambos es posterior al último despliegue.

## Arreglo

```bash
find /usr/local/bin -cnewer /var/log/deploy/ultimo.log -type f
for f in $(find /usr/local/bin -cnewer /var/log/deploy/ultimo.log -type f); do
  echo "$f  ctime=$(stat -c %z "$f")  mtime=$(stat -c %y "$f")"
done > ~/fechas.txt

sudo mkdir -p /root/cuarentena && sudo mv /usr/local/bin/backup-sync /root/cuarentena/
sudo tar -C /tmp -xzf /var/backups/usr-local-bin.tar.gz bin/rotate-logs
sudo install -m 0755 /tmp/bin/rotate-logs /usr/local/bin/rotate-logs
bash /opt/lab/check.sh
```

## Más allá del lab

- `debsums` / AIDE detectan el cambio por contenido, sin depender de fechas.
- Algunos sistemas de ficheros guardan `birth` (`stat -c %w`): otra marca más.
- Si el atacante cambió el reloj del sistema, el journal muestra el salto de hora.
