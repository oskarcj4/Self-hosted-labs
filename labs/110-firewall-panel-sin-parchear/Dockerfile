# Lab 110 — target: firewall BIEN configurado, pero el panel de gestión
# (Webmin) está sin parchear. Estilo máquina HTB fácil/media.
#
# El firewall es correcto (lista blanca: solo 80 y el panel 10000; 22 y 8080
# internos bloqueados). No hay que tocarlo. El fallo es que Webmin 1.920 es
# vulnerable a CVE-2019-15107 (RCE no autenticado real, exploit público):
# el parámetro 'old' de password_change.cgi se inyecta en un `qx//` de Perl.
# Se cruza el firewall por ahí y se cae como root en el appliance.
#
# La solución es ACTUALIZAR: Webmin 1.930 eliminó ese `qx()` y cierra el RCE.
# El .deb parcheado queda preinstalado en /opt/lab/patches para el modo blue.
FROM debian:12-slim
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      perl libnet-ssleay-perl libauthen-pam-perl libpam-runtime \
      libio-pty-perl apt-show-versions libapt-pkg-perl openssl \
      shared-mime-info unzip \
      python3 iptables iproute2 procps curl ncat sudo openssh-server \
      grep file vim-tiny nano less ca-certificates \
    && rm -rf /var/lib/apt/lists/*
# iptables-legacy: en contenedor es el backend fiable bajo Docker Desktop.
RUN update-alternatives --set iptables /usr/sbin/iptables-legacy \
    && update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy
# Webmin declara dependencia de 'python' (python2, ya no en Debian 12). No lo
# necesita para servir ni para el CGI vulnerable (es Perl): stub a python3.
RUN ln -sf /usr/bin/python3 /usr/bin/python
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 \
      -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd

# Webmin VULNERABLE (1.920) instalado; parche (1.930) staged para el blue.
RUN mkdir -p /opt/lab/patches \
    && curl -fsSL -o /tmp/webmin_1.920_all.deb \
       "https://sourceforge.net/projects/webadmin/files/webmin/1.920/webmin_1.920_all.deb/download" \
    && curl -fsSL -o /opt/lab/patches/webmin_1.930_all.deb \
       "https://sourceforge.net/projects/webadmin/files/webmin/1.930/webmin_1.930_all.deb/download" \
    && (dpkg -i --force-depends /tmp/webmin_1.920_all.deb || true) \
    && rm -f /tmp/webmin_1.920_all.deb \
    && test -f /usr/share/webmin/version

# analista: shell en modo blue (actualizar el panel). svc: dueño del 8080.
RUN useradd -m -s /bin/bash analista && echo 'analista:analista' | chpasswd \
    && useradd -r -s /usr/sbin/nologin svc
COPY setup/ /opt/lab/setup/
COPY check.sh check-blue.sh /opt/lab/
COPY RETO.md /RETO.md
RUN chmod 0755 /opt/lab/*.sh /opt/lab/setup/*.sh /opt/lab/setup/**/*.sh 2>/dev/null; true
CMD ["bash", "/opt/lab/setup/boot.sh"]
