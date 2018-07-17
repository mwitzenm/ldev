#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

export SCRIPT_ROOT=$( cd "$( dirname "$0" )" && pwd )
export OPENSHIFT_USER_PASSWD_ENC="$(echo $OPENSHIFT_USER_PASSWD | openssl passwd -stdin -apr1)"
export ANSIBLE_ROOT=${SCRIPT_ROOT}

echo "DEFAULT_HOST_IP=$DEFAULT_HOST_IP"

# Manually configure DNS settings on teh guest to refer to CoreDNS on the host.
nmcli con mod "System eth0" ipv4.dns "${DEFAULT_HOST_IP}"
# echo "PEERDNS=no" >> /etc/sysconfig/network-scripts/ifcfg-eth0
nmcli con mod "System eth0" ipv4.ignore-auto-dns yes
systemctl restart NetworkManager

# Dissable IPv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -p

## Setup http proxy variables
set +u
if [ ! -z "${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy}}}}" ]; then
    export http_proxy="${HTTP_PROXY:-${http_proxy:-${HTTPS_PROXY:-${https_proxy}}}}"
    export https_proxy="${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy}}}}"
    export no_proxy="${NO_PROXY:-${no_proxy}}"

    # Configure Yum proxy
    sed -i 's|\[main\]|\[main\]\nproxy=http://proxyvipfmcc.nb.ford.com:83|' /etc/yum.conf
fi
set -u

# Test internet connectivity
set +u
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
if [ "${OPENSHIFT_DEPLOYMENT_TYPE}" = "openshift-enterprise" ]; then
    set +u
    if [ ! -z "${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy}}}}" ]; then
        http_proxy_re='^https?://(([^:]{1,128}):([^@]{1,256})@)?([^:/]{1,255})(:([0-9]{1,5}))?/?'
        # http_proxy_re='^http:\/\/(([^:]+):?(\S+)?@)?([^:]+)(:(\d+))?\/?$'
        if [[ "$http_proxy" =~ $http_proxy_re ]]; then
            # care taken to skip parent nesting groups 1 and 5
            export proxy_user=${BASH_REMATCH[2]}
            export proxy_pass=${BASH_REMATCH[3]}
            export proxy_host=${BASH_REMATCH[4]}
            export proxy_port=${BASH_REMATCH[6]}
        fi
        subscription-manager config --server.proxy_hostname="${proxy_host}" --server.proxy_port="${proxy_port}" --server.no_proxy="${no_proxy}"
    else
        subscription-manager config --server.proxy_hostname='' --server.proxy_port='' --server.no_proxy=''
    fi
    set -u

    subscription-manager register --username="${RHSM_USERNAME}" --password="${RHSM_PASSWORD_ACT_KEY}" || true
    subscription-manager attach --pool=$RHSM_POOLID || true
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
## Update system to latest packages and install dependencies
yum makecache
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
    # yum install -y atomic-openshift-docker-excluder atomic-openshift-excluder unexclude

    ## Install the packages for Ansible
    if [ "$(hostname)" = "${MASTER_FQDN}" ] ; then
        yum install -y ansible openshift-ansible
    fi
fi
set -e


if [ $(cat /etc/hosts | grep console | wc -l) == 0 ]; then
cat <<EOD > /etc/hosts
#127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
#::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

${MASTER_IP} console.${OPENSHIFT_DOMAIN} console
${MASTER_IP} api.${OPENSHIFT_DOMAIN} api
${MASTER_IP} api-int.${OPENSHIFT_DOMAIN} api-int

${MASTER_IP} ${MASTER_FQDN} ${MASTER_HOSTNAME}
${INFRA_IP} ${INFRA_FQDN} ${INFRA_HOSTNAME}
EOD
fi

if [ -z $DOCKER_DISK ]; then
    echo "Not setting the Docker storage."
elif [ $(cat /etc/sysconfig/docker-storage-setup | grep docker-vg | wc -l) == 0  ]; then
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

## Run docker as unprivileged user on CentOS 7
if ! getent group dockerroot | grep &>/dev/null "\bvagrant\b"; then
    usermod -aG dockerroot vagrant
    echo "{\"live-restore\": true,\"group\": \"dockerroot\"}" > /etc/docker/daemon.json
    systemctl restart docker
    ls -ltr /var/run/docker.sock
