#!/usr/bin/env bash

set -o errexit


# fetch priv key from gcs
# write out to packer
# fetch the repo
# delete the key


function write_ssh_config() {


export _GIT_IP_ADDR=$(dig @10.0.11.0 gitlab +short | tail -1)

if [[ -e ".ssh/config" ]]; then
  rm -fv .ssh/config
else
  mkdir -p .ssh
cat > .ssh/config <<EOF
  Host gitlab
    Hostname ${_GIT_IP_ADDR}
    User git
    IdentityFile /tmp/key/terraform-key
    StrictHostKeyChecking no
EOF
fi
}

function check_gsutil() {
if ! hash gsutil >/dev/null 2>&1 ; then
  printf "ERR: ${FUNCNAME[0]} - Can't find gsutil, exiting!\n"
  exit 1
fi
}

function get_priv_key() {
if [[ $(uname -s) -eq "Darwin" ]]; then
  export B64_EXEC="base64 -D"
else
  export B64_EXEC="base64 -d"
fi

mkdir -p /tmp/key/
#gsutil cp gs://cicd-dev_secrets/gitlab/deployment_keys /tmp/key/
cp ~/tmp/terraform-key.b64 /tmp/key/
${B64_EXEC} /tmp/key/terraform-key.b64 \
  > /tmp/key/terraform-key \
  && chmod 0600 /tmp/key/terraform-key
}



function ansible_pull() {
GIT_SSH_COMMAND="ssh -F $(pwd)/.ssh/config" \
git clone --branch dev \
  git@gitlab:GCP-Infrastructure/ansible_layer.git
}

check_gsutil
write_ssh_config
get_priv_key
ansible_pull
