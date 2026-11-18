# Lab 213 — Debian 12 con systemd real + Gitea con Actions (sintaxis de GitHub
# Actions) + act_runner + Node 20 + espejo de actions/checkout. Sin internet en
# tiempo de ejecución.
# Las 3 primeras capas son idénticas a las de los labs 24-38, 54+, 137, 143 y 157,
# y las 2 siguientes, a las de toda la pista Q: Docker las comparte.
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
# --- Base común de la pista Q (CI/CD) ----------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
      git jq sqlite3 xz-utils rsync python3-yaml unzip \
    && rm -rf /var/lib/apt/lists/* \
    && git config --system safe.directory '*' \
    && git config --system init.defaultBranch main
RUN curl -fsSL https://dl.gitea.com/gitea/1.22.6/gitea-1.22.6-linux-amd64 -o /usr/local/bin/gitea \
    && curl -fsSL https://dl.gitea.com/act_runner/0.2.11/act_runner-0.2.11-linux-amd64 -o /usr/local/bin/act_runner \
    && chmod 0755 /usr/local/bin/gitea /usr/local/bin/act_runner \
    && curl -fsSL https://nodejs.org/dist/v20.18.1/node-v20.18.1-linux-x64.tar.xz \
       | tar xJ -C /usr/local --strip-components=1 --exclude CHANGELOG.md --exclude LICENSE --exclude README.md \
    && git clone -q --mirror https://github.com/actions/checkout /opt/mirrors/checkout.git
# --- Fin de la base común ----------------------------------------------------
COPY setup/ /opt/lab/setup/
COPY check.sh /opt/lab/check.sh
COPY RETO.md /RETO.md
RUN install -m 0755 /opt/lab/setup/plant.sh /opt/lab/plant.sh \
    && install -m 0755 /opt/lab/setup/enter.sh /opt/lab/enter.sh \
    && chmod 0755 /opt/lab/check.sh \
    && cp /opt/lab/setup/ttyd.service /opt/lab/setup/labsetup.service /etc/systemd/system/ \
    && systemctl enable ttyd.service labsetup.service
CMD ["/sbin/init"]
