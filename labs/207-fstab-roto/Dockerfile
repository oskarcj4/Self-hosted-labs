# Lab 207 — Debian 12 con systemd real + herramientas de almacenamiento.
# Las 3 primeras capas son idénticas a las de los labs 24-38, 54+, 137 y 155: Docker las comparte.
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
# Almacenamiento: ext4/xfs, particiones, LVM, LUKS y RAID por software.
RUN apt-get update && apt-get install -y --no-install-recommends \
      e2fsprogs util-linux xfsprogs lvm2 cryptsetup cloud-guest-utils gdisk parted kpartx mdadm \
    && rm -rf /var/lib/apt/lists/* \
    && printf 'activation {\n udev_sync = 0\n udev_rules = 0\n}\ndevices {\n use_devicesfile = 0\n}\n' > /etc/lvm/lvmlocal.conf \
    && systemctl mask mdmonitor.service lvm2-monitor.service >/dev/null 2>&1 || true
# Sin udev: libdevmapper crea los nodos /dev/mapper directamente.
RUN echo 'export DM_DISABLE_UDEV=1' > /etc/profile.d/dm.sh     && echo 'Defaults env_keep += "DM_DISABLE_UDEV"' > /etc/sudoers.d/dm     && chmod 0440 /etc/sudoers.d/dm
COPY setup/ /opt/lab/setup/
COPY check.sh /opt/lab/check.sh
COPY clean.sh /opt/lab/clean.sh
COPY RETO.md /RETO.md
RUN install -m 0755 /opt/lab/setup/plant.sh /opt/lab/plant.sh \
    && install -m 0755 /opt/lab/setup/enter.sh /opt/lab/enter.sh \
    && chmod 0755 /opt/lab/check.sh /opt/lab/clean.sh \
    && cp /opt/lab/setup/ttyd.service /opt/lab/setup/labsetup.service /etc/systemd/system/ \
    && systemctl enable ttyd.service labsetup.service
CMD ["/sbin/init"]
