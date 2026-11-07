# Lab 171 — Debian 12 con systemd real.
# Las 3 primeras capas son idénticas a las de los labs 24-38, 54+, 137, 143 y 157: Docker las comparte.
FROM debian:12
ENV DEBIAN_FRONTEND=noninteractive container=docker
RUN apt-get update && apt-get install -y --no-install-recommends \
      systemd systemd-sysv dbus \
      python3 iproute2 procps psmisc lsof file acl \
      curl ca-certificates sudo nano vim-tiny less \
      nginx-light cron openssh-server logrotate \
    && rm -rf /var/lib/apt/lists/* \
    && systemctl disable nginx cron ssh >/dev/null 2>&1 || true
RUN curl -fsSL https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 \
      -o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd
RUN useradd -m -s /bin/bash analista \
    && echo 'analista:analista' | chpasswd \
    && echo 'analista ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/analista \
    && chmod 0440 /etc/sudoers.d/analista
# Prometheus y promtool.
RUN apt-get update && apt-get install -y --no-install-recommends python3-yaml jq \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://github.com/prometheus/prometheus/releases/download/v2.55.1/prometheus-2.55.1.linux-amd64.tar.gz \
       | tar xz -C /usr/local/bin --strip-components=1 \
           prometheus-2.55.1.linux-amd64/prometheus prometheus-2.55.1.linux-amd64/promtool
# Grafana (OSS) y el cliente de métricas de Python.
RUN apt-get update && apt-get install -y --no-install-recommends python3-prometheus-client \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/grafana \
    && curl -fsSL https://dl.grafana.com/oss/release/grafana-11.3.0.linux-amd64.tar.gz \
       | tar xz -C /opt/grafana --strip-components=1
COPY setup/ /opt/lab/setup/
COPY check.sh /opt/lab/check.sh
COPY RETO.md /RETO.md
RUN install -m 0755 /opt/lab/setup/plant.sh /opt/lab/plant.sh \
    && install -m 0755 /opt/lab/setup/enter.sh /opt/lab/enter.sh \
    && chmod 0755 /opt/lab/check.sh \
    && cp /opt/lab/setup/ttyd.service /opt/lab/setup/labsetup.service /etc/systemd/system/ \
    && systemctl enable ttyd.service labsetup.service
CMD ["/sbin/init"]