fi

## Generate ssh key pairs
if [ ! -f ~/.ssh/id_rsa ]; then
    mkdir -p /root/.ssh
    cp -v /home/vagrant/.ssh/id_rsa /root/.ssh
    cp -v /home/vagrant/.ssh/authorized_keys /root/.ssh
    chmod -R 600 /root/.ssh
    if [ "$(hostname)" = "${INFRA_FQDN}" ]; then
        ssh -o StrictHostKeyChecking=no root@$INFRA_IP "pwd" < /dev/null
        ssh -o StrictHostKeyChecking=no root@$INFRA_FQDN "pwd" < /dev/null
    elif [ "$(hostname)" = "${MASTER_FQDN}" ]; then
        ssh -o StrictHostKeyChecking=no root@$MASTER_IP "pwd" < /dev/null
        ssh -o StrictHostKeyChecking=no root@$MASTER_FQDN "pwd" < /dev/null
    fi
fi

# other steps are required only on master node
if [ "$(hostname)" = "${INFRA_FQDN}" ]; then
    # Persist init script
    cp /tmp/vagrant-shell /home/vagrant/init.sh
    chown vagrant:vagrant /home/vagrant/init.sh
    chmod 755 /home/vagrant/init.sh
    sed -i "s|^export RHSM_USERNAME=.*$|export RHSM_USERNAME=''|g" /home/vagrant/init.sh
    sed -i "s|^export RHSM_PASSWORD_ACT_KEY=.*$|export RHSM_PASSWORD_ACT_KEY=''|g" /home/vagrant/init.sh
    sed -i "s|^export RHSM_ORG=.*$|export RHSM_ORG=''|g" /home/vagrant/init.sh
    sed -i "s|^export RHSM_POOLID=.*$|export RHSM_POOLID=''|g" /home/vagrant/init.sh

    # No further action is required on infra nodes
    exit 0
fi

# add proxy in inventory.ini if proxy variables are set
set +u
if [ ! -z "${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy}}}}" ]; then
    export openshift_http_proxy="${HTTP_PROXY:-${http_proxy:-${HTTPS_PROXY:-${https_proxy}}}}"
    export openshift_https_proxy="${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy}}}}"
    export openshift_no_proxy="${NO_PROXY:-${no_proxy}}"
else
    export openshift_http_proxy=""
    export openshift_https_proxy=""
    export openshift_no_proxy=""

fi
set -u

if [ "${OPENSHIFT_USE_CALICO_SDN}" = "true" ]; then
    export OS_SDN_NETWORK_PLUGIN_NAME='cni'
    export OPENSHIFT_USE_OPENSHIFT_SDN='false'
else
    export OPENSHIFT_USE_OPENSHIFT_SDN='true'
fi

# OpenShift v3.10+ does not support 'filename' attribute
if [ "${OPENSHIFT_RELEASE_MAJOR_VERSION}" != "3.9" ]; then
    sed -i "s|, 'filename': '/etc/origin/master/htpasswd'||g" $SCRIPT_ROOT/inventory.ini.tmpl
fi

# OpenShift Enterprise version does not yet support running the control plane in containers
if [ "${OPENSHIFT_DEPLOYMENT_TYPE}" = "openshift-enterprise" ]; then
    export OPENSHIFT_CONTAINERIZED='false'
fi

envsubst < $SCRIPT_ROOT/inventory.ini.tmpl > $SCRIPT_ROOT/inventory.ini

if [ "${OPENSHIFT_DEPLOYMENT_TYPE}" = "origin" ]; then
    # CentOS 7 - RPM install
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

if [ "${OPENSHIFT_USE_CALICO_SDN}" = "true" ]; then
    rsync -rIq /home/vagrant/share/ansible/roles/calico/ $ANSIBLE_ROOT/openshift-ansible/roles/
fi

