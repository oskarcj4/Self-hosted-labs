# Solución — Pipeline de Jenkins desde Gitea

| Problema | Arreglo |
|----------|---------|
| Pipeline pegado en la web | `Jenkinsfile` en el repo + job *Pipeline script from SCM* (`*/main`) |
| Contraseña de Gitea en claro | token `read:repository` como credencial `gitea` (JCasC, `${readFile:...}`) |
| Se lanza a mano | webhook de Gitea a `/job/tienda/build` con `Authorization: Basic admin:<API token>` |
| Sin tests | etapa `Tests` con `node --test` y reporter JUnit, publicada con `junit` |
| Todo en serie | `parallel { Tests; Frontend }` |
| Descuento mal calculado | `subtotal * (1 - descuento / 100)` |

Todo automatizado (token, JCasC, job por la API REST, webhook y Jenkinsfile) en `solve.sh`.

## Notas

- **Token de sólo lectura**: si Jenkins se ve comprometido, el token no sirve
  para empujar código. La contraseña de `analista` sí.
- **`/job/X/build` frente a `notifyCommit`**: el plugin Git ofrece
  `/git/notifyCommit?url=...`, que fuerza un *poll* de los jobs con ese repo;
  necesita *SCM polling* activado y un token de notifyCommit. Para un solo job,
  llamar a `/build` es directo.
- **Multibranch**: el siguiente paso natural es un job *Multibranch Pipeline*
  (o el plugin de Gitea), que crea un job por rama o PR y permite
  `when { branch 'main' }`.
- **`disableConcurrentBuilds()`**: dos pushes seguidos no despliegan a la vez.
