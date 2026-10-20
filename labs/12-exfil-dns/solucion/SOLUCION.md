# Solución — Lab 12

## 1. Detectar el dominio de exfiltración

```bash
awk '{print $(NF-2)}' /var/log/dnsquery.log \
  | awk -F. '{print $(NF-1)"."$NF}' | sort | uniq -c | sort -rn | head
```

(En este log el nombre consultado es el penúltimo campo, antes de `IN A`.) El
dominio `cdn-sync.io` aparece cientos de veces, siempre con subdominios distintos
y larguísimos codificados en base32: firma inequívoca de exfiltración por DNS.

```bash
grep cdn-sync.io /var/log/dnsquery.log | head
```

## 2. Bloquearlo

```bash
echo "address=/cdn-sync.io/0.0.0.0" | sudo tee -a /etc/dns-blocklist.conf
```

## 3. Documentar

```bash
echo "Dominio de exfiltracion: cdn-sync.io" > ~/hallazgos.txt
bash /opt/lab/check.sh
```

## Lecciones

- DNS es un canal de exfiltración favorito porque casi nunca se filtra. Vigila
  **volumen** de consultas, **longitud/entropía** de los subdominios y dominios
  recién registrados.
- Defensa: DNS sinkhole / RPZ, límites de tasa, y registrar + analizar todas las
  consultas en un resolver central.
