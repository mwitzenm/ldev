#!/bThin/bash

# set -xeuo pipefail

set -o errexit
set -o nounset
set -o pipefail

## OpenShift Origin
#ssh -o LogLevel=FATAL \
#    -o Compression=yes \
#    -o DSAAuthentication=yes \
#    -o IdentitiesOnly=yes \
#    -o StrictHostKeyChecking=no \
#    -o UserKnownHostsFile=/dev/null \
#    -o IdentityFile="~/.vagrant.d/insecure_private_key" \
#    vagrant@m1.oc.local \
#    -t "sudo systemctl stop origin-master-api && \
#        sudo systemctl stop origin-master-controllers && \
#        sudo systemctl stop origin-node && \
#        sudo systemctl stop docker && \
#        sudo shutdown -h -t 30"

## OpenShift Enterprise
#ssh -o LogLevel=FATAL \
#    -o Compression=yes \
#    -o DSAAuthentication=yes \
#    -o IdentitiesOnly=yes \
#    -o StrictHostKeyChecking=no \
#    -o UserKnownHostsFile=/dev/null \
#    -o IdentityFile="~/.vagrant.d/insecure_private_key" \
#    vagrant@m1.oc.local \
#    -t "sudo systemctl stop atomic-openshift-master-api && \
#        sudo systemctl stop atomic-openshift-master-controllers && \
#        sudo systemctl stop atomic-openshift-node && \
#        sudo systemctl stop docker && \
#        sudo shutdown -h -t 30"


TODAY=$(date +"%Y%m%d%H%M%S")
VERSION='3.9.33'
mkdir -p "$(pwd)/vagrant-boxes/boxes"

# RHEL
BOX_NAME='caas-rhel'
VERSION='1.8.12'
BOX_FILE="${BOX_NAME}-v${VERSION}-${TODAY}.virtualbox.box"
BOX_FILE_PATH="$(pwd)/vagrant-boxes/boxes/${BOX_FILE}"
vagrant package --output "${BOX_FILE_PATH}" --base ${BOX_NAME}
shasum -a 256 "${BOX_FILE_PATH}"
vagrant box add ${BOX_NAME} "${BOX_FILE_PATH}"

# Origin
BOX_NAME='openshift-origin'
BOX_FILE="${BOX_NAME}-v${VERSION}-${TODAY}.virtualbox.box"
BOX_FILE_PATH="$(pwd)/vagrant-boxes/boxes/${BOX_FILE}"
cp "$(pwd)/artifacts/logs/provision_$(date +"%Y-%m-%d").log" "$(pwd)/vagrant-boxes/boxes/${BOX_NAME}-v${VERSION}.build.log"
vagrant package --output "${BOX_FILE_PATH}" --base ${BOX_NAME}
shasum -a 256 "${BOX_FILE_PATH}"
vagrant box add ${BOX_NAME} "${BOX_FILE_PATH}"

# Enterprise
BOX_NAME='openshift-enterprise'
BOX_FILE="${BOX_NAME}-v${VERSION}-$(date +"%Y%m%d%H%M%S").virtualbox.box"
BOX_FILE_PATH="$(pwd)/vagrant-boxes/boxes/${BOX_FILE}"
cp "$(pwd)/artifacts/logs/provision_$(date +"%Y-%m-%d").log" "$(pwd)/vagrant-boxes/boxes/${BOX_NAME}-v${VERSION}.build.log"
vagrant package --output "${BOX_FILE_PATH}" --base ${BOX_NAME}
shasum -a 256 "${BOX_FILE_PATH}"
vagrant box add ${BOX_NAME} "${BOX_FILE_PATH}"
