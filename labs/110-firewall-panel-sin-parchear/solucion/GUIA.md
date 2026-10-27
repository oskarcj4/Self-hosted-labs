# Resolución guiada · Lab 110 (vía BLUE)

:::piensa
Solo doy el blindaje (blue). La vía red (cómo cruzar) es tuya; el servidor
valida las banderas que entregues. El firewall NO se toca: está bien.
:::

## Qué está mal

No es el firewall (lista blanca correcta: solo `80` y el panel `10000`; `22` y
`8080` cerrados). Lo que está mal es el **nivel de parche** del panel expuesto:

- **Webmin 1.920** en `:10000` es vulnerable a **CVE-2019-15107**: RCE no
  autenticado por inyección del parámetro `old` en `password_change.cgi`
  (un `qx//` de Perl). Como miniserv corre como root, la ejecución es como
  **root**. El atacante no salta ninguna regla: cruza por el servicio que el
  firewall permite, porque está sin actualizar.

## El arreglo: actualizar

La corrección es subir a **Webmin 1.930+** (quitó el `qx()`). El paquete ya
está en el appliance:

```bash
webmin-update
cat /usr/share/webmin/version   # >= 1.930
bash /opt/lab/check.sh
```

El validador comprueba que:

1. el firewall sigue correcto (`:80` y `:10000` arriba, `:22`/`:8080` cerrados),
2. el panel sigue sirviendo en `:10000` (no vale apagarlo),
3. la versión es `>= 1.930`,
4. el exploit del CVE ya no ejecuta código.

## Principios que deja el lab

- **El perímetro incluye el parcheo.** Un firewall impecable no te salva de un
  servicio expuesto con un RCE público.
- **Inventario y CVEs.** Conoce la versión de cada servicio que expones y sigue
  sus avisos (CISA KEV, vendor).
- **Menos superficie de gestión.** Paneles de administración detrás de VPN o
  bastion, no expuestos directamente a la red.
- **Ante un CVE conocido, actualiza.** Es la respuesta correcta, no el parche
  manual a ciegas.
