#!/usr/bin/env bash
set -o errexit
set -o nounset
set -x

export YUM="sudo yum -y -q"
export alh="sudo ansible 127.0.0.1"


pushd /tmp \
  && curl -sSO https://dl.google.com/cloudagents/add-logging-agent-repo.sh \
  && sudo bash /tmp/add-logging-agent-repo.sh \
  && curl -sSO https://dl.google.com/cloudagents/add-monitoring-agent-repo.sh \
  && sudo bash /tmp/add-monitoring-agent-repo.sh

${YUM} update
${YUM} install \
 google-fluentd-catch-all-config-structured \
 stackdriver-agent


