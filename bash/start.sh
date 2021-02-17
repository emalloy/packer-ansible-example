#!/usr/bin/env bash


yum_add() {
/usr/bin/yum update -y && \
  /usr/bin/yum install -y \
    wget \
    jq \
    nc \
    screen \
    tmux \
    net-tools \
    bind-utils \
    facter \
    python-devel \
    python-setuptools \
    lsof \
    git

  easy_install pip
}

ZK_MIG=(a b c)

cat > ~/env.yml <<EOF
zk_mig_name: "dummy-mig"
zk_hosts:
EOF
for index in ${!ZK_MIG[@]}; do
let id="$index + 1"
cat >> ~/env.yml <<EOF
  - host: ${ZK_MIG[$index]}
    id: $id
EOF
done
cat >> ~/env.yml <<EOF
dd_key: "null"
stack_key: "null"
EOF

}

# @todo - get a repo in gitlab- mirror to cloud repo
# and use service account to pull down
# - workaround, gitlab private repo - #


ansible_dep() {
mkdir -p /etc/ansible;
cat > /etc/ansible/hosts <<EOF
[all]
$(hostname -s) ansible_host=localhost
EOF

pip install -q ansible==2.4.3.0

}

ansible_pull() {
pushd ~/
git clone --branch ${git_deploy_branch} \
  git@${gitlab_domain}:GCP-Infrastructure/ansible_layer.git

}

ansible_exec() {
touch /var/log/start.log;
pushd ~/ansible_layer;
ansible-galaxy -r ansible-requirements.yml install;
mv ~/env.yml ~/ansible_layer;
ansible-playbook -v site.yml \
  | tee -a /var/log/start.log
}

#main
yum_add;
gather_members;
git_deploy_key_template;
git_repo_prep;
ansible_dep;
ansible_pull;
ansible_exec;




