# Solución — Lab 09

## 1. Confirmar el borrado

```bash
ls -la /var/log/auth.log*
# auth.log tiene tamaño 0; existe auth.log.1 con contenido
sudo cat /root/.bash_history
# aparece:  : > /var/log/auth.log   (el comando que vació el log)  y  history -c
```

## 2. Recuperar la IP desde la copia rotada

```bash
cat /var/log/auth.log.1
# Accepted password for root from 91.219.236.12 ...
```

El atacante vació `auth.log` pero olvidó la copia rotada `auth.log.1`. Ahí está
el `Accepted password ... from 91.219.236.12`.

## 3. Documentar

```bash
cat > ~/hallazgos.txt <<EOF
IP del intruso: 91.219.236.12
Fuente: /var/log/auth.log.1 (copia rotada que el atacante no borró)
Evidencia de borrado: ': > /var/log/auth.log' en /root/.bash_history, + history -c
EOF
bash /opt/lab/check.sh
```

## Lecciones

- Un log vacío no es ausencia de evidencia: es evidencia de manipulación.
- Fuentes redundantes: logs rotados (`.1`, `.gz`), `wtmp`/`btmp` (`last`/`lastb`),
  historiales de shell, journald en disco, y copias remotas (syslog central).
- Por eso en producción los logs se envían a un servidor central **inmutable**:
  el atacante no puede borrar lo que ya salió de la máquina.
