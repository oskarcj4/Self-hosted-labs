# Inventario de persistencia (forense de artefactos)

> Defensa del host · systemd · cron · dotfiles · IOCs

## Escenario

El intruso ya no tiene sesión en `web-123`, pero hay que asumir que dejó
formas de volver (`~/ticket/IR-123.txt`). Echarlo no sirve de nada si en
5 minutos un cron lo vuelve a llamar. Toca recorrer **todos** los sitios donde
algo puede quedarse instalado, sin romper lo legítimo.

## Objetivos

1. Revisa servicios habilitados, unidades propias, cron del sistema y de
   **cada** usuario, dotfiles y llaves SSH.
2. Analiza lo sospechoso sin ejecutarlo: decodifica lo que esté en base64 y
   saca los indicadores (dominios).
3. Documenta en `~/iocs.txt` cada punto de persistencia (ruta o
   ubicación) y los dominios decodificados.
4. Elimina sólo lo malicioso (guarda copia como evidencia). Lo legítimo se
   queda: backup de root, `/etc/cron.d/nginx-check`, la llave
   `admin@empresa`, nginx/cron/ssh habilitados y el resto del `.bashrc`.

## Comandos que te pueden servir

```bash
systemctl list-unit-files --state=enabled
ls -la /etc/systemd/system/ ; systemctl cat <unidad>
for u in $(cut -d: -f1 /etc/passwd); do sudo crontab -l -u $u 2>/dev/null | sed "s/^/$u: /"; done
ls -la /etc/cron.d/ /etc/cron.*/
grep -n '' /home/*/.bashrc /root/.bashrc /etc/profile.d/*
echo '<cadena>' | base64 -d      # decodifica, NO lo pases a sh
strings <binario> ; file <ruta>
sudo cat /root/.ssh/authorized_keys /home/*/.ssh/authorized_keys
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
