#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

export SCRIPT_ROOT=$( cd "$( dirname "$0" )" && pwd )

echo "DEFAULT_HOST_IP=$DEFAULT_HOST_IP"

if ! grep -q "${MASTER_FQDN}" /etc/hosts; then
	echo "Updating /etc/hosts file"
	# Note: DO NOT REPLACE TAB CHARACTER WITH SPACE, THIS WILL BREAK THE HEREDOC BELOW
	cat <<- EOD > /etc/hosts
	${MASTER_IP} ${MASTER_FQDN} ${MASTER_HOSTNAME}
	EOD
fi

echo "${MASTER_FQDN}" > /etc/hostname

# Manually configure DNS settings on teh guest to refer to CoreDNS on the host.
nmcli con mod "System eth0" ipv4.dns "${DEFAULT_HOST_IP}"
# echo "PEERDNS=no" >> /etc/sysconfig/network-scripts/ifcfg-eth0
nmcli con mod "System eth0" ipv4.ignore-auto-dns yes
systemctl restart NetworkManager

## Dissable IPv6
## https://wiki.centos.org/FAQ/CentOS6#head-d47139912868bcb9d754441ecb6a8a10d41781df
#if ! grep -q -F 'net.ipv6.conf.all.disable_ipv6 = 1' /etc/sysctl.conf; then
#    sysctl -w net.ipv6.conf.all.disable_ipv6=1
#    sysctl -w net.ipv6.conf.lo.disable_ipv6=1
#    sysctl -w net.ipv6.conf.default.disable_ipv6=1
#    sysctl -p
#fi

## Setup http proxy variables
set +u
if [ ! -z "${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy}}}}" ]; then
    export http_proxy="${HTTP_PROXY:-${http_proxy:-${HTTPS_PROXY:-${https_proxy}}}}"
    export https_proxy="${HTTPS_PROXY:-${https_proxy:-${HTTP_PROXY:-${http_proxy}}}}"
    export no_proxy="${NO_PROXY:-${no_proxy}}"

    # Configure Yum proxy
    #sed -i "s|\[main\]|\[main\]\nproxy=${http_proxy}|" /etc/yum.conf
    sed -i "/^proxy=.*/d" /etc/yum.conf
    sed -i "/\[main\]/a proxy=${http_proxy}" /etc/yum.conf

    if [ "${RHSM_ORG}" != "" ] && [ "${RHSM_ACTIVATION_KEY}" != "" ]; then
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
    fi
else
    # Delete the line, with proxy configuration from /etc/yum.conf
    sed -i "/^proxy=.*/d" /etc/yum.conf

    if [ "${RHSM_ORG}" != "" ] && [ "${RHSM_ACTIVATION_KEY}" != "" ]; then
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
if [ "${RHSM_ORG}" != "" ] && [ "${RHSM_ACTIVATION_KEY}" != "" ]; then
    echo "Enrolling VM with Red Hat Subscription-Manager"
    #subscription-manager register --username="${RHSM_USERNAME}" --password="${RHSM_PASSWORD_ACT_KEY}" || true
    #subscription-manager attach --pool=$RHSM_POOLID || true
    subscription-manager register --org="${RHSM_ORG}" --activationkey="${RHSM_ACTIVATION_KEY}" || true

    subscription-manager release --set='7.5'
    subscription-manager repos --disable="*"
    subscription-manager repos \
        --enable="rhel-7-server-rpms" \
        --enable="rhel-7-server-extras-rpms"

    ## https://access.redhat.com/articles/1320623
    rm -fr /var/cache/yum/*
    yum clean all

    yum makecache fast
    yum repolist
    yum -y update
    subscription-manager repos --disable="*"

    yum clean all
    rm -fr /var/cache/yum/*
    # subscription-manager repos --list | grep -B3 'Enabled:   1'
fi

## Clear logs
journalctl --vacuum-time=10s

exit 0
