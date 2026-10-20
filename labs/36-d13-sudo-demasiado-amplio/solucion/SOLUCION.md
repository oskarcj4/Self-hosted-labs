# Solución — Día 13: Reducir un sudo demasiado amplio

## 1. Inventario

```bash
sudo -l -U deploy
#   (ALL : ALL) ALL                  <- grupo sudo (%sudo en /etc/sudoers)
#   (ALL) NOPASSWD: ALL              <- /etc/sudoers.d/40-deploy-temp
id deploy                            # ... 27(sudo)
ls -l /usr/local/sbin/rotate-app-logs   # -rwxrwxr-x deploy deploy  <- ¡lo puede editar!
```

Son **tres** vías a root: la regla temporal, el grupo `sudo` y el script editable.

## 2. Regla mínima

```bash
sudo tee /etc/sudoers.d/40-deploy.tmp >/dev/null <<'EOF'
# deploy: sólo rotar logs de la app (pipeline, sin contraseña)
deploy ALL=(root) NOPASSWD: /usr/local/sbin/rotate-app-logs ""
EOF
sudo visudo -cf /etc/sudoers.d/40-deploy.tmp \
  && sudo install -m 0440 /etc/sudoers.d/40-deploy.tmp /etc/sudoers.d/40-deploy \
  && sudo rm /etc/sudoers.d/40-deploy.tmp /etc/sudoers.d/40-deploy-temp
```

- `(root)` en vez de `(ALL)`: sólo como root, no como cualquier usuario.
- Ruta absoluta del comando.
- `""` al final: **no admite argumentos** (sin él, `deploy` podría pasarle lo que quisiera).
- Validar con `visudo -cf` **antes** de ponerlo en su sitio.

## 3. Fuera del grupo sudo

```bash
sudo gpasswd -d deploy sudo
```

## 4. El script, de root

```bash
sudo chown root:root /usr/local/sbin/rotate-app-logs
sudo chmod 0755 /usr/local/sbin/rotate-app-logs
```

## 5. Verificar

```bash
sudo visudo -c
sudo -l -U deploy          # (root) NOPASSWD: /usr/local/sbin/rotate-app-logs ""
sudo runuser -u deploy -- sudo -n /usr/local/sbin/rotate-app-logs   # rotados: 3
sudo runuser -u deploy -- sudo -n cat /etc/shadow                   # denegado
```

## Lecciones

- "Temporal" en sudoers es permanente hasta que alguien lo audite: pon fecha y ticket, y revísalo.
- Mínimo privilegio en sudo = usuario + **host** + **como quién** + **comando exacto** + **argumentos**.
- Revisa todas las fuentes: `/etc/sudoers`, `/etc/sudoers.d/*`, grupos (`%sudo`, `%admin`).
- Un comando permitido que el usuario puede editar (o que lanza un editor, `less`,
  `find -exec`, `tar --checkpoint-action`…) equivale a `ALL`. Consulta GTFOBins.
