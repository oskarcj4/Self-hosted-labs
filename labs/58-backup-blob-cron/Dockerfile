# Lab 58 — Debian 12 con systemd real.
# Las 3 primeras capas son idénticas a las de los labs 24-38: Docker las comparte.
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
RUN apt-get update && apt-get install -y --no-install-recommends \
      unzip \
    && rm -rf /var/lib/apt/lists/*
# rclone oficial con versión fija (el de Debian 12, 1.60, no admite endpoints
# de emulador) y comprobación del SHA256 publicado.
RUN cd /tmp && V=v1.68.2 && Z=rclone-$V-linux-amd64.zip \
    && curl -fsSLO https://downloads.rclone.org/$V/$Z \
    && curl -fsSL https://downloads.rclone.org/$V/SHA256SUMS | grep " $Z\$" | sha256sum -c - \
    && unzip -q $Z && install -m 0755 rclone-$V-linux-amd64/rclone /usr/local/bin/rclone \
    && rm -rf /tmp/rclone-*
COPY setup/ /opt/lab/setup/
COPY check.sh /opt/lab/check.sh
COPY RETO.md /RETO.md
RUN install -m 0755 /opt/lab/setup/plant.sh /opt/lab/plant.sh \
    && install -m 0755 /opt/lab/setup/enter.sh /opt/lab/enter.sh \
    && chmod 0755 /opt/lab/check.sh \
    && cp /opt/lab/setup/ttyd.service /opt/lab/setup/labsetup.service /etc/systemd/system/ \
    && systemctl enable ttyd.service labsetup.service
CMD ["/sbin/init"]
