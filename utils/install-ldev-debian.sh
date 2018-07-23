#!/usr/bin/env bash

# This script installs packages and tools needed to run Kubernetes local development environment
# on debian 9 server, it assumes that current user has passwordless sudo access and has network
# access to internet.

set -o errexit
set -o nounset
set -o pipefail

# You need to adjust these variables if you outside corporate network
DEFAULT_HTTP_PROXY="http://mycorp.com:83"
DEFAULT_HTTPS_PROXY="http://mycorp.com:83"
DEFAULT_NO_PROXY="127.0.0.1,localhost,.mycorp.com,.local"

VAGRANT_VERSION='2.1.2'

# Lets assume we do not have to traverse corporate HTTP proxies
export ENABLE_HTTP_PROXY=false
export http_proxy=""
export https_proxy=""
export no_proxy=""

set +e
HTTP_CODE=$(curl -k -L -I --silent --show-error --fail --output /dev/null -w "%{http_code}" --connect-timeout 10 --proxy $DEFAULT_HTTP_PROXY https://google.com)
if [ "$HTTP_CODE" = "200" ]; then
    export ENABLE_HTTP_PROXY=true
fi

set -e
if [ "$ENABLE_HTTP_PROXY" = "true" ]; then
    export http_proxy="${DEFAULT_HTTP_PROXY}"
    export https_proxy="${DEFAULT_HTTPS_PROXY}"
    export no_proxy="${DEFAULT_NO_PROXY}"
fi

# Use parted to extend root partition to available /dev/sda space
sudo -E apt-get -y install parted
END=$(sudo -E parted /dev/sda print free  | grep Free | tail -1 | awk "{print \$2}")
sudo -E parted /dev/sda resizepart 2 $END
sudo -E parted /dev/sda resizepart 5 $END
sudo -E pvresize /dev/sda5
VGROUP=$(mount | grep root | awk "{ print \$1 }")
sudo -E lvextend -l +100%FREE -r $VGROUP

# Install packages
export DEBIAN_FRONTEND=noninteractive
sudo -E apt-get -y update
sudo -E apt-get -y upgrade
sudo -E apt-get -y dist-upgrade
sudo -E apt-get -y autoclean
sudo -E apt-get -y autoremove

# Install X
sudo -E apt-get -y install xserver-xorg xserver-xorg-core \
    xfonts-base xinit --no-install-recommends

# Install Gnome
sudo -E apt-get -y install libgl1-mesa-dri x11-xserver-utils gnome-session \
    gnome-shell gnome-terminal gnome-control-center nautilus \
    gnome-panel gnome-settings-daemon metacity autocutsel \
    gnome-icon-theme gdm3 --no-install-recommends

# Install utils
sudo -E apt-get -y install net-tools tightvncserver \
    nfs-kernel-server portmap resolvconf gedit git needrestart \
    --no-install-recommends

# reboot when the kernel has been upgraded
needrestart_ksta=$(sudo needrestart -b 2> /dev/null | grep 'NEEDRESTART-KSTA' | awk '{print $2}')
if [[ $needrestart_ksta -gt 1 ]] ; then
    echo "Kernel upgrade detected, rebooting now. Please re-run this script after reboot."
    sudo reboot
fi

# vnc config
mkdir -p /home/$(whoami)/.vnc
chmod 0700 /home/$(whoami)/.vnc
echo "vagrant" | tightvncpasswd -f > /home/$(whoami)/.vnc/passwd
chown -R $(whoami):$(whoami) /home/$(whoami)/.vnc
chmod 0600 /home/$(whoami)/.vnc/passwd
cat <<EOF > /home/$(whoami)/.vnc/xstartup
#!/bin/sh

autocutsel -fork
export XKL_XMODMAP_DISABLE=1
/etc/X11/Xsession

unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources

xsetroot -solid grey
vncconfig -nowin &

#gnome-session --session=gnome-classic &
#gnome-session --session=ubuntu-2d &
gnome-session &
gnome-panel &
gnome-settings-daemon &
metacity &
nautilus &
gnome-terminal &
EOF
chmod 0755 /home/$(whoami)/.vnc/xstartup

# vnc systemd service
if [ ! -f /etc/systemd/system/vncserver@.service ]; then
cat << EOF | sudo tee /etc/systemd/system/vncserver@.service
#/etc/systemd/system/vncserver@.service
# The vncserver service unit file
#
# Quick HowTo:
# 1. Copy this file to /etc/systemd/system/vncserver@.service
# 2. Edit /etc/systemd/system/vncserver@.service, replacing <USER>
#    with the actual user name. Leave the remaining lines of the file unmodified
#    (ExecStart=/usr/sbin/runuser -l <USER> -c "/usr/bin/vncserver %i"
#     PIDFile=/home/<USER>/.vnc/%H%i.pid)
# 3. Run `systemctl daemon-reload`
# 4. Run `systemctl enable vncserver@:<display>.service`
#
# DO NOT RUN THIS SERVICE if your local area network is
# untrusted!  For a secure way of using VNC, you should
# limit connections to the local host and then tunnel from
# the machine you want to view VNC on (host A) to the machine
# whose VNC output you want to view (host B)
#
# [user@hostA ~]$ ssh -v -C -L 590N:localhost:590M hostB
# [user@hostA ~]$ ssh -L 590N:127.0.0.1:590M -N -f -l username server_ip_address
#
# this will open a connection on port 590N of your hostA to hostB's port 590M
# (in fact, it ssh-connects to hostB and then connects to localhost (on hostB).
# See the ssh man page for details on port forwarding)
#
# You can then point a VNC client on hostA at vncdisplay N of localhost and with
# the help of ssh, you end up seeing what hostB makes available on port 590M
#
# Use "-nolisten tcp" to prevent X connections to your VNC server via TCP.
#
# Use "-localhost" to prevent remote VNC clients connecting except when
# doing so through a secure tunnel.  See the "-via" option in the
# 'man vncviewer' manual page.
[Unit]
Description=Start TightVNC server at startup
After=syslog.target network.target

[Service]
Type=forking
User=$(whoami)
PAMName=login
#PIDFile=/home/%u/.vnc/%H:%i.pid
PIDFile=/home/$(whoami)/.vnc/%H:%i.pid
# Clean any existing files in /tmp/.X11-unix environment
# ExecStartPre=/bin/sh -c '/usr/bin/vncserver -kill %i > /dev/null 2>&1 || :'
ExecStartPre=-/usr/bin/vncserver -kill :%i > /dev/null 2>&1
ExecStart=/usr/bin/vncserver -depth 24 -geometry 1280x800 -nolisten tcp -localhost :%i
#ExecStop=/usr/bin/vncserver -kill :%i
ExecStop=/bin/sh -c '/usr/bin/vncserver -kill %i > /dev/null 2>&1 || :'
# Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
sudo chown root:root /etc/systemd/system/vncserver@.service
sudo systemctl daemon-reload
# sudo systemctl reload vncserver@1.service
sudo systemctl enable vncserver@1.service
sudo systemctl start vncserver@1.service
fi

# Install virtaulBox
cat << EOF | sudo tee /etc/apt/sources.list.d/virtualbox.list
deb http://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib
EOF
wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | sudo -n apt-key add -
wget -q https://www.virtualbox.org/download/oracle_vbox.asc -O- | sudo -n apt-key add -
sudo -E apt-get -y update
sudo -E apt-get -y install linux-headers-$(uname -r) dkms virtualbox-5.2 --no-install-recommends

# Install vagrant
if ! which vagrant > /dev/null; then
cd /tmp
curl \
    --connect-timeout "${CURL_CONNECTION_TIMEOUT:-20}" \
    --retry "${CURL_RETRY:-5}" \
    --retry-delay "${CURL_RETRY_DELAY:-0}" \
    --retry-max-time "${CURL_RETRY_MAX_TIME:-60}" \
    --insecure \
    --progress-bar \
    --location \
    --remote-name \
    https://releases.hashicorp.com/vagrant/${VAGRANT_VERSION}/vagrant_${VAGRANT_VERSION}_x86_64.deb
sudo -E dpkg -i /tmp/vagrant_${VAGRANT_VERSION}_x86_64.deb
sudo -E apt install -f -y
rm -rf /tmp/vagrant_${VAGRANT_VERSION}_x86_64.deb
fi

# https://www.linuxbabe.com/debian/install-firefox-quantum-debian-9-stretch
sudo apt-get -y install snapd
sudo snap install firefox

# Install configure Docker
sudo -E apt-get -y install apt-transport-https ca-certificates \
     curl  gnupg2 software-properties-common --no-install-recommends

# Add the GPG key for Docker repository
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release; echo "$ID")/gpg | sudo apt-key add -
# Add the official Docker repository to the system
echo "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee -a /etc/apt/sources.list.d/docker.list
sudo -E apt-get update
# Make sure you are installing Docker from the official repository, not from the default Debian repository.
sudo -E apt-cache policy docker-ce
# Install Docker
sudo -E apt-get -y install docker-ce
# If you would like to use Docker as a non-root user, you should now consider adding your user to the "docker" group with something like:
sudo usermod -aG docker "$(whoami)"

# Enable docker daemon proxy
if [ "$ENABLE_HTTP_PROXY" = "true" ]; then
sudo mkdir -p /etc/systemd/system/docker.service.d/
cat <<-EOF | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=$http_proxy"
Environment="HTTPS_PROXY=$http_proxy"
Environment="NO_PROXY=$no_proxy"
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
fi

# Disable docker daemon proxy
# sudo rm -rf /etc/systemd/system/docker.service.d/http-proxy.conf || true
# sudo rm -rf /etc/docker/daemon.json || true
# sudo systemctl daemon-reload
# sudo systemctl restart docker

sudo -E apt-get -y autoremove
sudo -E apt-get -y clean
# sudo -E apt-get -y purge --auto-remove xrdp
# sudo -E apt-get -y remove --auto-remove xrdp

# sudo systemctl list-units --all --state=failed

echo ""
echo "To complete the localdev setup please clone this git repos:"
echo ""
echo "git clone https://github.com/spuranam/ldev"
echo ""
echo "Please refer https://github.com/spuranam/ldev for documentation."
