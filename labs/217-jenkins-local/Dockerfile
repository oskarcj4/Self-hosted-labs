# Lab 217 — Jenkins local bien montado: usuario propio, JCasC, seguridad, agente y credenciales.
# Base común de la pista Q (Debian 12 + systemd + Gitea + act_runner + Node 20):
# capas idénticas a las del lab 213; la capa de Jenkins, idéntica en los labs 217 y 218.
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
# --- Jenkins LTS + plugins precargados (sin internet en tiempo de ejecución) ---
RUN apt-get update && apt-get install -y --no-install-recommends fontconfig \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/java21 \
    && curl -fsSL "https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jre/hotspot/normal/eclipse" \
       | tar -xz -C /opt/java21 --strip-components=1 \
    && ln -sf /opt/java21/bin/java /usr/local/bin/java \
    && java -version
RUN mkdir -p /opt/jenkins \
    && curl -fsSL https://get.jenkins.io/war-stable/2.580.2/jenkins.war -o /opt/jenkins/jenkins.war \
    && curl -fsSL https://github.com/jenkinsci/plugin-installation-manager-tool/releases/download/2.13.2/jenkins-plugin-manager-2.13.2.jar \
         -o /opt/jenkins/plugin-manager.jar \
    && java -jar /opt/jenkins/plugin-manager.jar --war /opt/jenkins/jenkins.war \
         --plugin-download-directory /opt/jenkins/plugins \
         --plugins configuration-as-code workflow-aggregator git credentials-binding timestamper junit \
    && unzip -p /opt/jenkins/jenkins.war 'WEB-INF/lib/remoting-*.jar' > /opt/jenkins/agent.jar \
    && ls /opt/jenkins/plugins | wc -l
COPY setup/ /opt/lab/setup/
COPY check.sh /opt/lab/check.sh
COPY RETO.md /RETO.md
RUN install -m 0755 /opt/lab/setup/plant.sh /opt/lab/plant.sh \
    && install -m 0755 /opt/lab/setup/enter.sh /opt/lab/enter.sh \
    && chmod 0755 /opt/lab/check.sh \
    && cp /opt/lab/setup/ttyd.service /opt/lab/setup/labsetup.service /etc/systemd/system/ \
    && systemctl enable ttyd.service labsetup.service
CMD ["/sbin/init"]
