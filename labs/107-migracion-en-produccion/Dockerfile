# Lab 107 — Debian 12 con systemd real: PostgreSQL + API de la tienda + k6.
# Migración de datos EN PRODUCCIÓN, con tráfico de usuarios (k6) golpeando la
# API. Hacerlo mal bloquea la tabla y "todo muere"; hacerlo online no.
FROM debian:12
ENV DEBIAN_FRONTEND=noninteractive container=docker
RUN apt-get update && apt-get install -y --no-install-recommends \
      systemd systemd-sysv dbus \
      postgresql postgresql-client python3 python3-psycopg2 \
      iproute2 procps psmisc lsof file \
      curl ca-certificates sudo nano vim-tiny less jq \
    && rm -rf /var/lib/apt/lists/* \
    && systemctl disable postgresql >/dev/null 2>&1 || true
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 \
      -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd
# k6 para simular el tráfico de usuarios.
RUN curl -fsSL https://github.com/grafana/k6/releases/download/v0.49.0/k6-v0.49.0-linux-amd64.tar.gz \
      -o /tmp/k6.tgz \
    && tar -xzf /tmp/k6.tgz -C /tmp \
    && install -m 0755 /tmp/k6-v0.49.0-linux-amd64/k6 /usr/local/bin/k6 \
    && rm -rf /tmp/k6.tgz /tmp/k6-v0.49.0-linux-amd64
RUN useradd -m -s /bin/bash analista \
    && echo 'analista:analista' | chpasswd \
    && echo 'analista ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/analista \
    && chmod 0440 /etc/sudoers.d/analista
COPY setup/ /opt/lab/setup/
COPY check.sh /opt/lab/check.sh
COPY RETO.md /RETO.md
RUN install -m 0755 /opt/lab/setup/plant.sh /opt/lab/plant.sh \
    && install -m 0755 /opt/lab/setup/enter.sh /opt/lab/enter.sh \
    && install -D -m 0644 /opt/lab/setup/app.py /opt/app/app.py \
    && chmod 0755 /opt/lab/check.sh \
    && cp /opt/lab/setup/ttyd.service /opt/lab/setup/labsetup.service \
          /opt/lab/setup/shop-api.service /etc/systemd/system/ \
    && systemctl enable ttyd.service labsetup.service shop-api.service
CMD ["/sbin/init"]
