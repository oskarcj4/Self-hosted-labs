#!/usr/bin/env bash
# Arranque del lab 159: dockerd interno -> imágenes base -> registro -> escenario -> terminal.
(
  dind dockerd --host=unix:///var/run/docker.sock --group docker \
    > /var/log/dockerd.log 2>&1 &
  for _ in $(seq 1 90); do docker info >/dev/null 2>&1 && break; sleep 1; done
  docker image inspect python:3.12-slim-bookworm >/dev/null 2>&1 \
    || docker load -i /opt/images/python-slim.tar >/dev/null
  docker image inspect registry:2 >/dev/null 2>&1 \
    || docker load -i /opt/images/registry.tar >/dev/null
  docker start registry >/dev/null 2>&1 \
    || docker run -d --name registry --restart=always -p 127.0.0.1:5000:5000 registry:2 >/dev/null
  if [ ! -e /opt/lab/.planted ] && bash /opt/lab/plant.sh > /var/log/tclab-plant.log 2>&1; then
    touch /opt/lab/.planted
    rm -rf /opt/lab/setup /opt/lab/plant.sh
  fi
  if [ -e /opt/lab/.planted ]; then touch /run/tclab-ready; else touch /run/tclab-failed; fi
) &
exec ttyd -p 7681 -W -t fontSize=14 bash /opt/lab/enter.sh
