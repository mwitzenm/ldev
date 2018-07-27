#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

export SCRIPT_ROOT=$( cd "$( dirname "$0" )" && pwd )
export OPENSHIFT_USER_PASSWD_ENC="$(echo $OPENSHIFT_USER_PASSWD | openssl passwd -stdin -apr1)"
export ANSIBLE_ROOT=${SCRIPT_ROOT}

echo "DEFAULT_HOST_IP=$DEFAULT_HOST_IP"

if ! grep -q "console.${OPENSHIFT_DOMAIN}" /etc/hosts; then
	echo "Updating /etc/hosts file"
	# Note: DO NOT REPLACE TAB CHARACTER WITH SPACE, THIS WILL BREAK THE HEREDOC BELOW
	cat <<- EOD > /etc/hosts
	#127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
	#::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

	${MASTER_IP} ${MASTER_FQDN} ${MASTER_HOSTNAME}
	${MASTER_IP} console.${OPENSHIFT_DOMAIN} console
	${MASTER_IP} api.${OPENSHIFT_DOMAIN} api
	${MASTER_IP} api-int.${OPENSHIFT_DOMAIN} api-int
	EOD
fi

echo "${MASTER_FQDN}" > /etc/hostname

# Manually configure DNS settings on teh guest to refer to CoreDNS on the host.
nmcli con mod "System eth0" ipv4.dns "${DEFAULT_HOST_IP}"
nmcli con mod "System eth0" ipv4.ignore-auto-dns yes
systemctl restart NetworkManager

## Generate ssh key pairs
if [ ! -f ~/.ssh/id_rsa ]; then
	echo "Copying ssh keys"
	# NOTE: DO NOT REPLACE TAB CHARACTER WITH SPACE, THIS WILL BREAK THE HEREDOC BELOW
	# NOTE: single quotes will prevent variable interpolation
	cat <<- 'VAGRANT_ID_RSA' > /home/vagrant/.ssh/id_rsa
	-----BEGIN RSA PRIVATE KEY-----
	MIIEogIBAAKCAQEA6NF8iallvQVp22WDkTkyrtvp9eWW6A8YVr+kz4TjGYe7gHzI
	w+niNltGEFHzD8+v1I2YJ6oXevct1YeS0o9HZyN1Q9qgCgzUFtdOKLv6IedplqoP
	kcmF0aYet2PkEDo3MlTBckFXPITAMzF8dJSIFo9D8HfdOV0IAdx4O7PtixWKn5y2
	hMNG0zQPyUecp4pzC6kivAIhyfHilFR61RGL+GPXQ2MWZWFYbAGjyiYJnAmCP3NO
	Td0jMZEnDkbUvxhMmBYSdETk1rRgm+R4LOzFUGaHqHDLKLX+FIPKcF96hrucXzcW
	yLbIbEgE98OHlnVYCzRdK8jlqm8tehUc9c9WhQIBIwKCAQEA4iqWPJXtzZA68mKd
	ELs4jJsdyky+ewdZeNds5tjcnHU5zUYE25K+ffJED9qUWICcLZDc81TGWjHyAqD1
	Bw7XpgUwFgeUJwUlzQurAv+/ySnxiwuaGJfhFM1CaQHzfXphgVml+fZUvnJUTvzf
	TK2Lg6EdbUE9TarUlBf/xPfuEhMSlIE5keb/Zz3/LUlRg8yDqz5w+QWVJ4utnKnK
	iqwZN0mwpwU7YSyJhlT4YV1F3n4YjLswM5wJs2oqm0jssQu/BT0tyEXNDYBLEF4A
	sClaWuSJ2kjq7KhrrYXzagqhnSei9ODYFShJu8UWVec3Ihb5ZXlzO6vdNQ1J9Xsf
	4m+2ywKBgQD6qFxx/Rv9CNN96l/4rb14HKirC2o/orApiHmHDsURs5rUKDx0f9iP
	cXN7S1uePXuJRK/5hsubaOCx3Owd2u9gD6Oq0CsMkE4CUSiJcYrMANtx54cGH7Rk
	EjFZxK8xAv1ldELEyxrFqkbE4BKd8QOt414qjvTGyAK+OLD3M2QdCQKBgQDtx8pN
	CAxR7yhHbIWT1AH66+XWN8bXq7l3RO/ukeaci98JfkbkxURZhtxV/HHuvUhnPLdX
	3TwygPBYZFNo4pzVEhzWoTtnEtrFueKxyc3+LjZpuo+mBlQ6ORtfgkr9gBVphXZG
	YEzkCD3lVdl8L4cw9BVpKrJCs1c5taGjDgdInQKBgHm/fVvv96bJxc9x1tffXAcj
	3OVdUN0UgXNCSaf/3A/phbeBQe9xS+3mpc4r6qvx+iy69mNBeNZ0xOitIjpjBo2+
	dBEjSBwLk5q5tJqHmy/jKMJL4n9ROlx93XS+njxgibTvU6Fp9w+NOFD/HvxB3Tcz
	6+jJF85D5BNAG3DBMKBjAoGBAOAxZvgsKN+JuENXsST7F89Tck2iTcQIT8g5rwWC
	P9Vt74yboe2kDT531w8+egz7nAmRBKNM751U/95P9t88EDacDI/Z2OwnuFQHCPDF
	llYOUI+SpLJ6/vURRbHSnnn8a/XG+nzedGH5JGqEJNQsz+xT2axM0/W/CRknmGaJ
	kda/AoGANWrLCz708y7VYgAtW2Uf1DPOIYMdvo6fxIB5i9ZfISgcJ/bbCUkFrhoH
	+vq/5CIWxCPp0f85R4qxxQ5ihxJ0YDQT9Jpx4TMss4PSavPaBH3RXow5Ohe+bYoQ
	NE5OgEXk2wVfZczCZpigBKbKZHNYcelXtTt/nP3rsCuGcM4h53s=
	-----END RSA PRIVATE KEY-----
	VAGRANT_ID_RSA

    mkdir -p /root/.ssh
    rsync -rIq /home/vagrant/.ssh/ /root/.ssh/
    chmod -R 600 /root/.ssh
    ssh -o StrictHostKeyChecking=no root@$(hostname -i) "pwd" < /dev/null
    ssh -o StrictHostKeyChecking=no root@$(hostname -f) "pwd" < /dev/null
