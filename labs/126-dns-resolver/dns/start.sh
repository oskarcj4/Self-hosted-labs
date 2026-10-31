#!/bin/bash
# DNS interno del lab 126: bind9 (autoritativo, zona firmada con DNSSEC) en
# 127.0.0.1:5353 + unbound (resolver que valida) en :53 para la red.
set -e
mkdir -p /var/cache/bind/keys
cp /dns/empresa.lab.zone /dns/0.126.10.zone /var/cache/bind/
cp /dns/named.conf /etc/bind/named.conf
named -c /etc/bind/named.conf -g &
for _ in $(seq 1 60); do
  dig @127.0.0.1 -p 5353 +dnssec portal.empresa.lab A | grep -q RRSIG && break
  sleep 1
done
dig @127.0.0.1 -p 5353 +noall +answer empresa.lab DNSKEY > /etc/unbound/empresa.anchor
cp /dns/unbound.conf /etc/unbound/lab.conf
exec unbound -d -c /etc/unbound/lab.conf