# If we are deploying a containerized OpenShift, and using Calico SDN then we need patch the docker
# node service (origin-node.service) to bind mount /etc/cni/net.d, and /opt/cni/bin directories
if [ "${OPENSHIFT_USE_CALICO_SDN}" = "true" ] && [ "${OPENSHIFT_RELEASE_MAJOR_VERSION}" = "3.9" ]; then
    if ! grep -q 'openshift_use_calico' $ANSIBLE_ROOT/openshift-ansible/roles/openshift_node/templates/openshift.docker.node.service; then
        sed -i '/^  {% if openshift_use_nuage | default(false) -%} $NUAGE_ADDTL_BIND_MOUNTS {% endif -%} \\/i\  {% if openshift_is_containerized | default(False) | bool and openshift_use_calico | default(False) | bool -%} -v /etc/cni/net.d:/etc/cni/net.d -v /opt/cni/bin:/opt/cni/bin {% endif -%} \\' $ANSIBLE_ROOT/openshift-ansible/roles/openshift_node/templates/openshift.docker.node.service
    fi
fi

# BUG FIX:(in 3.9.31 release) https://github.com/openshift/openshift-ansible/issues/7596#issuecomment-403241883
if [ "${OPENSHIFT_DEPLOYMENT_TYPE}" = "openshift-enterprise" ]; then
    # yum --showduplicates list openshift-ansible
    if [ "$(rpm -qa openshift-ansible --qf "%{VERSION}")" = "3.9.31" ]; then
        sed -i "95s/{{ hostvars\[inventory_hostname\] | certificates_to_synchronize }}/{{ hostvars\[inventory_hostname\]\['ansible_facts'\] | certificates_to_synchronize }}/" $ANSIBLE_ROOT/openshift-ansible/roles/openshift_master_certificates/tasks/main.yml
    fi
fi

# Single node GlusterFS/CNS
# See:
#  https://github.com/gluster/gluster-kubernetes/issues/467#issuecomment-384916200
#  https://github.com/gluster/gluster-kubernetes/issues/468#issuecomment-384998539
#  https://github.com/heketi/heketi/blob/master/client/cli/go/cmds/volume.go#L130
#  https://github.com/heketi/heketi/blob/master/client/cli/go/cmds/heketi_storage.go#L64
#  https://docs.oracle.com/en/solutions/set-up-gluster-file-system/index.html#GUID-602A6F75-7927-43B4-B2AD-4CF145F29660
sed -i "s|--listfile /tmp/heketi-storage.json|--listfile /tmp/heketi-storage.json --durability=none|" $ANSIBLE_ROOT/openshift-ansible/roles/openshift_storage_glusterfs/tasks/heketi_deploy_part2.yml
sed -i "s@glusterfs_nodes | count >= 3@glusterfs_nodes | count >= 1@" $ANSIBLE_ROOT/openshift-ansible/roles/openshift_storage_glusterfs/tasks/glusterfs_deploy.yml

#if [ "${OPENSHIFT_RELEASE_MAJOR_VERSION}" = "3.9"]; then
#    # https://github.com/gluster/gluster-kubernetes/blob/master/docs/examples/containerized_heketi_dedicated_gluster/README.md#create-a-storage-class
#    sed -i '/^parameters:/a\  volumetype: "replicate:1"' $ANSIBLE_ROOT/openshift-ansible/roles/openshift_storage_glusterfs/templates/v3.9/glusterfs-storageclass.yml.j2
#    # https://github.com/gluster/gluster-kubernetes/blob/master/docs/design/gluster-block-provisioning.md#details-about-the-glusterblock-provisioner
#    sed -i 's/hacount: "3"/hacount: "1"/' $ANSIBLE_ROOT/openshift-ansible/roles/openshift_storage_glusterfs/templates/v3.9/gluster-block-storageclass.yml.j2
#    # https://github.com/gluster/gluster-kubernetes/tree/master/docs/examples/gluster-s3-storage-template
#    # $ANSIBLE_ROOT/openshift-ansible/roles/openshift_storage_glusterfs/templates/gluster-s3-storageclass.yml.j2
#else
#    # https://github.com/gluster/gluster-kubernetes/blob/master/docs/examples/containerized_heketi_dedicated_gluster/README.md#create-a-storage-class
#    sed -i '/^parameters:/a\  volumetype: "replicate:1"' $ANSIBLE_ROOT/openshift-ansible/roles/openshift_storage_glusterfs/templates/glusterfs-storageclass.yml.j2
#    # https://github.com/gluster/gluster-kubernetes/blob/master/docs/design/gluster-block-provisioning.md#details-about-the-glusterblock-provisioner
#    sed -i 's/hacount: "3"/hacount: "1"/' $ANSIBLE_ROOT/openshift-ansible/roles/openshift_storage_glusterfs/templates/gluster-block-storageclass.yml.j2
#    # https://github.com/gluster/gluster-kubernetes/tree/master/docs/examples/gluster-s3-storage-template
#    # $ANSIBLE_ROOT/openshift-ansible/roles/openshift_storage_glusterfs/templates/gluster-s3-storageclass.yml.j2
#fi

