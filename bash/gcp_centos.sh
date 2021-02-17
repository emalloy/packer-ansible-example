#!/usr/bin/env bash
set -o errexit
set -o nounset
set -x

export YUM="sudo yum -y -q"
export alh="sudo ansible 127.0.0.1"

# Document box build time
echo "Built by Packer $(date '+%H:%M %Z on %B %-d, %Y')" \
    | sudo tee --append  /etc/image-build-time

sudo chmod 0644 /etc/image-build-time
sudo chcon system_u:object_r:etc_t:s0 /etc/image-build-time

${YUM} update 
${YUM} install \
  python-setuptools \
  python-devel \
  libselinux-python \
  cloud-init \
  git

sudo easy_install pip
sudo pip install netaddr ansible==2.4.3.0
sudo mkdir -p /etc/ansible
echo "what we have as $USER user - $(ls -lah)"
sudo ls -lah ~/
sudo sh -c 'printf "[packer]\n127.0.0.1  ansible_connection=local\n[gcp_host:children]\npacker\n" > /etc/ansible/hosts'


# requiretty disabled
${alh} -m lineinfile -a \
    'dest=/etc/sudoers state=present regexp="^Defaults\s+[!]?requiretty" line="Defaults  !requiretty"'
# enable NOPASSWD
${alh} -m lineinfile -a \
    'dest=/etc/sudoers state=present line="%wheel  ALL=(ALL)  NOPASSWD:ALL"'
# disable selinux
${alh} -m lineinfile -a \
    'dest=/etc/sysconfig/selinux state=present regexp="^SELINUX=" line="SELINUX=disabled"'

# This is a slightly modified version of cloud-init in the centos rpm
sudo tee -a /etc/cloud/cloud.cfg > /dev/null << EOF
users:
 - default

disable_root: 0
ssh_pwauth:   0

locale_configfile: /etc/sysconfig/i18n
mount_default_fields: [~, ~, 'auto', 'defaults,nofail', '0', '2']
resize_rootfs_tmp: /dev
ssh_deletekeys:   0
ssh_genkeytypes:  ~
syslog_fix_perms: ~

cloud_init_modules:
 - migrator
 - bootcmd
 - write-files
 - growpart
 - resizefs
 - set_hostname
 - update_hostname
 - update_etc_hosts
 - rsyslog
 - users-groups
 - ssh

cloud_config_modules:
 - mounts
 - locale
 - set-passwords
 - yum-add-repo
 - package-update-upgrade-install
 - timezone
 - puppet
 - chef
 - salt-minion
 - mcollective
 - disable-ec2-metadata
 - runcmd

cloud_final_modules:
 - rightscale_userdata
 - scripts-per-once
 - scripts-per-boot
 - scripts-per-instance
 - scripts-user
 - ssh-authkey-fingerprints
 - keys-to-console
 - phone-home
 - final-message

system_info:
  default_user:
    name: ec2-user
    lock_passwd: true
    gecos: Cloud User
    groups: [wheel, adm]
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    shell: /bin/bash
  distro: rhel
  paths:
    cloud_dir: /var/lib/cloud
    templates_dir: /etc/cloud/templates
  ssh_svcname: sshd

# vim:syntax=yaml
EOF
