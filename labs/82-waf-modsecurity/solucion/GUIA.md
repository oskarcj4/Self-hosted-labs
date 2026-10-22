# Resolución guiada · Lab 82

:::piensa Antes de tocar nada
Un WAF en `DetectionOnly` es teatro: llena el log pero no para nada. En Debian el paquete ya deja el OWASP CRS cargado; el único interruptor que falta es el **modo del motor**. `DetectionOnly` → mira; `On` → actúa. No hace falta tocar includes (y si los duplicas, rompes Apache por IDs de regla repetidos).
:::

## Paso 1 · Confirma qué hay cargado

```bash
sudo apache2ctl -M | grep -i security2          # security2_module presente
grep SecRuleEngine /etc/modsecurity/modsecurity.conf   # DetectionOnly
# El CRS ya viene incluido por el paquete:
grep -n modsecurity-crs /etc/apache2/mods-available/security2.conf
```

## Paso 2 · Mira que en DetectionOnly NO bloquea

```bash
curl -s -o /dev/null -w '%{http_code}\n' "http://127.0.0.1/?q=1%27+OR+%271%27=%271"   # 200 (no bloquea)
sudo tail /var/log/apache2/error.log   # pero SÍ lo registra: "Matched ... SQL Injection"
```

## Paso 3 · Enciende el motor

**Pregúntate:** ¿quiero que mire o que actúe?

:::pista Cómo hacerlo
```bash
sudo sed -i 's/^SecRuleEngine.*/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf
sudo apache2ctl -t
sudo service apache2 restart
```
:::

## Paso 4 · Comprueba que ahora bloquea

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1/                        # 200 legítimo
curl -s -o /dev/null -w '%{http_code}\n' "http://127.0.0.1/?q=1%27+OR+%271%27=%271" # 403 bloqueado
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Secuencia segura en producción:** despliega el CRS en `DetectionOnly`, revisa
  en el log los **falsos positivos** (tráfico legítimo que dispararía reglas),
  crea exclusiones, y recién entonces pasa a `On`. Aquí vamos directos porque el
  tráfico es simple.
- **No dupliques includes.** El CRS tiene IDs de regla únicos; cargarlo dos veces
  hace fallar `apache2ctl -t` y Apache no arranca.
- **Paranoia Level**: el CRS escala de 1 (menos falsos positivos) a 4 (más
  estricto) en `crs-setup.conf`. Súbelo con cabeza.
- El WAF frena **capa 7** (inyección, XSS, scanners, abuso de endpoints), no un
  flood volumétrico de capa 3/4: eso es firewall/CDN (labs 83/84, curso 14).
- Mantén el CRS actualizado: reglas viejas = agujeros nuevos.
