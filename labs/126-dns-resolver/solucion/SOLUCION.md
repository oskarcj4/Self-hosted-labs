# Solución — DNS: ¿quién te está respondiendo?

## Qué pasaba

`/etc/resolv.conf` apuntaba a `10.126.0.99`, un dnsmasq falso que respondía
`portal.empresa.lab → 10.126.0.66`. El resolver legítimo `10.126.0.53` (unbound
validando DNSSEC sobre la zona firmada por bind9) responde `10.126.0.80`.

## Arreglo

```bash
F=$(dig +short portal.empresa.lab)
R=$(dig +short @10.126.0.53 portal.empresa.lab)
N=$(dig +short -x 10.126.0.25 @10.126.0.53 | sed 's/\.$//')
printf 'resolver_actual=10.126.0.99\nportal_falso=%s\nportal_real=%s\nnombre_25=%s\n' "$F" "$R" "$N" > ~/dns.txt
echo 'nameserver 10.126.0.53' | sudo tee /etc/resolv.conf
dig +dnssec portal.empresa.lab > ~/dnssec.txt
bash /opt/lab/check.sh
```

Respuestas: `portal_real=10.126.0.80`, `nombre_25=backup-nas.empresa.lab`.

## Más allá del lab

- Averigua cómo cambió `resolv.conf`: un DHCP falso (lab 131) es la causa típica.
- Bloquea en el firewall el DNS saliente que no vaya a tus resolvers.
