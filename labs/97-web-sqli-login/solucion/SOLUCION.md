# Solución — Portal con SQLi en el login (vía BLUE)

> Aquí solo está el arreglo. La vía RED (capturar la flag) la resuelves tú;
> el validador la reconoce cuando lo logras.

## Causa

`username` y `password` se concatenan dentro de la cadena SQL. El atacante
controla parte de la consulta: puede cerrar el literal de cadena y añadir
lógica (`' OR '1'='1`), comentar el resto (`-- `) o pegar un `UNION SELECT`.

## Arreglo: consultas parametrizadas

```python
q = ("SELECT username, role, flag FROM users "
     "WHERE username = ? AND password = ?")
rows = cur.execute(q, (user, password)).fetchall()
```

El motor recibe la plantilla y los valores por separado; la entrada se trata
siempre como dato, nunca como SQL. Es la única defensa completa contra SQLi;
escapar comillas a mano se escapa casos.

## Por qué esto no es "defensa en profundidad" completa

- **Mínimo privilegio en la query:** el login no necesita leer la columna
  `flag` ni la fila de `admin`. `SELECT ... WHERE role != 'admin'` o tablas
  separadas limitan el daño de un fallo futuro.
- **No guardes claves en claro:** aquí las comparamos directas. En real,
  hash con `argon2`/`bcrypt` y comparar el hash.
- **No devuelvas secretos en la respuesta:** la app soltaba la flag en el
  cuerpo. Un endpoint no debería incluir datos que el rol no necesita ver.
- **Errores SQL silenciados:** devolver el `sqlite3.Error` al cliente da pistas
  al atacante (inyección basada en errores).

## Lecciones

- La entrada del usuario es dato, nunca código. Parametriza **siempre**.
- Un WAF o un filtro de comillas es un parche; el fix está en cómo se
  construye la consulta.
- Principio de mínima exposición: la respuesta solo debe contener lo que ese
  usuario tiene que ver.