fi

## Setup http proxy variables
set +u
if [ ! -z "${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy}}}}" ]; then
    export http_proxy="${HTTP_PROXY:-${http_proxy:-${HTTPS_PROXY:-${https_proxy}}}}"
    export https_proxy="${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy}}}}"
    export no_proxy="${NO_PROXY:-${no_proxy}}"

    # These are consumed by ansible inventory file
    export openshift_http_proxy="${HTTP_PROXY:-${http_proxy:-${HTTPS_PROXY:-${https_proxy}}}}"
    export openshift_https_proxy="${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy}}}}"
    export openshift_no_proxy="${NO_PROXY:-${no_proxy}}"

    # Configure Yum proxy
    sed -i "/^proxy=.*/d" /etc/yum.conf
    sed -i "/\[main\]/a proxy=${http_proxy}" /etc/yum.conf

    if [ "${OPENSHIFT_DEPLOYMENT_TYPE}" = "openshift-enterprise" ] && [ "${RHSM_ORG}" != "" ] && [ "${RHSM_ACTIVATION_KEY}" != "" ]; then
        http_proxy_re='^https?://(([^:]{1,128}):([^@]{1,256})@)?([^:/]{1,255})(:([0-9]{1,5}))?/?'
        # http_proxy_re='^http:\/\/(([^:]+):?(\S+)?@)?([^:]+)(:(\d+))?\/?$'
        if [[ "$http_proxy" =~ $http_proxy_re ]]; then
            # skip parent nesting groups 1 and 5
            export proxy_user=${BASH_REMATCH[2]}
            export proxy_pass=${BASH_REMATCH[3]}
            export proxy_host=${BASH_REMATCH[4]}
            export proxy_port=${BASH_REMATCH[6]}
        fi
        subscription-manager config --server.proxy_hostname="${proxy_host}" --server.proxy_port="${proxy_port}" --server.no_proxy="${no_proxy}"
    fi
