# Resolución guiada · Servicio caído tras un reinicio

:::piensa Antes de tocar nada
Un reinicio dejó la tienda caída. Dos cosas distintas pueden explicarlo y aquí
pasan las dos: la config de nginx está **rota** (por eso no arranca) y los
servicios no estaban **habilitados** (por eso el reinicio los dejó muertos).
No adivines el error: haz que las herramientas te lo digan.
:::

## Paso 1 · Mira el estado real, sin suposiciones

**Pregúntate:** ¿está parado, o arranca y se cae? ¿Y arrancará solo la próxima vez?

```bash
systemctl status nginx shop-api
systemctl is-enabled nginx shop-api
```

`inactive (dead)` + `disabled` en ambos. Dos problemas: no están arrancados y
no están habilitados.

## Paso 2 · Deja que nginx te diga qué está mal

**Pregúntate:** ¿por qué no arranca nginx? La respuesta exacta está en `nginx -t`.

:::pista Cómo comprobarlo
```bash
sudo nginx -t
```
```
nginx: [emerg] invalid number of arguments in "proxy_pass" directive in
/etc/nginx/sites-enabled/shop:13
```
`nginx -t` muestra **un** error cada vez, con fichero y línea. Arregla ese y
vuelve a lanzarlo: aparecerá el siguiente.
:::

## Paso 3 · Primer fallo: falta un `;`

**Pregúntate:** nginx dice línea 13, pero el error real suele estar **antes**.
En la 12 falta el `;` de `proxy_pass`, así que nginx engancha la línea de abajo
como si fuera la misma directiva.

:::pista Cómo arreglarlo
```bash
sudo nano /etc/nginx/sites-available/shop   # añade el ; al final de proxy_pass
sudo nginx -t                                # ahora sale el SEGUNDO error
```
:::

## Paso 4 · Segundo fallo: una "copia" que nginx carga igual

**Pregúntate:** `nginx.conf` incluye `sites-enabled/*`. ¿Qué pasa con un
`shop.bak` ahí dentro?

```
nginx: [emerg] a duplicate default server for 0.0.0.0:80 in
/etc/nginx/sites-enabled/shop.bak:2
```

El `*` carga **todos** los ficheros, también el `.bak`, que define un segundo
`default_server`. Una copia de seguridad en ese directorio no es inofensiva.

:::pista Cómo arreglarlo
```bash
sudo mkdir -p /root/nginx-backups
sudo mv /etc/nginx/sites-enabled/shop.bak /root/nginx-backups/
sudo nginx -t          # test is successful
```
Saca las copias **fuera** de cualquier directorio que se cargue con `*`.
:::

## Paso 5 · Arranca y habilita (en el orden correcto)

**Pregúntate:** `start` arregla el ahora; ¿qué arregla el próximo reinicio?
`enable`. `enable --now` hace las dos. Y arranca **primero el backend**: si
nginx levanta antes que `shop-api`, los primeros usuarios ven `502`.

:::pista Cómo hacerlo
```bash
sudo systemctl enable --now shop-api nginx
systemctl is-enabled nginx shop-api    # enabled / enabled
```
:::

## Paso 6 · Verifica como un usuario real

```bash
curl -i http://127.0.0.1/                 # portada de la tienda
curl -s http://127.0.0.1/api/health       # shop-api ok (pasando por el proxy)
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **`active` ≠ `enabled`.** Lo que sobrevive a un reinicio es `enable`.
- **`nginx -t` antes de cada `reload`/`restart`.** Un `reload` con config rota
  falla sin tirar el servicio; un `restart` con config rota lo deja caído.
- **Nunca guardes copias** en `sites-enabled/`, `conf.d/` ni nada que cargue
  con `*`. Guárdalas fuera, o usa git (`etckeeper`).
- Tras parchear y reiniciar, comprueba siempre los críticos: `systemctl
  --failed` y una petición de verdad.

## Si te atascas

- `nginx -t` sigue fallando: lee el fichero y la línea que indica; arregla
  **uno** y repite.
- Servicios `active` pero `disabled`: te faltó `enable` (usa `enable --now`).
- `/api/health` no responde: ¿arrancaste `shop-api` antes que nginx?
