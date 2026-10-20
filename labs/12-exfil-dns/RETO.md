# Lab 12 — Datos saliendo por DNS

## Escenario

El firewall de `web-12` bloquea casi todo el tráfico saliente… menos el DNS
(puerto 53), porque "el DNS hace falta para todo". Los atacantes lo saben: meten
los datos robados dentro de los **nombres de subdominio** que consultan, y así
los exfiltran por DNS sin tocar HTTP. En el log de consultas hay un patrón
sospechoso: miles de subdominios larguísimos, codificados, hacia el mismo
dominio. Encuéntralo y bloquéalo.

## Objetivos

1. **Analiza `/var/log/dnsquery.log`** y detecta el dominio usado para
   exfiltrar (subdominios largos, aleatorios/base32, altísima frecuencia).
2. **Bloquéalo**: añade el dominio a `/etc/dns-blocklist.conf` (una línea
   `address=/<dominio>/0.0.0.0`).
3. **Documenta el dominio** en `~/hallazgos.txt`.

## Comandos que te pueden servir

```bash
head /var/log/dnsquery.log
# el nombre consultado es el campo antes de 'IN A' -> $(NF-2)
# agrupa por dominio base (últimas 2 etiquetas) y cuenta:
awk '{print $(NF-2)}' /var/log/dnsquery.log | awk -F. '{print $(NF-1)"."$NF}' \
  | sort | uniq -c | sort -rn | head
# longitud media de las etiquetas por dominio (exfil = etiquetas largas)
```

> DNS legítimo: pocas consultas, nombres cortos y repetidos (`www.google.com`).
> Exfiltración: miles de consultas con subdominios largos y únicos al mismo
> dominio base.

## Escribe tu informe

```bash
echo "Dominio de exfiltracion: <dominio>" > ~/hallazgos.txt
echo "address=/<dominio>/0.0.0.0" | sudo tee -a /etc/dns-blocklist.conf
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
