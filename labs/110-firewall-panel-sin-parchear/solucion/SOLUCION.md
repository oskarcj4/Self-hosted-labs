# Solución — Firewall correcto, panel sin parchear (vía BLUE)

> Solo el blindaje. La explotación (RED) la resuelves tú.

## Por qué se podía cruzar el firewall

El firewall **no** era el fallo: lista blanca, política `DROP`, solo `80` y el
panel `10000` expuestos; `22` y `8080` internos realmente cerrados. No hay regla
que arreglar.

El problema es de **gestión de parches**. El panel de administración expuesto,
**Webmin 1.920**, es vulnerable a **CVE-2019-15107** (RCE no autenticado,
CVSS 9.8, exploit público y en el catálogo KEV de CISA):

- En `password_change.cgi`, el parámetro `old` se interpola en un `qx//` de
  Perl sin saneo. Con la función de cambio de contraseña caducada activa
  (`passwd_mode=2` en `/etc/webmin/miniserv.conf`), ese CGI es alcanzable
  **sin autenticación**.
- Una petición `POST` con `old=test|<comando>` ejecuta `<comando>` como
  **root** (miniserv corre como root). Así se cruza el firewall: no se salta
  una regla, se abusa del servicio que el firewall sí deja entrar.

## Arreglo: actualizar

La corrección oficial es **actualizar Webmin a 1.930 o superior** (1.930 quitó
ese `qx()`). El paquete parcheado está en el appliance:

```bash
webmin-update                 # instala Webmin 1.930 y reinicia el panel
cat /usr/share/webmin/version # debe decir >= 1.930
bash /opt/lab/check.sh
```

Mitigación temporal si no se pudiera actualizar al momento: desactivar la
función de cambio de contraseña (`passwd_mode=0`) y/o restringir el `10000` a
redes de gestión. Pero la solución real es el parche.

## Más allá del lab

- **El perímetro incluye el nivel de parche.** Un firewall perfecto no protege
  de un servicio que sí permites si ese servicio tiene un RCE conocido.
- **Inventario + CVEs + ventana de parcheo.** Saber qué versión corre cada
  servicio expuesto y seguir sus avisos (CISA KEV, vendor advisories) es
  control de primera línea.
- **Reduce la superficie de gestión.** Paneles como Webmin en `10000` mejor
  detrás de VPN / bastion, no expuestos directamente.
- **Defensa en capas.** VPN para gestión + parcheo + mínimo privilegio: si una
  capa falla, las otras aguantan.

## Lecciones

- "Firewall bien configurado" ≠ "perímetro seguro": el software expuesto cuenta.
- Las versiones viejas con CVE público son la vía de entrada más común y barata.
- La respuesta correcta a un CVE conocido es **actualizar**, no parchear a mano.

## Referencias

- CVE-2019-15107 — Rapid7: <https://www.rapid7.com/db/vulnerabilities/cve-2019-15107/>
- Tenable (módulos de exploit disponibles): <https://www.tenable.com/blog/cve-2019-15107-exploit-modules-available-for-remote-code-execution-vulnerability-in-webmin>
- Análisis técnico (chybeta): <https://chybeta.github.io/2019/08/19/%E3%80%90CVE-2019-15107%E3%80%91-RCE-in-Webmin-1-920-via-password-change/>