else
    # These are consumed by ansible inventory file
    export openshift_http_proxy=""
    export openshift_https_proxy=""
    export openshift_no_proxy=""

    # Delete the line, with proxy configuration from /etc/yum.conf
    sed -i "/^proxy=.*/d" /etc/yum.conf

    if [ "${OPENSHIFT_DEPLOYMENT_TYPE}" = "openshift-enterprise" ] && [ "${RHSM_ORG}" != "" ] && [ "${RHSM_ACTIVATION_KEY}" != "" ]; then
        subscription-manager config --server.proxy_hostname='' --server.proxy_port='' --server.no_proxy=''
    fi
fi

# Test internet connectivity
CONNECTION_TEST_URL='www.google.com'
HTTP_CODE=$( curl \
                --connect-timeout 20 --retry 5  --retry-delay 0 --head --insecure \
                --location --silent --show-error --fail --output /dev/null \
                --write-out "%{http_code}" \
                $CONNECTION_TEST_URL
)
if [ "$HTTP_CODE" != "200" ]; then
    echo "Please check your internet connectivity"
    exit 1
else
    echo "Your internet connectivity has been successfully verified !"
fi
set -u

# RHSM subscription setup
if [ "${OPENSHIFT_DEPLOYMENT_TYPE}" = "openshift-enterprise" ] && [ "${RHSM_ORG}" != "" ] && [ "${RHSM_ACTIVATION_KEY}" != "" ]; then
    echo "Enrolling VM with Red Hat Subscription-Manager"
    subscription-manager register --org="${RHSM_ORG}" --activationkey="${RHSM_ACTIVATION_KEY}" || true
fi

if [ "${OPENSHIFT_DEPLOYMENT_TYPE}" = "openshift-enterprise" ]; then
    echo "Enable RHEL repositories"
    subscription-manager release --set='7.5'
    subscription-manager repos --disable="*"
    subscription-manager repos \
        --enable="rhel-7-server-rpms" \
        --enable="rhel-7-server-extras-rpms" \
        --enable="rhel-7-server-ose-3.9-rpms" \
        --enable="rhel-7-server-ansible-2.4-rpms" \
        --enable="rhel-7-fast-datapath-rpms" \
        --enable="rh-gluster-3-client-for-rhel-7-server-rpms"

    export ANSIBLE_ROOT=/usr/share/ansible
fi

