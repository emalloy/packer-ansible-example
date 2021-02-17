#!/bin/bash
# Copyright 2020 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# Add repository for the Google logging agent.
#
# This script configures the required apt or yum repository.
# The environment variable REPO_SUFFIX can be set to alter which repository is
# used. A dash (-) will be inserted prior to the supplied suffix. An example
# value is '20200127-1'. <REPO_SUFFIX> defaults to 'all'.
# The full repository name is:
# "google-cloud-logging-<DISTRO>[-<ARCH>]-<REPO_SUFFIX>".
#
# Ignore the return code of command substitution in variables.
# shellcheck disable=SC2155

# Host that serves the repositories.
REPO_HOST='packages.cloud.google.com'

# URL for the logging agent documentation.
LOGGING_AGENT_DOCS_URL="https://cloud.google.com/logging/docs/agent"

# URL documentation which lists supported platforms for running the logging agent.
LOGGING_AGENT_SUPPORTED_URL="${LOGGING_AGENT_DOCS_URL}/#agent-os-list"

# <REPO_SUFFIX> defaults to 'all'.
[[ -z "${REPO_SUFFIX-}" ]] && REPO_SUFFIX='all'

if [[ -f /etc/os-release ]]; then
  . /etc/os-release
fi

handle_debian() {
  lsb_release -v >/dev/null 2>&1 || { \
    apt-get update; apt-get -y install lsb-release; \
  }
  apt-get update; apt-get -y install apt-transport-https ca-certificates
  local CODENAME="${REPO_CODENAME:-"$(lsb_release -sc)"}"
  local REPO_NAME="google-cloud-logging-${CODENAME}${REPO_SUFFIX+-${REPO_SUFFIX}}"
  cat > /etc/apt/sources.list.d/google-cloud-logging.list <<EOM
deb https://${REPO_HOST}/apt ${REPO_NAME} main
EOM
  curl --connect-timeout 5 -s -f "https://${REPO_HOST}/apt/doc/apt-key.gpg" | apt-key add -
}

# Takes the repo codename as a parameter.
handle_rpm() {
  lsb_release -v >/dev/null 2>&1 || yum -y install redhat-lsb-core
  local REPO_NAME="google-cloud-logging-${1}-\$basearch${REPO_SUFFIX+-${REPO_SUFFIX}}"
  cat > /etc/yum.repos.d/google-cloud-logging.repo <<EOM
[google-cloud-logging]
name=Google Cloud Logging Agent Repository
baseurl=https://${REPO_HOST}/yum/repos/${REPO_NAME}
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://${REPO_HOST}/yum/doc/yum-key.gpg
       https://${REPO_HOST}/yum/doc/rpm-package-key.gpg
EOM
}

handle_redhat() {
  local VERSION_PRINTER='import platform; print(platform.dist()[1].split(".")[0])'
  local MAJOR_VERSION="$(python2 -c "${VERSION_PRINTER}")"
  handle_rpm "el${MAJOR_VERSION}"
}

handle_amazon_linux() {
  handle_rpm "el6"
}

handle_suse() {
  SUSE_VERSION=${VERSION%%-*}
  local REPO_NAME="google-cloud-logging-sles${SUSE_VERSION}-\$basearch${REPO_SUFFIX+-${REPO_SUFFIX}}"
  # TODO: expand all short arguments in this script, for readability.
  zypper -n refresh || { \
    echo "Could not refresh zypper repositories."; \
    echo "This is not necessarily a fatal error; proceeding..."; \
  }
  zypper addrepo -g -t YUM "https://${REPO_HOST}/yum/repos/${REPO_NAME}" google-cloud-logging
  rpm --import "https://${REPO_HOST}/yum/doc/yum-key.gpg" "https://${REPO_HOST}/yum/doc/rpm-package-key.gpg"
}

case "${ID:-}" in
  amzn)
    echo 'Adding agent repository for Amazon Linux.'
    handle_amazon_linux
    ;;
  debian|ubuntu)
    echo 'Adding agent repository for Debian or Ubuntu.'
    handle_debian
    ;;
  rhel|centos)
    echo 'Adding agent repository for RHEL or CentOS.'
    handle_redhat
    ;;
  sles)
    echo 'Adding agent repository for SLES.'
    handle_suse
    ;;
  *)
    # Fallback for systems lacking /etc/os-release.
    if [[ -f /etc/debian_version ]]; then
      echo 'Adding agent repository for Debian.'
      handle_debian
    elif [[ -f /etc/redhat-release ]]; then
      echo 'Adding agent repository for Red Hat.'
      handle_redhat
    elif [[ -f /etc/SuSE-release ]]; then
      echo 'Adding agent repository for SLES.'
      handle_suse
    else
      echo >&2 'Unidentifiable or unsupported platform.'
      echo >&2 "See ${LOGGING_AGENT_SUPPORTED_URL} for a list of supported platforms."
      exit 1
    fi
esac
