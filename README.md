# Container Local Development Environment
Getting started with any distributed system that has several components expected to run on different servers can be challenging. Often developers and administrators want to be able to take a new system for a spin before diving straight into a full-fledged deployment on a cluster.

All in one installations are a good remedy to this challenge. They provide a quick way to test a new technology by getting a working setup on a local machine. They can be used by developers in their local workflow and by system administrators to learn the basics of the deployment setup and configuration of various components.

# Quick Start

1. Install supported operating system MacOS, Windows 10, Linux
1. Install [Git](https://git-scm.com/downloads), [Vagrant](https://www.vagrantup.com/downloads.html), and [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
1. [Powershell 5+](https://docs.microsoft.com/en-us/powershell/scripting/setup/installing-windows-powershell?view=powershell-6) and [7zip](https://www.7-zip.org/a/7z1801-x64.exe) (windows only requirement)
1. Clone, Configure, and Deploy
    ```
    git clone https://github.com/spuranam/ldev

    or

    git clone git@github.com:spuranam/ldev.git
    ```
    > ⚠ NOTE: On windows you should execute these commands in powershell running in administrative context.
1. copy the file [./RHSM.env.tpl](RHSM.env.tpl) to RHSM.env, update the file RHSM.env with your RHSM info, note do not modify the value of RHSM_ORG
1. Execute the command:
    ```
    source $(pwd)/RHSM.env && \
        RHSM_USERNAME="${RHSM_USERNAME}" \
        RHSM_PASSWORD_ACT_KEY="${RHSM_PASSWORD_ACT_KEY}" \
        RHSM_ORG="${RHSM_ORG}" \
        RHSM_POOLID="${RHSM_POOLID}" \
        MASTER_VM_MEMORY=8192 \
        MASTER_VM_CPUS=4 \
        vagrant up --provision
    ```
1. Access the GUI [https://console.oc.local:8443](https://console.oc.local:8443)
    ```
    Username: admin
    Password: sandbox
    ```

# Default service endpoints

| Component                  | Details                                     |
| :------------------------- | :------------------------------------------ |
| All-in-one node            | m1.oc.local                                 |
| Master/Worker SSH Username | vagrant                                     |
| SSH Private key            | <PWD>/.vagrant/machines/default/virtualbox/private_key |
| Tectonic Web Console       | https://console.oc.local:8443               |
| Default username           | __admin__                                   |
| Default password           | __sandbox__                                 |
| KUBECONFIG                 | <PWD>/artifacts/.kube/config                |
| StorageClass Name          | az1                                         |
| Wildcard Ingress URI       | *.apps.oc.local                             |

>NOTE: StorageClass __DO NOT__ yet work in OpenShift
