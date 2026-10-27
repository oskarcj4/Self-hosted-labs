#!/usr/bin/env bash
(
  dind dockerd --host=unix:///var/run/docker.sock --group docker \
    > /var/log/dockerd.log 2>&1 &
  for _ in $(seq 1 90); do docker info >/dev/null 2>&1 && break; sleep 1; done
  docker image inspect python:3.12-alpine >/dev/null 2>&1 \
    || docker load -i /opt/images/python.tar >/dev/null
  if [ ! -e /opt/lab/.planted ] && bash /opt/lab/plant.sh > /var/log/tclab-plant.log 2>&1; then
    touch /opt/lab/.planted
    rm -rf /opt/lab/setup /opt/lab/plant.sh
  fi
  if [ -e /opt/lab/.planted ]; then touch /run/tclab-ready; else touch /run/tclab-failed; fi
) &
exec ttyd -p 7681 -W -t fontSize=14 bash /opt/lab/enter.sh
