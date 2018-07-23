#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail


function enable_proxy() {
    # enable proxy i.e uncomment lines
    local filename=$1
    sed -i '/^#HTTP_PROXY/s/^#//g' $filename
    sed -i '/^#HTTPS_PROXY/s/^#//g' $filename
    sed -i '/^#NO_PROXY/s/^#//g' $filename
}

function disable_proxy() {
    # disable proxy i.e comment lines
    local filename=$1
    sed -i '/^HTTP_PROXY/s/^/#/g' $filename
    sed -i '/^HTTPS_PROXY/s/^/#/g' $filename
    sed -i '/^NO_PROXY/s/^/#/g' $filename
}

set +u
if [ -z "${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy}}}}" ]; then
    export http_proxy="${HTTP_PROXY:-${http_proxy:-${HTTPS_PROXY:-${https_proxy}}}}"
    export https_proxy="${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy}}}}"
    export no_proxy="${NO_PROXY:-${no_proxy}}"

    # https://docs.openshift.org/3.9/install_config/http_proxies.html
    if [ "${OPENSHIFT_DEPLOYMENT_TYPE}" = "origin" ]; then
        # Stop services
        systemctl stop origin-master-api
        systemctl stop origin-master-controllers
        systemctl stop origin-node
        systemctl stop docker

        # Disable yum proxy
        sed -i '/^proxy/s/^/#/g' /etc/yum.conf

        nmcli con mod "System eth0" ipv4.dns "${DEFAULT_HOST_IP}"
        nmcli con mod "System eth0" ipv4.ignore-auto-dns yes
        systemctl restart NetworkManager

        # Disable proxy configurations
        for f in /etc/sysconfig/origin-master-api /etc/sysconfig/origin-master-controllers /etc/sysconfig/origin-node /etc/sysconfig/docker; do
            echo "Processing $f"
            # do something on $f
            disable_proxy $f
        done

        # Start services
        systemctl start docker
        systemctl start origin-node
        systemctl start origin-master-controllers
        systemctl start origin-master-api
    fi

    # https://docs.openshift.com/container-platform/3.9/install_config/http_proxies.html
    if [ "${OPENSHIFT_DEPLOYMENT_TYPE}" = "openshift-enterprise" ]; then
        # Stop services
        systemctl stop atomic-openshift-master-api
        systemctl stop atomic-openshift-master-controllers
        systemctl stop atomic-openshift-node
        systemctl stop docker

        # Disable yum proxy
        sed -i '/^proxy/s/^/#/g' /etc/yum.conf

        nmcli con mod "System eth0" ipv4.dns "${DEFAULT_HOST_IP}"
        nmcli con mod "System eth0" ipv4.ignore-auto-dns yes
        systemctl restart NetworkManager

        # Disable proxy configurations
        for f in /etc/sysconfig/atomic-openshift-master-api /etc/sysconfig/atomic-openshift-master-controllers /etc/sysconfig/atomic-openshift-node /etc/sysconfig/docker; do
            echo "Processing $f"
            # do something on $f
            disable_proxy $f
        done

        # Start services
        systemctl start docker
        systemctl start atomic-openshift-node
        systemctl start atomic-openshift-master-controllers
        systemctl start atomic-openshift-master-api
    fi

fi
set -u

echo "Copying kubeconfig file to ${ARTIFACT_PATH}/.kube"
rsync -rIq --exclude=http-cache --exclude=api_int.oc.local_8443 /root/.kube /home/vagrant/share/artifacts/
sed -i -e "s|https://api-int.oc.local|https://${MASTER_IP}|g" /home/vagrant/share/artifacts/.kube/config
sed -i -e "s|https://api.oc.local|https://${MASTER_IP}|g" /home/vagrant/share/artifacts/.kube/config

echo "Copying kubeconfig file to /home/vagrant/.kube"
rsync -rIq --exclude=http-cache --exclude=api_int.oc.local_8443 /root/.kube /home/vagrant/
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

exit 0