#oc patch storageclass glusterfs-storage -p '{"parameters":{"volumetype":{"replicate":"1"}}}'
#oc patch storageclass glusterfs-storage-block -p '{"parameters":{"hacount":"1"}}'
#oc get storageclass glusterfs-storage-block -o yaml > glusterfs-storage-block.yaml
#oc get storageclass glusterfs-storage -o yaml > glusterfs-storage.yaml
#oc delete storageclass glusterfs-storage
#oc delete storageclass glusterfs-storage-block
#oc create -f glusterfs-storage-block.yaml
#oc create -f glusterfs-storage.yaml

# Deploy OpenShift
ansible-playbook -vvv -i $SCRIPT_ROOT/inventory.ini $ANSIBLE_ROOT/openshift-ansible/playbooks/prerequisites.yml 2>&1
ansible-playbook -vvv -i $SCRIPT_ROOT/inventory.ini $ANSIBLE_ROOT/openshift-ansible/playbooks/deploy_cluster.yml 2>&1

## Generate encrypted password
## https://bugzilla.redhat.com/show_bug.cgi?id=1565447
#htpasswd -b /etc/origin/master/htpasswd ${OPENSHIFT_USER_NAME} ${OPENSHIFT_USER_PASSWD}

# Create default user account
echo " "
oc adm policy add-cluster-role-to-user cluster-admin ${OPENSHIFT_USER_NAME}

# Deploy Storage

if [ "${OPENSHIFT_DEPLOYMENT_TYPE}" = "origin" ]; then
    systemctl restart origin-master-api
fi

# Persist init script
cp /tmp/vagrant-shell /home/vagrant/init.sh
chown vagrant:vagrant /home/vagrant/init.sh
chmod 755 /home/vagrant/init.sh
sed -i "s|^export RHSM_USERNAME=.*$|export RHSM_USERNAME=''|g" /home/vagrant/init.sh
sed -i "s|^export RHSM_PASSWORD_ACT_KEY=.*$|export RHSM_PASSWORD_ACT_KEY=''|g" /home/vagrant/init.sh
sed -i "s|^export RHSM_ORG=.*$|export RHSM_ORG=''|g" /home/vagrant/init.sh
sed -i "s|^export RHSM_POOLID=.*$|export RHSM_POOLID=''|g" /home/vagrant/init.sh

echo " "
echo "Copying kubeconfig file to ${ARTIFACT_PATH}/.kube"
rsync -rq --exclude=http-cache --exclude=api_int.oc.local_8443 /root/.kube /home/vagrant/share/artifacts/
sed -i -e "s|https://api-int.oc.local|https://${MASTER_IP}|g" /home/vagrant/share/artifacts/.kube/config
sed -i -e "s|https://api.oc.local|https://${MASTER_IP}|g" /home/vagrant/share/artifacts/.kube/config

echo "Copying kubeconfig file to /home/vagrant/.kube"
rsync -rq --exclude=http-cache --exclude=api_int.oc.local_8443 /root/.kube /home/vagrant/

echo " "
echo "OpenShift CLI:"
echo "-----------------------------------------------------"
echo "  https://api.${OPENSHIFT_DOMAIN}:${OPENSHIFT_API_PORT}/console/command-line"
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

# Clear logs
journalctl --vacuum-time=10s

exit 0