set +e
echo "Installing packages"
## https://access.redhat.com/articles/1320623
rm -fr /var/cache/yum/*
yum clean all

## Update system to latest packages and install dependencies
yum makecache
yum repolist
yum -y update

## Install the following base packages
yum install -y  wget git net-tools bind-utils iptables-services \
                bridge-utils bash-completion \
                kexec-tools sos psacct nfs-utils \
                openssl-devel httpd-tools NetworkManager \
                fuse-sshfs docker

systemctl | grep "NetworkManager.*running"
if [ $? -eq 1 ]; then
    systemctl start NetworkManager
    systemctl enable NetworkManager
fi

if [ "${OPENSHIFT_DEPLOYMENT_TYPE}" = "origin" ]; then
    yum install -y  epel-release python-cryptography python2-pip \
                    python-devel python-passlib zile vim \
                    java-1.8.0-openjdk-headless "@Development Tools"

    ## Disable the EPEL repository globally so that is not accidentally used during later steps of the installation
    sed -i -e "s/^enabled=1/enabled=0/" /etc/yum.repos.d/epel.repo

    ## Disable EPEL to prevent unexpected packages from being pulled in during installation.
    yum-config-manager epel --disable

    ## Install the packages for Ansible
    if [ "$(hostname)" = "${MASTER_FQDN}" ] ; then
        yum -y --enablerepo=epel install ansible pyOpenSSL
    fi
fi

if [ "${OPENSHIFT_DEPLOYMENT_TYPE}" = "openshift-enterprise" ]; then
    yum install -y atomic-openshift-utils atomic-openshift-clients
    #yum install -y atomic-openshift-docker-excluder atomic-openshift-excluder unexclude

    ## Install the packages for Ansible
    if [ "$(hostname)" = "${MASTER_FQDN}" ] ; then
        yum install -y ansible openshift-ansible
    fi
fi
set -e

if [ -z $DOCKER_DISK ]; then
    echo "Not setting the Docker storage."
elif [ $(cat /etc/sysconfig/docker-storage-setup | grep docker-vg | wc -l) == 0  ]; then
    echo "Configuring docker storage"
    cp /etc/sysconfig/docker-storage-setup /etc/sysconfig/docker-storage-setup.bk

    echo DEVS=$DOCKER_DISK > /etc/sysconfig/docker-storage-setup
    echo VG=docker-vg >> /etc/sysconfig/docker-storage-setup
    echo SETUP_LVM_THIN_POOL=yes >> /etc/sysconfig/docker-storage-setup
    echo DATA_SIZE="100%FREE" >> /etc/sysconfig/docker-storage-setup

    systemctl stop docker

    rm -rf /var/lib/docker
    wipefs --all $DOCKER_DISK
    docker-storage-setup

    systemctl restart docker
    systemctl enable docker
fi

## Run docker as unprivileged user
if ! getent group dockerroot | grep &>/dev/null "\bvagrant\b"; then
    usermod -aG dockerroot vagrant
    echo "{\"live-restore\": true,\"group\": \"dockerroot\"}" > /etc/docker/daemon.json
    #echo "{\"live-restore\": true,\"group\": \"dockerroot\", \"dns\": [\"192.168.1.25\"]}" > /etc/docker/daemon.json
    systemctl restart docker
    ls -ltr /var/run/docker.sock
fi

## other steps are required only on master node
if [ "$(hostname)" = "${INFRA_FQDN}" ]; then
    ## Persist init script
    cp /tmp/vagrant-shell /home/vagrant/init.sh
    chown vagrant:vagrant /home/vagrant/init.sh
    chmod 755 /home/vagrant/init.sh
    sed -i "s|^export RHSM_ORG=.*$|export RHSM_ORG=''|g" /home/vagrant/init.sh
    sed -i "s|^export RHSM_ACTIVATION_KEY=.*$|export RHSM_ACTIVATION_KEY=''|g" /home/vagrant/init.sh

    ## No further action is required on infra nodes
    exit 0
fi

if [ "${OPENSHIFT_USE_CALICO_SDN}" = "true" ]; then
    export OS_SDN_NETWORK_PLUGIN_NAME='cni'
    export OPENSHIFT_USE_OPENSHIFT_SDN='false'
else
    export OPENSHIFT_USE_OPENSHIFT_SDN='true'
fi

## OpenShift Enterprise version does not yet support running the control plane in containers
if [ "${OPENSHIFT_DEPLOYMENT_TYPE}" = "openshift-enterprise" ]; then
    export OPENSHIFT_CONTAINERIZED='false'
fi

echo "Generate ansible inventory file"
envsubst < $SCRIPT_ROOT/inventory.ini.tmpl > $SCRIPT_ROOT/inventory.ini

if [ "${OPENSHIFT_DEPLOYMENT_TYPE}" = "origin" ]; then
    ## CentOS 7 - RPM install
    # https://buildlogs.centos.org/centos/7/paas/x86_64/openshift-origin39/
    # https://wiki.centos.org/SpecialInterestGroup/PaaS/OpenShift-Quickstart
    # yum install -y centos-release-openshift-origin39
    # yum install -y openshift-ansible

    [ ! -d $SCRIPT_ROOT/openshift-ansible ] && git clone https://github.com/openshift/openshift-ansible.git
    if [ "${OPENSHIFT_USE_GIT_RELEASE}" = "true" ]; then
        cd $SCRIPT_ROOT/openshift-ansible && git fetch && git checkout ${OPENSHIFT_ANSIBLE_GIT_REL} && cd ..
    else
        cd $SCRIPT_ROOT/openshift-ansible && git fetch && git checkout tags/${OPENSHIFT_ANSIBLE_GIT_TAG} && cd ..
    fi
fi

## OpenShift v3.10+ does not support 'filename' attribute
if [ "${OPENSHIFT_RELEASE_MAJOR_VERSION}" != "3.9" ]; then
    sed -i "s|, 'filename': '/etc/origin/master/htpasswd'||g" $SCRIPT_ROOT/inventory.ini
fi

if [ "${OPENSHIFT_USE_CALICO_SDN}" = "true" ]; then
    echo "Copying Calico ansible playbooks"
    rsync -rIq /home/vagrant/share/ansible/roles/calico/ $ANSIBLE_ROOT/openshift-ansible/roles/
fi

## Enable gluster S3
if [ "${OPENSHIFT_DEPLOYMENT_TYPE}" = "openshift-enterprise" ]; then
    echo "TODO - PLEASE IMPLEMENT"
    ## Enable gluster S3
    # sed -i '/^#openshift_storage_glusterfs_s3_/s/^#//g' $SCRIPT_ROOT/inventory.ini

    ## Disable gluster S3
    # sed -i '/^openshift_storage_glusterfs_s3_/s/^/#/g' $SCRIPT_ROOT/inventory.ini
fi

## Patch
## If we are deploying a containerized OpenShift, and using Calico SDN then we need patch the docker
## node service (origin-node.service) to bind mount /etc/cni/net.d, and /opt/cni/bin directories
if [ "${OPENSHIFT_USE_CALICO_SDN}" = "true" ] && [ "${OPENSHIFT_RELEASE_MAJOR_VERSION}" = "3.9" ]; then
    echo "Patching ansible playbooks for containerized openshift"
    if ! grep -q 'openshift_use_calico' $ANSIBLE_ROOT/openshift-ansible/roles/openshift_node/templates/openshift.docker.node.service; then
        sed -i '/^  {% if openshift_use_nuage | default(false) -%} $NUAGE_ADDTL_BIND_MOUNTS {% endif -%} \\/i\  {% if openshift_is_containerized | default(False) | bool and openshift_use_calico | default(False) | bool -%} -v /etc/cni/net.d:/etc/cni/net.d -v /opt/cni/bin:/opt/cni/bin {% endif -%} \\' $ANSIBLE_ROOT/openshift-ansible/roles/openshift_node/templates/openshift.docker.node.service
    fi
fi

## Patch
## Running containerized OpenShift does not correctly detect the version of OpenShift, this cause patching of
## storageClass to fail, as it ends up deploying un-patched files.
## find $ANSIBLE_ROOT/openshift-ansible -type f | grep -v README | grep -v ansible.spec | grep -v 'v3.7' | grep -v upgrades | xargs grep v3.7
if [ "${OPENSHIFT_CONTAINERIZED}" = "true" ] && [ "${OPENSHIFT_RELEASE_MAJOR_VERSION}" = "3.9" ]; then
    sed -i "s|facts\['common'\]\['examples_content_version'\] = examples_content_version|facts\['common'\]\['examples_content_version'\] = 'v3.9'|" $ANSIBLE_ROOT/openshift-ansible/roles/openshift_facts/library/openshift_facts.py
fi

## BUG FIX in 3.9.{31,33} release
## Patch for https://github.com/openshift/openshift-ansible/issues/7596#issuecomment-403241883
if [ "${OPENSHIFT_DEPLOYMENT_TYPE}" = "openshift-enterprise" ]; then
    echo "Patching ansible playbooks for issue# 7596"
    # yum --showduplicates list openshift-ansible
    INSTALLED_VERSION=$(rpm -qa openshift-ansible --qf "%{VERSION}")
    if [ "${INSTALLED_VERSION}" = "3.9.31" ] || [ "${INSTALLED_VERSION}" = "3.9.33" ]; then
        sed -i "95s/{{ hostvars\[inventory_hostname\] | certificates_to_synchronize }}/{{ hostvars\[inventory_hostname\]\['ansible_facts'\] | certificates_to_synchronize }}/" $ANSIBLE_ROOT/openshift-ansible/roles/openshift_master_certificates/tasks/main.yml
    fi
fi

## BUG FIX in 3.9.{31,33}
## Patch for https://bugzilla.redhat.com/show_bug.cgi?id=1602015
if [ "${OPENSHIFT_DEPLOYMENT_TYPE}" = "openshift-enterprise" ]; then
    echo "Patching ansible playbooks for issue# 1602015"
    # yum --showduplicates list openshift-ansible
    INSTALLED_VERSION=$(rpm -qa openshift-ansible --qf "%{VERSION}")
    if [ "${INSTALLED_VERSION}" = "3.9.31" ] || [ "${INSTALLED_VERSION}" = "3.9.33" ]; then
        sed -i 's/  when: not logging_elasticsearch_rollout_override | bool/  when: not logging_elasticsearch_rollout_override | default(false) | bool/' $ANSIBLE_ROOT/openshift-ansible/roles/openshift_logging_elasticsearch/handlers/main.yml
    fi
fi

## BUG FIX in 3.9.{31,33}
## Patch for https://github.com/openshift/openshift-ansible/issues/9068#issuecomment-403823714
if [ "${OPENSHIFT_DEPLOYMENT_TYPE}" = "openshift-enterprise" ]; then
    echo "Patching ansible playbooks for issue# 9068"
    # yum --showduplicates list openshift-ansible
    INSTALLED_VERSION=$(rpm -qa openshift-ansible --qf "%{VERSION}")
    if [ "${INSTALLED_VERSION}" = "3.9.31" ] || [ "${INSTALLED_VERSION}" = "3.9.33" ]; then
        sed -i '175s/  - glusterfs_is_native/  - glusterfs_heketi_is_native/' $ANSIBLE_ROOT/openshift-ansible/roles/openshift_storage_glusterfs/tasks/glusterfs_common.yml
    fi
fi

## Single node GlusterFS/CNS
echo "Patching ansible playbooks to support single node GlusterFS"
sed -i 's|--listfile /tmp/heketi-storage.json"|--listfile /tmp/heketi-storage.json --durability=none"|' $ANSIBLE_ROOT/openshift-ansible/roles/openshift_storage_glusterfs/tasks/heketi_deploy_part2.yml
sed -i "s@glusterfs_nodes | count >= 3@glusterfs_nodes | count >= 1@" $ANSIBLE_ROOT/openshift-ansible/roles/openshift_storage_glusterfs/tasks/glusterfs_deploy.yml
sed -i 's|--name={{ openshift_hosted_registry_storage_glusterfs_path }}"|--name={{ openshift_hosted_registry_storage_glusterfs_path }} --durability=none"|' $ANSIBLE_ROOT/openshift-ansible/roles/openshift_storage_glusterfs/tasks/glusterfs_registry.yml
if [ "${OPENSHIFT_RELEASE_MAJOR_VERSION}" = "3.9" ]; then
    sed -i '/^parameters:/a\  volumetype: "none"' $ANSIBLE_ROOT/openshift-ansible/roles/openshift_storage_glusterfs/templates/v3.9/glusterfs-storageclass.yml.j2
    sed -i 's/hacount: "3"/hacount: "1"/' $ANSIBLE_ROOT/openshift-ansible/roles/openshift_storage_glusterfs/templates/v3.9/gluster-block-storageclass.yml.j2
fi

## Patch to create gluterfs block host volume, since heketi expects to be able to create glusterfs block
## hosting volume as replica 3, in localdev we only have one host hence it silently fails "no space" error.
## https://github.com/openshift/openshift-ansible/blob/release-3.9/roles/openshift_storage_glusterfs/tasks/glusterfs_common.yml#L264
## https://github.com/openshift/openshift-ansible/blob/release-3.9/roles/openshift_storage_glusterfs/tasks/heketi_deploy_part2.yml#L126
if [ "${OPENSHIFT_RELEASE_MAJOR_VERSION}" = "3.9" ]; then
	echo "Patching ansible playbooks to support single node GlusterFS"
	filename_to_mod="$ANSIBLE_ROOT/openshift-ansible/roles/openshift_storage_glusterfs/tasks/heketi_deploy_part2.yml"
	if ! grep --quiet 'Check if gluster block hosting volume exists' ${filename_to_mod}; then
		# NOTE: DO NOT REPLACE TAB CHARACTER WITH SPACE, THIS WILL BREAK THE HEREDOC BELOW
		cat <<- 'EOF' >> ${filename_to_mod}

		- name: Check if gluster block hosting volume exists
		  command: "{{ glusterfs_heketi_client }} volume list"
		  register: blockhosting_volume

		- name: Create gluster block hosting volume
		  command: "{{ glusterfs_heketi_client }} volume create --size={{ openshift_storage_glusterfs_block_host_vol_size }} --block=true --durability=none --name=glusterfs_block_hosting_volume"
		  when: '"glusterfs_block_hosting_volume" not in blockhosting_volume.stdout'
		EOF
	fi
fi

if [ "${OPENSHIFT_USE_TIGERA_CNX}" = "true" ]; then
    echo "TODO: DEVICE A WAY SECURELY DELIVER DOCKER PULL SECRET"
fi

## Deploy OpenShift
echo "Invoking openShift-ansible playbooks"
ansible-playbook -vvv -i $SCRIPT_ROOT/inventory.ini $ANSIBLE_ROOT/openshift-ansible/playbooks/prerequisites.yml 2>&1
ansible-playbook -vvv -i $SCRIPT_ROOT/inventory.ini $ANSIBLE_ROOT/openshift-ansible/playbooks/deploy_cluster.yml 2>&1

## Generate encrypted password
## https://bugzilla.redhat.com/show_bug.cgi?id=1565447
#htpasswd -b /etc/origin/master/htpasswd ${OPENSHIFT_USER_NAME} ${OPENSHIFT_USER_PASSWD}

if [ "${OPENSHIFT_USE_TIGERA_CNX}" = "true" ]; then
    echo "TODO, DEPLOY CNX MANAGER"
fi

## Create default user account
echo " "
echo "Creating default user '${OPENSHIFT_USER_NAME}'"
oc adm policy add-cluster-role-to-user cluster-admin ${OPENSHIFT_USER_NAME}

## Persist init script
cp /tmp/vagrant-shell /home/vagrant/init.sh
chown vagrant:vagrant /home/vagrant/init.sh
chmod 755 /home/vagrant/init.sh
sed -i "s|^export RHSM_ORG=.*$|export RHSM_ORG=''|g" /home/vagrant/init.sh
sed -i "s|^export RHSM_ACTIVATION_KEY=.*$|export RHSM_ACTIVATION_KEY=''|g" /home/vagrant/init.sh

echo " "
echo "Copying kubeconfig file to ${ARTIFACT_PATH}/.kube"
rsync -rq --exclude=http-cache --exclude=api_int.oc.local_8443 /root/.kube /home/vagrant/share/artifacts/
sed -i -e "s|https://api-int.oc.local|https://${MASTER_IP}|g" /home/vagrant/share/artifacts/.kube/config
sed -i -e "s|https://api.oc.local|https://${MASTER_IP}|g" /home/vagrant/share/artifacts/.kube/config

echo "Copying kubeconfig file to /home/vagrant/.kube"
rsync -rq --exclude=http-cache --exclude=api_int.oc.local_8443 /root/.kube /home/vagrant/
chown -R vagrant:vagrant /home/vagrant/.kube

echo " "
echo "OpenShift CLI:"
echo "-----------------------------------------------------"
echo "  https://api.${OPENSHIFT_DOMAIN}:${OPENSHIFT_API_PORT}/console/command-line"
echo " "

echo " "
echo "OpenShift CLI Bash completion:"
echo "-----------------------------------------------------"
echo "  source <(oc completion bash)"
echo "  source <(oc completion zsh)"
echo " "

echo "KubeConfig MacOS/Linux:"
echo "-----------------------------------------------------"
echo "  export KUBECONFIG=\$(pwd)/artifacts/.kube/config"
echo "  oc login -u ${OPENSHIFT_USER_NAME} -p ${OPENSHIFT_USER_PASSWD} https://console.${OPENSHIFT_DOMAIN}:${OPENSHIFT_API_PORT}/"
echo " "

echo "KubeConfig Windows:"
echo "-----------------------------------------------------"
echo "  \$env:KUBECONFIG = \"\$PWD\\artifacts\\.kube\\config\""
echo "  oc.exe login -u ${OPENSHIFT_USER_NAME} -p ${OPENSHIFT_USER_PASSWD} https://console.${OPENSHIFT_DOMAIN}:${OPENSHIFT_API_PORT}/"
echo " "

echo "OpenShift console:"
echo "-----------------------------------------------------"
echo "  Url:      https://console.${OPENSHIFT_DOMAIN}:${OPENSHIFT_API_PORT}"
echo "  Username: ${OPENSHIFT_USER_NAME}"
echo "  Password: ${OPENSHIFT_USER_PASSWD}"
echo " "

## Clear logs
journalctl --vacuum-time=10s

exit 0

## TODO: NODE PREP PLAYBOOK
## https://github.com/heketi/vagrant-heketi/blob/master/openshift/roles/client/tasks/main.yml
## https://github.com/jmnohales/OCP_INSTALL
## https://github.com/barkbay/elastic-k8s-baremetal
## https://github.com/giannisalinetti/ocp-inventory
## https://github.com/heketi/vagrant-heketi

# Dissable IPv6
# https://www.thegeekdiary.com/centos-rhel-7-how-to-disable-ipv6/
# https://www.ehowstuff.com/disable-ipv6-on-redhat-centos-6-centos-7/
# https://www.unixmen.com/disable-ipv6-centos-7/
# https://access.redhat.com/solutions/8709
# https://rmohan.com/?p=7094

#if [ "${OPENSHIFT_DEPLOYMENT_TYPE}" = "origin" ]; then
#    systemctl restart origin-master-api
#fi

## CNS BUG:
## heketi expects to be able to create glusterfs block hosting volume as replica 3,and silently fails
## if it can't citing "no space" error
#HEKETI_POD=$(oc -n glusterfs get pods | grep 'heketi-storage-' | awk '{print $1}')
#HEKETI_ADMIN_KEY=$(oc get pods \
#    --namespace glusterfs \
#    -o jsonpath='{.items[*].spec.containers[?(.name=="'heketi'")].env[?(.name=="'HEKETI_ADMIN_KEY'")].value}' | \
#    awk '{ print $1 }')
#oc -n glusterfs exec -it ${HEKETI_POD} -- bash -c "\
#    HEKETI_CLI_SERVER=http://localhost:8080 \
#    HEKETI_CLI_USER=admin \
#    HEKETI_CLI_KEY=${HEKETI_ADMIN_KEY} \
#    heketi-cli volume create --size=100 --block --durability=none"

## Delete storageClass
#oc delete storageclass glusterfs-storage       || true
#oc delete storageclass glusterfs-storage-block || true

## Create storageClass
## OPENSHIFT_DOMAIN='oc.local'
#cat <<EOF | oc create -f -
#apiVersion: storage.k8s.io/v1
#kind: StorageClass
#metadata:
#  annotations:
#    storageclass.kubernetes.io/is-default-class: "true"
#  name: glusterfs-storage
#  namespace: ""
#parameters:
#  volumetype: "none"
#  resturl: http://heketi-storage-glusterfs.apps.${OPENSHIFT_DOMAIN}
#  restuser: admin
#  secretName: heketi-storage-admin-secret
#  secretNamespace: glusterfs
#provisioner: kubernetes.io/glusterfs
#reclaimPolicy: Delete
#---
#apiVersion: storage.k8s.io/v1
#kind: StorageClass
#metadata:
#  name: glusterfs-storage-block
#  namespace: ""
#parameters:
#  chapauthenabled: "true"
#  hacount: "1"
#  restsecretname: heketi-storage-admin-secret-block
#  restsecretnamespace: glusterfs
#  resturl: http://heketi-storage-glusterfs.apps.${OPENSHIFT_DOMAIN}
#  restuser: admin
#provisioner: gluster.org/glusterblock
#reclaimPolicy: Delete
#EOF

#cat <<EOF | kubectl create -f -
#apiVersion: v1
#kind: PersistentVolumeClaim
#metadata:
#  annotations:
#    volume.beta.kubernetes.io/storage-provisioner: gluster.org/glusterblock
#  labels:
#    logging-infra: support
#  name: logging-es-0
#  namespace: logging
#spec:
#  accessModes:
#  - ReadWriteOnce
#  resources:
#    requests:
#      storage: 10Gi
#  storageClassName: glusterfs-storage-block
#EOF

#cat <<EOF | kubectl create -f -
#apiVersion: v1
#kind: PersistentVolumeClaim
#metadata:
#  annotations:
#    volume.beta.kubernetes.io/storage-class: glusterfs-storage-block
#    volume.beta.kubernetes.io/storage-provisioner: gluster.org/glusterblock
#  labels:
#    logging-infra: support
#  name: logging-es-0
#  namespace: logging
#spec:
#  accessModes:
#    - ReadWriteOnce
#  resources:
#    requests:
#      storage: 10Gi
#EOF
