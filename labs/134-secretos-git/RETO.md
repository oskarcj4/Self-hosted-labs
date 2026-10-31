# Secretos en el historial de git

> Hardening web · gitleaks · trufflehog · rotación · pre-commit

## Escenario

`/srv/repos/pagos` se va a publicar (`~/ticket/SEC-134.txt`). Alguien
dice que "hace tiempo se subieron credenciales, pero ya se borraron".
Borrar un fichero en un commit nuevo **no** lo borra del historial:
cualquiera que clone el repo puede hacer `git log -p` y leerlo.

La regla de oro: **una credencial que ha tocado un repositorio está
comprometida. Se rota (se revoca y se emite otra), siempre.** Reescribir el
historial (`git filter-repo`) es un extra opcional; sin rotar no sirve de
nada, porque ya puede haber copias del repo.

## Objetivos

1. Escanea **todo el historial** con `gitleaks` y guarda el informe en
   `~/gitleaks.json`. Compáralo con `trufflehog` si quieres.
2. En `~/secretos.txt` anota cada credencial: tipo (AWS, GitHub, Stripe) y
   commit (hash corto) donde se introdujo.
3. Rota las tres con `rotar-secreto <valor>` (simula al proveedor).
4. Deja el código actual sin credenciales (léelas del entorno) y commitea.
5. Instala un hook `pre-commit` que ejecute gitleaks sobre lo que vas a
   commitear y bloquee si encuentra algo.

## Comandos que te pueden servir

```bash
cd /srv/repos/pagos
git log --oneline --all ; git log -p -- config/aws.py ; git show <commit>
gitleaks detect --source . -v
gitleaks detect --source . --report-format json --report-path ~/gitleaks.json
trufflehog git file:///srv/repos/pagos --no-verification --no-update
jq -r '.[] | "\(.RuleID) \(.Commit[0:7]) \(.File)"' ~/gitleaks.json
gitleaks protect --staged -v           # lo que va en el hook
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
