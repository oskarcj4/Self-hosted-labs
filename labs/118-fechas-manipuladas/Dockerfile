# Lab 118 — Debian 12 con systemd real.
# Las 3 primeras capas son idénticas a las de los labs 24-38 y 54+: Docker las comparte.
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
# Scripts de administración "de siempre", con fechas de 2023 (despliegue antiguo).
COPY tools/ /usr/local/bin/
RUN chmod 0755 /usr/local/bin/* \
    && touch -d '2023-05-10 09:12' /usr/local/bin/backup-db \
    && touch -d '2023-05-10 09:13' /usr/local/bin/rotate-logs \
    && touch -d '2023-06-21 17:40' /usr/local/bin/healthcheck \
    && touch -d '2023-09-02 11:05' /usr/local/bin/clean-tmp \
    && touch /usr/local/bin/.deploy-ok && touch -d '2023-09-02 11:06' /usr/local/bin/.deploy-ok \
    && tar -C /usr/local -czf /var/backups/usr-local-bin.tar.gz bin \
    && printf '15 3 * * * root /usr/local/bin/rotate-logs\n' > /etc/cron.d/rotate-logs
COPY setup/ /opt/lab/setup/
COPY check.sh /opt/lab/check.sh
COPY RETO.md /RETO.md
RUN install -m 0755 /opt/lab/setup/plant.sh /opt/lab/plant.sh \
    && install -m 0755 /opt/lab/setup/enter.sh /opt/lab/enter.sh \
    && chmod 0755 /opt/lab/check.sh \
    && cp /opt/lab/setup/ttyd.service /opt/lab/setup/labsetup.service /etc/systemd/system/ \
    && systemctl enable ttyd.service labsetup.service
CMD ["/sbin/init"]
