# Lab 170 — Debian 12 con systemd real.
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
# OpenTelemetry: Collector (contrib), Jaeger all-in-one y el SDK de Python.
RUN apt-get update && apt-get install -y --no-install-recommends python3-venv python3-yaml jq \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.116.0/otelcol-contrib_0.116.0_linux_amd64.tar.gz \
       | tar xz -C /usr/local/bin otelcol-contrib \
    && curl -fsSL https://github.com/jaegertracing/jaeger/releases/download/v1.64.0/jaeger-1.64.0-linux-amd64.tar.gz \
       | tar xz -C /usr/local/bin --strip-components=1 jaeger-1.64.0-linux-amd64/jaeger-all-in-one \
    && python3 -m venv /opt/otel \
    && /opt/otel/bin/pip install --no-cache-dir opentelemetry-sdk==1.29.0 \
         opentelemetry-exporter-otlp-proto-http==1.29.0
COPY setup/ /opt/lab/setup/
COPY check.sh /opt/lab/check.sh
COPY RETO.md /RETO.md
RUN install -m 0755 /opt/lab/setup/plant.sh /opt/lab/plant.sh \
    && install -m 0755 /opt/lab/setup/enter.sh /opt/lab/enter.sh \
    && chmod 0755 /opt/lab/check.sh \
    && cp /opt/lab/setup/ttyd.service /opt/lab/setup/labsetup.service /etc/systemd/system/ \
    && systemctl enable ttyd.service labsetup.service
CMD ["/sbin/init"]
