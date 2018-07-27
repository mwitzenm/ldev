# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'fileutils'
require 'log4r/config'
require 'net/http'
require 'resolv'
require 'socket'
require 'uri'
require 'vagrant/ui'
require 'vagrant/util/downloader'
require 'vagrant/util/subprocess'
require 'vagrant/util/which'

LOCAL_DEV_VERSION            = '3.9.33-5'

SKIP_HTTP_PROXY              = ENV['SKIP_HTTP_PROXY'] || false
ENABLE_HTTP_PROXY            = ENV['ENABLE_HTTP_PROXY'] || false
OPENSHIFT_CONTAINERIZED      = ENV['OPENSHIFT_CONTAINERIZED'] || true
OPENSHIFT_USE_CALICO_SDN     = ENV['OPENSHIFT_USE_CALICO_SDN'] || true
OPENSHIFT_USE_TIGERA_CNX     = ENV['OPENSHIFT_USE_TIGERA_CNX'] || false
OPENSHIFT_DEPLOY_LOGGING     = ENV['OPENSHIFT_DEPLOY_LOGGING'] || true
OPENSHIFT_DEPLOY_MONITORING  = ENV['OPENSHIFT_DEPLOY_MONITORING'] || true
OPENSHIFT_USE_GIT_RELEASE    = ENV['OPENSHIFT_USE_GIT_RELEASE'] || true

ADDITIONAL_SYNCED_FOLDERS    = ENV['ADDITIONAL_SYNCED_FOLDERS'] || ''

# Minimum version of vagrant required
MIN_VAGRANT_VERSION          = '2.1.0'

# Minimum version of virtualbox required
MIN_VIRTUALBOX_VERSION       = '5.2.12'

# CoreDNS version, https://coredns.io/
COREDNS_VERSION              = ENV['COREDNS_VERSION'] || '1.2.0'

# Windows service manager verion, https://nssm.cc/download
NSSM_VERSION                 = ENV['NSSM_VERSION'] || '2.24'

# kubectl version, https://nssm.cc/download
KUBECTL_VERSION              = ENV['KUBECTL_VERSION'] || '1.9.1'

# Specify the deployment type. Valid values are origin and openshift-enterprise.
OPENSHIFT_DEPLOYMENT_TYPE    = ENV['OPENSHIFT_DEPLOYMENT_TYPE'] || 'openshift-enterprise'

# This should match the git branch name
# for example:
#    https://github.com/openshift/origin/tree/release-3.9
#    yum --showduplicates list openshift-ansible
OPENSHIFT_RELEASE_MAJOR_VERSION    = ENV['OPENSHIFT_RELEASE_MAJOR_VERSION'] || '3.9'
if OPENSHIFT_DEPLOYMENT_TYPE == 'openshift-enterprise'
    OPENSHIFT_RELEASE_MINOR_VERSION    = ENV['OPENSHIFT_RELEASE_MINOR_VERSION'] || '33'
else
    OPENSHIFT_RELEASE_MINOR_VERSION    = ENV['OPENSHIFT_RELEASE_MINOR_VERSION'] || '0'
end

# oc verion, https://github.com/openshift/origin/releases
OC_VERSION                   = ENV['OC_VERSION'] || "#{OPENSHIFT_RELEASE_MAJOR_VERSION}.#{OPENSHIFT_RELEASE_MINOR_VERSION}"
OC_VERSION_GIT_BUILDID       = ENV['OC_VERSION_GIT_BUILDID'] || '191fece'

# openshift/origin git release version, https://github.com/openshift/origin
OPENSHIFT_RELEASE_GIT        = ENV['OPENSHIFT_RELEASE_GIT'] || "v#{OPENSHIFT_RELEASE_MAJOR_VERSION}.#{OPENSHIFT_RELEASE_MINOR_VERSION}"

# openshift/openshift-ansible git release https://github.com/openshift/openshift-ansible
OPENSHIFT_ANSIBLE_GIT_REL    = ENV['OPENSHIFT_ANSIBLE_GIT_REL'] || "release-#{OPENSHIFT_RELEASE_MAJOR_VERSION}"

# openshift/openshift-ansible git tag https://github.com/openshift/openshift-ansible
OPENSHIFT_ANSIBLE_GIT_TAG    = ENV['OPENSHIFT_ANSIBLE_GIT_TAG'] || 'v3.10.0-rc.0'

# Specify the generic release of OpenShift to install. This is used mainly just during installation, after which we
# rely on the version running on the first master. Works best for containerized installs where we can usually
# use this to lookup the latest exact version of the container images, which is the tag actually used to configure
# the cluster. For RPM installations we just verify the version detected in your configured repos matches this
# release.
OPENSHIFT_RELEASE            = ENV['OPENSHIFT_RELEASE'] || "v#{OPENSHIFT_RELEASE_MAJOR_VERSION}"

# Specify an exact rpm version to install or configure.
# WARNING: This value will be used for all hosts in RPM based environments, even those that have another version installed.
# This could potentially trigger an upgrade and downtime, so be careful with modifying this value after the cluster is set up.
# See, https://github.com/openshift/openshift-ansible/blob/release-3.9/inventory/hosts.example#L823
OPENSHIFT_PKG_VERSION        = ENV['OPENSHIFT_PKG_VERSION'] || "-#{OPENSHIFT_RELEASE_MAJOR_VERSION}.#{OPENSHIFT_RELEASE_MINOR_VERSION}"

# Specify an exact container image tag to install or configure.
# WARNING: This value will be used for all hosts in containerized environments, even those that have another version installed.
# This could potentially trigger an upgrade and downtime, so be careful with modifying this value after the cluster is set up.
OPENSHIFT_IMAGE_TAG          = ENV['OPENSHIFT_IMAGE_TAG'] || "v#{OPENSHIFT_RELEASE_MAJOR_VERSION}.#{OPENSHIFT_RELEASE_MINOR_VERSION}"

# https://docs.openshift.org/latest/install_config/configuring_sdn.html
# redhat/openshift-ovs-subnet (default) | redhat/openshift-ovs-multitenant | redhat/openshift-ovs-networkpolicy
OS_SDN_NETWORK_PLUGIN_NAME   = ENV['OS_SDN_NETWORK_PLUGIN_NAME'] || 'redhat/openshift-ovs-multitenant'
CALICO_IPV4POOL_IPIP         = ENV['CALICO_IPV4POOL_IPIP'] || 'never'
CALICO_URL_POLICY_CONTROLLER = ENV['CALICO_URL_POLICY_CONTROLLER'] || 'quay.io/calico/kube-controllers:v3.1.3'
CNX_NODE_IMAGE               = ENV['CNX_NODE_IMAGE'] || 'quay.io/tigera/cnx-node:v2.1.1'
CALICO_NODE_IMAGE            = ENV['CALICO_NODE_IMAGE'] || 'quay.io/calico/node:v3.1.3'
CALICO_CNI_IMAGE             = ENV['CALICO_CNI_IMAGE'] || 'quay.io/calico/cni:v3.1.3'
CALICO_UPGRADE_IMAGE         = ENV['CALICO_UPGRADE_IMAGE'] || 'quay.io/calico/upgrade:v1.0.5'
CALICO_ETCD_IMAGE            = ENV['CALICO_ETCD_IMAGE'] || 'quay.io/coreos/etcd:v3.2.5'

# master API and console ports
OPENSHIFT_API_PORT           = '8443'

# Localdev DNS top level domain name
OPENSHIFT_DOMAIN             = 'oc.local'

# Default username that's auto created at the cluster creation time
OPENSHIFT_USER_NAME          = 'admin'

# Password associated with default user account
OPENSHIFT_USER_PASSWD        = 'sandbox'

# Hostname, IP, FQDN of the OpenShift master VM
MASTER_HOSTNAME              = 'm1'
MASTER_IP                    = '172.17.4.101'
MASTER_IP_REVERSE            = MASTER_IP.split('.').reverse.join('.')
MASTER_FQDN                  = "#{MASTER_HOSTNAME}.#{OPENSHIFT_DOMAIN}"
MASTER_IP_REVERSE_OCTETS_1   = MASTER_IP.split('.').reverse.slice(0,1).join('.')
MASTER_IP_REVERSE_OCTETS_234 = MASTER_IP.split('.').reverse.slice(1,3).join('.')
OPENSHIFT_REVERSE_DOMAIN     = "#{MASTER_IP_REVERSE_OCTETS_234}.in-addr.arpa"

# Hostname, IP, FQDN of the OpenShift infra VM
INFRA_HOSTNAME               = 'i1'
INFRA_IP                     = '172.17.4.201'
INFRA_IP_REVERSE             = INFRA_IP.split('.').reverse.join('.')
INFRA_FQDN                   = "#{INFRA_HOSTNAME}.#{OPENSHIFT_DOMAIN}"
INFRA_IP_REVERSE_OCTETS_1    = INFRA_IP.split('.').reverse.slice(0,1).join('.')
INFRA_IP_REVERSE_OCTETS_234  = INFRA_IP.split('.').reverse.slice(1,3).join('.')

# https://docs.openshift.org/3.9/install_config/http_proxies.html#configuring-hosts-for-proxies
# https://docs.openshift.org/3.9/install_config/install/advanced_install.html#configuring-cluster-variables
# https://docs.openshift.org/latest/install_config/install/host_preparation.html#setting-global-proxy
OPENSHIFT_SDN_NETWORK_AND_SERVICE_IP_RANGES = '10.128.0.0/14, 172.30.0.0/16, 172.30.0.1'

DEFAULT_HTTP_PROXY           = ENV['DEFAULT_HTTP_PROXY']  || "http://mycorp.com:83"
DEFAULT_HTTPS_PROXY          = ENV['DEFAULT_HTTPS_PROXY'] || "http://mycorp.com:83"
DEFAULT_NO_PROXY             = ENV['DEFAULT_NO_PROXY']    || "127.0.0.1,localhost,.mycorp.com,.local,.svc,#{OPENSHIFT_SDN_NETWORK_AND_SERVICE_IP_RANGES},#{MASTER_IP},#{INFRA_IP}"

VM_STORAGE_DISK_SIZE_IN_GB   = ENV['VM_STORAGE_DISK_SIZE_IN_GB'] || 250
INFRA_VM_DISK_COUNT          = 1
MASTER_VM_DISK_COUNT         = 3
VBOX_DISK_CONTROLLER         = 'CaaSVboxSATA'

RHSM_ORG                     = ENV['RHSM_ORG'] || ''
RHSM_ACTIVATION_KEY          = ENV['RHSM_ACTIVATION_KEY'] || ''

CENTOS_BOX_URL               = ENV['CENTOS_BOX_URL'] || 'https://app.vagrantup.com/centos/boxes/7'
CENTOS_BOX_NAME              = ENV['CENTOS_BOX_NAME'] || 'centos/7'

RHEL_BOX_URL                 = ENV['RHEL_BOX_URL'] || 'https://app.vagrantup.com/generic/boxes/rhel7'
RHEL_BOX_NAME                = ENV['RHEL_BOX_NAME'] || 'generic/rhel7'

ENV['VAGRANT_NO_COLOR']      = 'true'
#ENV['VAGRANT_SERVER_URL']  = 'http://localhost:8099'

if Vagrant::Util::Platform.windows?
    #DEFAULT_USER_HOME = ENV['USERPROFILE'].gsub(/\\/,'/').gsub(/[[:alpha:]]{1}:/){|s|'/' + s.downcase.sub(':', '')}
    DEFAULT_USER_HOME = ENV['USERPROFILE']
else
    DEFAULT_USER_HOME = ENV['HOME']
end

TRUTHY_VALUES = [true, 1, '1', 't', 'T', 'true', 'TRUE', 'y', 'Y', 'yes', 'YES']

FALSY_VALUES = [false, 0, '0', 'f', 'F', 'false', 'FALSE', 'n', 'N', 'no', 'NO']

required_plugins = %w() #vagrant-sshfs

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION    = '2'

def calculate_resource_allocation
    cpus = ENV['VM_CORES'] ? ENV['VM_CORES'].to_i : nil
    memory = ENV['VM_MEMORY'] ? ENV['VM_MEMORY'].to_i : nil

    # Compute installed Memory in MB & Number of logical CPUs
    case RUBY_PLATFORM
    when /darwin/i
        sysctl_path = `which sysctl || echo /usr/sbin/sysctl`.chomp
        cpus ||= `#{sysctl_path} -n hw.ncpu`.to_i
        max_memory = `#{sysctl_path} -n hw.memsize`.to_i / 1024 / 1024
    when /linux/i
        cpus ||= `nproc`.to_i
        max_memory = `grep 'MemTotal' /proc/meminfo | sed -e 's/MemTotal://' -e 's/ kB//'`.to_i / 1024
    when /cygwin|mswin|mingw|bccwin|wince|emx/i
        cpus ||= `wmic computersystem get numberoflogicalprocessors`.split("\n")[2].to_i
        max_memory = `wmic OS get TotalVisibleMemorySize`.split("\n")[2].to_i / 1024
    else
        cpus ||= 4
        max_memory = 4096
    end

    infra_memory = 1024
    infra_cpus = 1

    master_memory = 2048
    master_cpus = 2

    # Assign max of 57% of total installed memory or 5120MB to master nodes
    # master_memory = [5120, ((max_memory * 0.72 * 0.80) - infra_memory) ].max.to_i

    # Assign max of 48% of total installed cpus or 2 vCPUs to worker nodes
    #master_cpus = [2, (cpus * 0.60 * 0.80)].max.to_i

    # Assign 50% of host memory to the guest
    master_memory = (max_memory * 0.50).to_i

    # Assign 50% of host cpu to the guest
    master_cpus = (cpus * 0.50).to_i

    {max_memory: max_memory, cpus: cpus, master_memory: master_memory, master_cpus: master_cpus, infra_memory: infra_memory, infra_cpus: infra_cpus}
end

class Module
    def redefine_const(name, value)
      __send__(:remove_const, name) if const_defined?(name)
      const_set(name, value)
    end
end

class String
    # colorization
    def colorize(color_code)
      "\e[#{color_code}m#{self}\e[0m"
    end

    def red
      colorize(31)
    end

    def green
      colorize(32)
    end

    def yellow
      colorize(33)
    end

    def blue
      colorize(34)
    end

    def pink
      colorize(35)
    end

    def light_blue
      colorize(36)
    end

    def to_bool
      return true   if self == true   || self =~ (/(true|t|yes|y|1)$/i)
      return false  if self == false  || self.blank? || self =~ (/(false|f|no|n|0)$/i)
      raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
    end
end

UI = Log4r::Logger.new("oc-localdev")
UI.add Log4r::Outputter.stdout
if ENV['VAGRANT_LOG'] && ENV['VAGRANT_LOG'] != ''
  Log4r.define_levels(*Log4r::Log4rConfig::LogLevels)
  level = Log4r.const_get(ENV['VAGRANT_LOG'].upcase)
  UI.level = level
end

class ValidationError < StandardError
    def initialize(list=[], msg="Validation Error")
      @list = list
      super(msg)
    end

    def list
      @list.dup
    end

    def publish
      UI.error 'Errors:'.red
      @list.each do |error|
        UI.error "  #{error}".red
      end
      exit 2
    end
end

Vagrant.require_version ">= #{MIN_VAGRANT_VERSION}"

UI.info "OpenShift localdev v#{LOCAL_DEV_VERSION}".yellow

if Vagrant::Util::Platform.windows?
    if not Vagrant::Util::Platform.windows_admin?
        UI.info "Please run vagrant as administrator, right click powershell and select 'Run as Administrator'".red
        exit(0)
    end
end

def redefine_constant(env_var)
    if ENV.has_key?(env_var)
        Object.redefine_const(eval(":#{env_var}"), true) if TRUTHY_VALUES.include? ENV[env_var]
    end
end

def fetch(uri_str, use_proxy = 'false', limit = 10)
    raise ArgumentError, 'HTTP redirect too deep' if limit == 0

    url = URI.parse(uri_str)
    req = Net::HTTP::Get.new(url.request_uri, { 'User-Agent' => 'Mozilla/5.0' })
    if use_proxy == 'true' then
        proxy_url = URI.parse(DEFAULT_HTTP_PROXY)
        ## TODO: Authenticated proxy
        # response = Net::HTTP.start(url.host, url.port, proxy_url.host, proxy_url.port, 'proxy_user', 'proxy_pass') { |http| http.request(req) }
        response = Net::HTTP.start(url.host, url.port, proxy_url.host, proxy_url.port) { |http| http.request(req) }
    else
        response = Net::HTTP.start(url.host, url.port) { |http| http.request(req) }
    end
    case response
    when Net::HTTPSuccess     then response
    when Net::HTTPRedirection then fetch(response['location'], limit - 1)
    else
      response.error!
    end
end

def traverse_http_proxy?
    if fetch('http://google.com/').kind_of? Net::HTTPSuccess then
        return false
    elsif fetch('http://google.com/', 'true').kind_of? Net::HTTPSuccess
        return true
    end
end

def on_corporate_network?
    addr_infos = Socket.ip_address_list
    ip_addr = nil
    addr_infos.each do |addr_info|
        return true if addr_info.ip_address.start_with?('136.') or addr_info.ip_address.start_with?('19.')
    end
    return false
end

def first_private_ipv4
    Socket.ip_address_list.detect{|intf| intf.ipv4? and !intf.ipv4_loopback? and !intf.ipv4_multicast? and intf.ipv4_private?}
end

def first_public_ipv4
    Socket.ip_address_list.detect{|intf| intf.ipv4? and !intf.ipv4_loopback? and !intf.ipv4_multicast? and !intf.ipv4_private?}
end

if !SKIP_HTTP_PROXY then
    if on_corporate_network? or ENABLE_HTTP_PROXY then
        Object.redefine_const(:ENABLE_HTTP_PROXY, true)
        # These environment variables only exists in the context of vagrant process only.
        # These are required so that vagrant download plugins, coredns, ct, and nssm from public internet
        ENV['http_proxy']  = DEFAULT_HTTP_PROXY
        ENV['https_proxy'] = DEFAULT_HTTPS_PROXY
        ENV['no_proxy']    = DEFAULT_NO_PROXY
        ENV['HTTP_PROXY']  = DEFAULT_HTTP_PROXY
        ENV['HTTPS_PROXY'] = DEFAULT_HTTPS_PROXY
        ENV['NO_PROXY']    = DEFAULT_NO_PROXY
    end
end

if Vagrant::Util::Platform.windows? and OPENSHIFT_DEPLOYMENT_TYPE == 'origin'
    required_plugins.push('vagrant-winnfsd')
end

plugins_to_install = required_plugins.select { |plugin| not Vagrant.has_plugin? plugin }
if not plugins_to_install.empty?
    UI.info "Installing plugins: #{plugins_to_install.join(' ')}".yellow
    # vagrant plugin install <SPACE_DELIMETED_PLUGIN_NAMES> --plugin-source http://rubygems.org
    # vagrant plugin install <SPACE_DELIMETED_PLUGIN_NAMES> --plugin-source file://fully/qualified/path/vagrant-proxyconf-1.4.0.gem
    if system "vagrant plugin install #{plugins_to_install.join(' ')}"
        # Call the vagrant again the with original arguments
        exec "vagrant #{ARGV.join(' ')}"
    else
        abort "Installation of one or more plugins has failed. Aborting."
    end
end

def validate_download(path, sha256Expected)
    UI.info "Validating Installer Checksum..."
    sha256 = Digest::SHA256.file(path).hexdigest
    unless sha256Expected == sha256
    errorMsg = "Installer Checksum (SHA256) Mismatch - expected: '#{sha256Expected}'; found: '#{sha256}'"
    UI.warn errorMsg
    raise ValidationError, [errorMsg]
    end
end

def download_file(name, version, url, path, sha256Expected)
    UI.info "HTTP Proxy: #{ENV['http_proxy']}" if ENV.has_key?('http_proxy')
    UI.info "Downloading #{name} v#{version} ...".yellow
    UI.info "Source: #{url}"
    UI.info "Destination: #{path}"

    options = {}
    if ENV.has_key?('CURL_CA_BUNDLE')
        # https://github.com/hashicorp/vagrant/blob/master/lib/vagrant/util/downloader.rb#L58
        options[:ca_cert] = ENV.fetch('CURL_CA_BUNDLE')
    end

    options[:ui] = Vagrant::UI::Colored.new
    dl = Vagrant::Util::Downloader.new(url, path, options)

    retriesMax = 3
    retries = 0
    errorMsgs = []
    begin
        File.delete(path) if File.file?(path)
        dl.download!

        if !sha256Expected.nil? && !sha256Expected.empty? then
            validate_download(path, sha256Expected)
        end

        rescue ValidationError => e
        errorMsgs += e.list
        retry if (retries += 1) < retriesMax
        errorMsgs += ["Maximum download retries exceeded: #{retriesMax}"]
        raise ValidationError, errorMsgs
    end
end

def virtualbox_version()
    vboxmanage = Vagrant::Util::Which.which("VBoxManage") || Vagrant::Util::Which.which("VBoxManage.exe")
    if vboxmanage != nil
        s = Vagrant::Util::Subprocess.execute(vboxmanage, '--version')
        return s.stdout.strip!.split("r")[0]
    else
        return nil
    end
end

#if Gem::Version.new(virtualbox_version) < Gem::Version.new(MIN_VIRTUALBOX_VERSION)
#    UI.info "Please install VirtualBox >= v#{MIN_VIRTUALBOX_VERSION}".red
#    exit(0)
#end

VAGRANT_FILE_PATH        = File.dirname(__FILE__)
TEMPLATE_PATH            = File.join(VAGRANT_FILE_PATH,'templates')
CACHE_PATH               = File.join(VAGRANT_FILE_PATH,'cache')
ARTIFACT_PATH            = File.join(VAGRANT_FILE_PATH,'artifacts')
PROVISION_LOGDIR         = File.join(ARTIFACT_PATH,'logs')
PROVISION_LOGFILE        = ENV['PROVISION_LOGFILE'] || "/home/vagrant/share/artifacts/logs/provision_#{Time.now.strftime("%Y-%m-%d")}.log"
DEFAULT_NAMESERVERS      = Resolv::DNS::Config.new.lazy_initialize.nameserver_port.map{|n| n[0]}
INVENTORY_FILE_PATH      = ENV['INVENTORY_FILE_PATH'] || "#{TEMPLATE_PATH}/openshift/inventory.ini"

# The interface on which CoreDNS would listen on the host should be
# reachable from within the localdev VM. To that end this code make every effort
# find a suitable host interface IP. Here are various scenarios that we need to handle:
# 1. Client is on corporate network - get first 19.x host IP
# 2. Client is not on corporate network - get first RFC 1918 address
# 3. Client is connected to corporate network via VPN - get first RFC 1918 address
#######################################################################
# NOTE:
#######################################################################
# While this algorithm is not perfect i.e. i am making a huge assumption that while client
# is either on corporate network or is not, however we have an escape hatch in the form of
# environment varibale 'DEFAULT_HOST_IP' if set we will trust the user and move on.
vbox_host_network = MASTER_IP.split('.').slice(0,3).join('.')

all_host_ips = Socket.ip_address_list.select{|intf| intf.ipv4? and !intf.ipv4_loopback? and !intf.ipv4_multicast?}.collect(&:ip_address)
public_ips = all_host_ips.delete_if{|i| i.start_with?(vbox_host_network)}.grep(/19\./)

private_host_ips = Socket.ip_address_list.select{|intf| intf.ipv4? and !intf.ipv4_loopback? and !intf.ipv4_multicast? and intf.ipv4_private?}.collect(&:ip_address)
private_ips = private_host_ips.delete_if{|i| i.start_with?(vbox_host_network)}

if ENV.has_key?('DEFAULT_HOST_IP') and not ENV['DEFAULT_HOST_IP'].strip.empty?
    DEFAULT_HOST_IP = ENV['DEFAULT_HOST_IP'].strip
elsif !public_ips.empty?
    DEFAULT_HOST_IP = public_ips[0]
elsif !private_ips.empty?
    DEFAULT_HOST_IP = private_ips[0]
else
    UI.info "Unable to determine host ip address".red
    exit(0)
end

redefine_constant('SKIP_HTTP_PROXY')
redefine_constant('ENABLE_HTTP_PROXY')
redefine_constant('OPENSHIFT_CONTAINERIZED')
redefine_constant('OPENSHIFT_USE_CALICO_SDN')
redefine_constant('OPENSHIFT_USE_TIGERA_CNX')
redefine_constant('OPENSHIFT_ENABLE_ADDONS')
redefine_constant('OPENSHIFT_DEPLOY_LOGGING')
redefine_constant('OPENSHIFT_DEPLOY_MONITORING')
redefine_constant('OPENSHIFT_USE_GIT_RELEASE')

if MASTER_VM_DISK_COUNT < 3
    UI.info "Please increase the addtional storage disk on master to #{MASTER_VM_DISK_COUNT} or more".red
    exit(0)
end

######################################################################
# suspend localdev
######################################################################
if ARGV[0] == 'suspend'
    UI.info 'Stopping CoreDNS service'.yellow
    UI.info 'You might be prompted for admin password for your local system'.pink
    if Vagrant::Util::Platform.darwin?
        system "sudo launchctl unload #{ARTIFACT_PATH}/coredns/coredns.plist"
    elsif Vagrant::Util::Platform.linux?
        system "sudo systemctl stop coredns.service"

        UI.info "Updating the local DNS setting".yellow
        update_dns_servers = <<~BASH
            if [ -f /etc/resolvconf/resolv.conf.d/head.original ]; then
                sudo mv /etc/resolvconf/resolv.conf.d/head.original /etc/resolvconf/resolv.conf.d/head
            else
                sudo bash -c 'echo "" > /etc/resolvconf/resolv.conf.d/head'
            fi
            sudo resolvconf -u
            sudo service resolvconf restart
        BASH
        system update_dns_servers
    elsif Vagrant::Util::Platform.windows?
        nssmBin = "#{ARTIFACT_PATH}/bin/nssm.exe".gsub('/', '\\')
        system "#{nssmBin} stop coredns"

        DEFAULT_NAMESERVERS.delete("127.0.0.1")
        ns = DEFAULT_NAMESERVERS.map{|s| "'#{s}'"}.compact.join(',')
        reset_nic = <<~POWERSHELL
            $newDNSServers = #{ns}
            # $adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { ($_.DNSServerSearchOrder -ne $null) -and ($_.IPAddress -ne $null) -and ($_.IpEnabled -eq $true) -and ($_.DHCPEnabled -eq $true) }
            $adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { ($_.DNSServerSearchOrder -ne $null) -and ($_.IPAddress -ne $null) -and ($_.IpEnabled -eq $true) }
            $adapters | ForEach-Object {$_.SetDNSServerSearchOrder($newDNSServers)}
            $adapters | Get-NetAdapter | Restart-NetAdapter
        POWERSHELL

        c = [
            "powershell",
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy", "Bypass",
            "-Command",
            reset_nic
            ].flatten

        result = Vagrant::Util::Subprocess.execute(*c)
        if result.exit_code != 0
            UI.info "#{result.stdout}, #{result.stderr}".red
            exit
        end
    end
end

######################################################################
# resume localdev
######################################################################
if ARGV[0] == 'resume'
    UI.info 'Starting CoreDNS service'.yellow
    UI.info 'You might be prompted for admin password for your local system'.pink
    if Vagrant::Util::Platform.darwin?
        system "sudo launchctl load #{ARTIFACT_PATH}/coredns/coredns.plist"
    elsif Vagrant::Util::Platform.linux?
        system "sudo systemctl reload-or-restart coredns.service"
        # squint hard, you can barely notice it `~` without it output with leading spaces.
        UI.info "Updating the local DNS setting".yellow
        update_dns_servers = <<~BASH
            sudo mv /etc/resolvconf/resolv.conf.d/head.original /etc/resolvconf/resolv.conf.d/head
            sudo bash -c 'echo "nameserver 127.0.0.1" > /etc/resolvconf/resolv.conf.d/head'
            sudo resolvconf -u
            sudo service resolvconf restart
        BASH
        system update_dns_servers
    elsif Vagrant::Util::Platform.windows?
        nssmBin = "#{ARTIFACT_PATH}/bin/nssm.exe".gsub('/', '\\')
        system "#{nssmBin} start coredns"

        DEFAULT_NAMESERVERS.delete("127.0.0.1")
        # create copy of original array
        nameservers = DEFAULT_NAMESERVERS.inject([]) { |a,element| a << element.dup }
        nameservers.unshift '127.0.0.1'
        ns = nameservers.map{|s| "'#{s}'"}.compact.join(',')

        update_dns_servers = <<~POWERSHELL
            # Disable IPv6 across all interfaces
            #Get-NetAdapter | Select-Object name | Disable-NetAdapterBinding –ComponentID ms_tcpip6
            Get-NetAdapterBinding | Where-Object {($_.ElementName -eq 'ms_tcpip6') -and ($_.Enabled -eq $True)} | Disable-NetAdapterBinding -ComponentID ms_tcpip6
            # Update DNSSearchOrder
            $newDNSServers = #{ns}
            $adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { ($_.DNSServerSearchOrder -ne $null) -and ($_.IPAddress -ne $null) -and ($_.IpEnabled -eq $true) }
            $adapters | ForEach-Object {$_.SetDNSServerSearchOrder($newDNSServers)}
        POWERSHELL

        c = [
            "powershell",
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy", "Bypass",
            "-Command",
            update_dns_servers
            ].flatten

        result = Vagrant::Util::Subprocess.execute(*c)
        if result.exit_code != 0
            UI.info "#{result.stdout}, #{result.stderr}".red
            exit
        end
    end

    # Check if we are able to resolve "m1.oc.local" domain
    begin
        ldev_master_ip = Socket::getaddrinfo(MASTER_FQDN, 'echo', Socket::AF_INET)[0][3]
    rescue
        ldev_master_ip = ""
    end

    if ldev_master_ip.strip.empty? or ldev_master_ip != MASTER_IP then
        UI.info "Unable to #{MASTER_FQDN} to #{MASTER_IP}, ensure that coreDNS service is running".red
        exit(0)
    end
end

######################################################################
# install tools & download offline image cache
######################################################################
if ARGV[0] == 'up'

    ######################################################################
    # Create log dir if its missing
    ######################################################################
    FileUtils.mkdir_p PROVISION_LOGDIR unless Dir.exist?(PROVISION_LOGDIR)

    ######################################################################
    # Download, and install CoreDNS
    ######################################################################
    url = "https://github.com/coredns/coredns/releases/download/v#{COREDNS_VERSION}/coredns_#{COREDNS_VERSION}"
    downloadPath = File.expand_path("#{ARTIFACT_PATH}/bin/coredns.tgz")
    if Vagrant::Util::Platform.windows?
        url = "#{url}_windows_amd64.tgz"
        installPath = File.expand_path("#{ARTIFACT_PATH}/bin/coredns.exe")
    elsif Vagrant::Util::Platform.darwin?
        url = "#{url}_darwin_amd64.tgz"
        installPath = File.expand_path("#{ARTIFACT_PATH}/bin/coredns")
    elsif Vagrant::Util::Platform.linux?
        url = "#{url}_linux_amd64.tgz"
        installPath = File.expand_path("#{ARTIFACT_PATH}/bin/coredns")
    end
    sha256Expected = nil
    if File.exists?(installPath)
        version = Vagrant::Util::Subprocess.execute("#{installPath}", "-version")
        FileUtils.rm(installPath) if not version.stdout.chomp.include?(COREDNS_VERSION)
    end
    FileUtils.mkdir_p Pathname.new(installPath).dirname unless Dir.exist?(Pathname.new(installPath).dirname)
    download_file('coredns', COREDNS_VERSION, url, downloadPath, sha256Expected) unless File.exists?(installPath)
    if Vagrant::Util::Platform.darwin? or Vagrant::Util::Platform.linux? and File.exists?(downloadPath)
        install_tool = <<~BASH
            #!/bin/bash
            tar -zxvf #{downloadPath} -C #{Pathname.new(installPath).dirname} > /dev/null 2>&1
            chmod +x #{installPath}
            rm -f #{downloadPath}
        BASH
        result = Vagrant::Util::Subprocess.execute("/bin/sh", "-c", install_tool)
        puts "#{result.stdout.chomp}"
        if result.exit_code != 0
            UI.info "Following errors occured: \n\tSTDOUT:#{result.stdout}\n\tSTDERR:#{result.stderr}".red
            exit(0)
        end
    elsif Vagrant::Util::Platform.windows? and File.exists?(downloadPath)
        # vagrant = Vagrant::Util::Which.which("vagrant")
        # unless vagrant
        #     raise 'vagrant not found in path'
        # end
        tarfile = File.join(ARTIFACT_PATH, 'bin', File.basename(downloadPath,".*")).concat('.tar')
        system "7z -y x #{downloadPath} -o#{Pathname.new(installPath).dirname} > nul" if not File.exists?(installPath)
        system "7z -y x #{tarfile} -o#{Pathname.new(installPath).dirname} > nul" if not File.exists?(installPath)
        FileUtils.mv("#{Pathname.new(installPath).dirname}/coredns", installPath)
        FileUtils.rm(tarfile)
        FileUtils.rm(downloadPath)
    end

    ######################################################################
    # Download nssm
    ######################################################################
    if Vagrant::Util::Platform.windows?
        version = NSSM_VERSION
        url = "https://nssm.cc/release/nssm-#{NSSM_VERSION}.zip"
        downloadPath = File.expand_path("#{ARTIFACT_PATH}/bin/nssm-#{NSSM_VERSION}.zip")
        installPath = File.expand_path("#{ARTIFACT_PATH}/bin/nssm.exe")
        sha256Expected = nil
        FileUtils.mkdir_p Pathname.new(installPath).dirname unless Dir.exist?(Pathname.new(installPath).dirname)
        download_file('nssm', NSSM_VERSION, url, downloadPath, sha256Expected) if not File.exists?(installPath)
        system "7z -y e #{downloadPath} nssm-#{NSSM_VERSION}\\win64\\nssm.exe -o#{Pathname.new(installPath).dirname} > nul" if not File.exists?(installPath)
        FileUtils.rm(downloadPath) if File.exists?(downloadPath)
    end

    ######################################################################
    # Download and install kubectl
    ######################################################################
    url = "https://storage.googleapis.com/kubernetes-release/release/v#{KUBECTL_VERSION}"
    installPath = File.expand_path("#{ARTIFACT_PATH}/bin/kubectl")
    if Vagrant::Util::Platform.windows?
        url = "#{url}/bin/windows/amd64/kubectl.exe"
        installPath = File.expand_path("#{ARTIFACT_PATH}/bin/kubectl.exe")
    elsif Vagrant::Util::Platform.darwin?
        url = "#{url}/bin/darwin/amd64/kubectl"
    elsif Vagrant::Util::Platform.linux?
        url = "#{url}/bin/linux/amd64/kubectl"
    end
    sha256Expected = nil
    FileUtils.mkdir_p Pathname.new(installPath).dirname unless Dir.exist?(Pathname.new(installPath).dirname)
    #if File.exists?(installPath)
    #    version = Vagrant::Util::Subprocess.execute("#{installPath}", "version", "--short", "--client")
    #    puts "kubectl version is #{version}"
    #    FileUtils.rm(installPath) if not version.stdout.chomp.include?(KUBECTL_VERSION)
    #end
    #download_file('kubectl', KUBECTL_VERSION, url, installPath, sha256Expected) unless File.exists?(installPath)
    if Vagrant::Util::Platform.darwin? or Vagrant::Util::Platform.linux?
        install_tool = <<~BASH
            #!/bin/bash

            set -o errexit
            set -o nounset
            set -o pipefail

            if [ -f #{installPath} ]; then
                installed_kubectl=$(#{installPath} version --short --client | cut -d ':' -f 2 | cut -d 'v' -f 2)
                echo "Found kubectl v#{KUBECTL_VERSION} at #{installPath} .."
                if [[ "${installed_kubectl}" != "#{KUBECTL_VERSION}" ]]; then
                    rm -rf #{installPath}
                fi
            fi

            if [ ! -f #{installPath} ]; then
                echo "Downloading kubectl v#{KUBECTL_VERSION} from #{url}"
                curl \
                    --connect-timeout 20 \
                    --retry 5 \
                    --retry-delay 0 \
                    --retry-max-time 660 \
                    --insecure \
                    --progress-bar \
                    --fail \
                    --location \
                    --show-error \
                    --output #{installPath} \
                    #{url}
                chmod +x #{installPath}
            fi
        BASH
        result = Vagrant::Util::Subprocess.execute("/bin/sh", "-c", install_tool)
        puts "#{result.stdout.chomp}"
        if result.exit_code != 0
            UI.info "Following errors occured: \n\tSTDOUT:#{result.stdout}\n\tSTDERR:#{result.stderr}".red
            exit(0)
        end
    elsif Vagrant::Util::Platform.windows? and File.exists?(downloadPath)
        install_kubectl = <<~POWERSHELL
            if ( Test-Path #{installPath} ) {
                $installed_kubectl=$(#{installPath} version --short --client 2> $null)
                if ( -not ($installed_kubectl -match "v#{KUBECTL_VERSION}") ) {
                    Remove-Item -Path #{installPath} -Force
                }
            }

            if ( -not Test-Path #{installPath} ) {
                (New-Object System.Net.WebClient).DownloadFile(#{url}, #{installPath})
            }
        POWERSHELL

        c = [
           "powershell",
           "-NoLogo",
           "-NoProfile",
           "-NonInteractive",
           "-ExecutionPolicy", "Bypass",
           "-Command",
           install_kubectl
           ].flatten

        result = Vagrant::Util::Subprocess.execute(*c)
        if result.exit_code != 0
           # UI.info "#{result.stdout}, #{result.stderr}".red
           UI.info "Following errors occured: \n\tSTDOUT:#{result.stdout}\n\tSTDERR:#{result.stderr}".red
           exit
        end
    end

    ######################################################################
    # Configure and start CoreDNS service
    ######################################################################
    #MASTER_IP_REVERSE_OCTETS_12, MASTER_IP_REVERSE_OCTETS_34 = MASTER_IP.split('.').reverse.each_slice(2).to_a
    #INFRA_IP_REVERSE_OCTETS_12, INFRA_IP_REVERSE_OCTETS_34 = INFRA_IP.split('.').reverse.each_slice(2).to_a

    COREDNS_ZONE_DIR = "#{ARTIFACT_PATH}/coredns/zones"
    CLUSTER_ZONEFILE = File.join(COREDNS_ZONE_DIR,"db.#{OPENSHIFT_DOMAIN}")
    CLUSTER_REVERSE_ZONEFILE = File.join(COREDNS_ZONE_DIR,"db.#{MASTER_IP_REVERSE_OCTETS_234}")

    UI.info "Writing CoreDNS Corefile".yellow
    FileUtils::mkdir_p COREDNS_ZONE_DIR unless File.directory?(COREDNS_ZONE_DIR)
    upstream_dns_servers = DEFAULT_NAMESERVERS.map{|s| "#{s}:53" if not s=='127.0.0.1'}.compact.join(' ')
    data = File.read("#{TEMPLATE_PATH}/coredns/corefile")
    if Vagrant::Util::Platform.darwin? or Vagrant::Util::Platform.linux?
        data = data.gsub("{{CLUSTER_ZONEFILE}}", CLUSTER_ZONEFILE)
        data = data.gsub("{{CLUSTER_REVERSE_ZONEFILE}}", CLUSTER_REVERSE_ZONEFILE)
    elsif Vagrant::Util::Platform.windows?
        data = data.gsub("{{CLUSTER_ZONEFILE}}", CLUSTER_ZONEFILE.gsub('/', '\\'))
        data = data.gsub("{{CLUSTER_REVERSE_ZONEFILE}}", CLUSTER_REVERSE_ZONEFILE.gsub('/', '\\'))
    end
    data = data.gsub("{{OPENSHIFT_DOMAIN}}", OPENSHIFT_DOMAIN)
    data = data.gsub("{{UPSTREAM_DNS_SERVERS}}", upstream_dns_servers)
    data = data.gsub("{{MASTER_IP}}", MASTER_IP)
    data = data.gsub("{{MASTER_IP_REVERSE}}", MASTER_IP_REVERSE)
    data = data.gsub("{{INFRA_IP}}", INFRA_IP)
    data = data.gsub("{{INFRA_IP_REVERSE}}", INFRA_IP_REVERSE)
    data = data.gsub("{{OPENSHIFT_REVERSE_DOMAIN}}", OPENSHIFT_REVERSE_DOMAIN)
    coredns_corefile = File.new("#{ARTIFACT_PATH}/coredns/Corefile", "wb")
    coredns_corefile.syswrite(data)
    coredns_corefile.close


    UI.info "Writing CoreDNS zonefile".yellow
    data = File.read("#{TEMPLATE_PATH}/coredns/zonefile")
    data = data.gsub("{{OPENSHIFT_DOMAIN}}", OPENSHIFT_DOMAIN)
    data = data.gsub("{{MASTER_IP}}", MASTER_IP)
    data = data.gsub("{{MASTER_IP_REVERSE}}", MASTER_IP_REVERSE)
    data = data.gsub("{{MASTER_HOSTNAME}}", MASTER_HOSTNAME)
    data = data.gsub("{{INFRA_IP}}", INFRA_IP)
    data = data.gsub("{{INFRA_IP_REVERSE}}", INFRA_IP_REVERSE)
    data = data.gsub("{{INFRA_HOSTNAME}}", INFRA_HOSTNAME)
    coredns_zonefile = File.new(CLUSTER_ZONEFILE, "wb")
    coredns_zonefile.syswrite(data)
    coredns_zonefile.close


    UI.info "Writing CoreDNS reverse zonefile".yellow
    data = File.read("#{TEMPLATE_PATH}/coredns/zonefile.reverse")
    data = data.gsub("{{OPENSHIFT_DOMAIN}}", OPENSHIFT_DOMAIN)
    data = data.gsub("{{OPENSHIFT_REVERSE_DOMAIN}}", OPENSHIFT_REVERSE_DOMAIN)
    data = data.gsub("{{MASTER_IP}}", MASTER_IP)
    data = data.gsub("{{MASTER_IP_REVERSE}}", MASTER_IP_REVERSE)
    data = data.gsub("{{MASTER_IP_REVERSE_OCTETS_1}}", MASTER_IP_REVERSE_OCTETS_1)
    data = data.gsub("{{MASTER_HOSTNAME}}", MASTER_HOSTNAME)
    data = data.gsub("{{INFRA_IP}}", INFRA_IP)
    data = data.gsub("{{INFRA_IP_REVERSE}}", INFRA_IP_REVERSE)
    data = data.gsub("{{INFRA_IP_REVERSE_OCTETS_1}}", INFRA_IP_REVERSE_OCTETS_1)
    data = data.gsub("{{INFRA_HOSTNAME}}", INFRA_HOSTNAME)
    coredns_zonefile = File.new(CLUSTER_REVERSE_ZONEFILE, "wb")
    coredns_zonefile.syswrite(data)
    coredns_zonefile.close

    if Vagrant::Util::Platform.darwin?
        coredns_plist_path = "#{ARTIFACT_PATH}/coredns/coredns.plist"
        system "sudo rm -f #{coredns_plist_path}" if File.exists?(coredns_plist_path)
        FileUtils.rm_rf("#{ARTIFACT_PATH}/coredns/coredns.log") if File.exists?("#{ARTIFACT_PATH}/coredns/coredns.log")
        data = File.read("#{TEMPLATE_PATH}/coredns/coredns.plist")
        data = data.gsub("{{COREDNS_BIN}}", "#{ARTIFACT_PATH}/bin/coredns")
        data = data.gsub("{{COREFILE_PATH}}", "#{ARTIFACT_PATH}/coredns/Corefile")
        data = data.gsub("{{COREDNS_BIN_DIR}}", "#{ARTIFACT_PATH}/bin")
        data = data.gsub("{{COREDNS_LOG_FILE}}", "#{ARTIFACT_PATH}/coredns/coredns.log")
        coredns_plist = File.new(coredns_plist_path, "wb")
        coredns_plist.syswrite(data)
        coredns_plist.close
        UI.info 'Starting CoreDNS service'.yellow
        UI.info 'You might be prompted for admin password for your local system'.pink
        system "sudo chown root:wheel #{coredns_plist_path}"
        system "sudo chmod o-w #{coredns_plist_path}"
        system "sudo launchctl unload #{coredns_plist_path}"
        system "sudo launchctl load #{coredns_plist_path}"

        # squint hard, you can barely notice it `~` without it output with leading spaces.
        UI.info "Updating the local DNS setting".yellow
        update_dns_servers = <<~BASH
            if [ ! -d /etc/resolver ]; then
               sudo mkdir -p /etc/resolver
            fi
            # sudo mkdir -p /etc/resolver
            sudo tee /etc/resolver/#{OPENSHIFT_DOMAIN} > /dev/null <<EOF
            domain #{OPENSHIFT_DOMAIN}
            port 53
            nameserver 127.0.0.1
            search_order 1
            EOF
        BASH
        system update_dns_servers
        system "sudo killall -HUP mDNSResponder;sudo killall mDNSResponderHelper;sudo dscacheutil -flushcache > /dev/null 2>&1"

    elsif Vagrant::Util::Platform.linux?
        # Create coredns user account, this account is used in systemd unitfile
        create_coredns_user = <<~BASH
            if ! getent passwd coredns > /dev/null; then
                sudo adduser --system --disabled-password --disabled-login --home /var/lib/coredns \
                --quiet --force-badname --group coredns
            fi
        BASH
        system create_coredns_user

        # Render coredns systemd unitfile
        coredns_unitfile_path = "#{ARTIFACT_PATH}/coredns/coredns.service"
        system "sudo rm -f #{coredns_unitfile_path}" if File.exists?(coredns_unitfile_path)
        FileUtils.rm_rf("#{ARTIFACT_PATH}/coredns/coredns.log") if File.exists?("#{ARTIFACT_PATH}/coredns/coredns.log")
        data = File.read("#{TEMPLATE_PATH}/coredns/coredns.service")
        data = data.gsub("{{COREDNS_BIN}}", "#{ARTIFACT_PATH}/bin/coredns")
        data = data.gsub("{{COREFILE_PATH}}", "#{ARTIFACT_PATH}/coredns/Corefile")
        data = data.gsub("{{COREDNS_BIN_DIR}}", "#{ARTIFACT_PATH}/bin")
        # data = data.gsub("{{COREDNS_LOG_FILE}}", "#{ARTIFACT_PATH}/coredns/coredns.log")
        coredns_plist = File.new(coredns_unitfile_path, "wb")
        coredns_plist.syswrite(data)
        coredns_plist.close

        UI.info 'Starting CoreDNS service'.yellow
        UI.info 'You might be prompted for admin password for your local system'.pink
        system "sudo cp #{ARTIFACT_PATH}/coredns/coredns.service /etc/systemd/system/coredns.service"
        system "sudo chown root:root /etc/systemd/system/coredns.service"
        system "sudo systemctl reload coredns.service"
        system "sudo systemctl start coredns.service"

        # squint hard, you can barely notice it `~` without it output with leading spaces.
        UI.info "Updating the local DNS setting".yellow
        update_dns_servers = <<~BASH
            if [ ! -d /etc/resolvconf/resolv.conf.d ]; then
                sudo mkdir -p /etc/resolvconf/resolv.conf.d
            fi
            if [ -f /etc/resolvconf/resolv.conf.d/head ]; then
                sudo mv /etc/resolvconf/resolv.conf.d/head /etc/resolvconf/resolv.conf.d/head.original
            fi
            # sudo bash -c 'echo "nameserver 127.0.0.1" >> /etc/resolvconf/resolv.conf.d/head'
            sudo tee /etc/resolvconf/resolv.conf.d/head > /dev/null <<EOF
            nameserver 127.0.0.1
            EOF
            sudo resolvconf -u
            sudo service resolvconf restart
        BASH
        system update_dns_servers
    elsif Vagrant::Util::Platform.windows?
        # A space is required between an option and its value (for example, type= own.
        # If the space is omitted the operation will fail.
        # sc.exe create coredns binpath= "ntsd -d c:\windows\system32\NewServ.exe" displayname=CoreDNS type= own start= demand

        nssmBin = "#{ARTIFACT_PATH}/bin/nssm.exe".gsub('/', '\\')
        corednsBin = "#{ARTIFACT_PATH}/bin/coredns.exe".gsub('/', '\\')
        coreFile = "#{ARTIFACT_PATH}/coredns/Corefile".gsub('/', '\\')
        logFile = "#{ARTIFACT_PATH}/coredns/coredns.log".gsub('/', '\\')
        errlogFile = "#{ARTIFACT_PATH}/coredns/coredns.err.log".gsub('/', '\\')

        UI.info "Starting CoreDNS service".yellow
        windows_service = <<~WINSERVICE
            #{nssmBin} stop coredns
            #{nssmBin} remove coredns confirm
            #{nssmBin} install coredns #{corednsBin}
            #{nssmBin} set coredns DisplayName CoreDNS
            #{nssmBin} set coredns Description CoreDNS
            #{nssmBin} set coredns AppParameters \"-conf #{coreFile}\"
            #{nssmBin} set coredns Start SERVICE_DEMAND_START
            #{nssmBin} set coredns Type SERVICE_WIN32_OWN_PROCESS
            #{nssmBin} set coredns AppStdout #{logFile}
            #{nssmBin} set coredns AppStderr #{errlogFile}
            #{nssmBin} set coredns AppStdoutCreationDisposition 4
            #{nssmBin} set coredns AppStderrCreationDisposition 4
            #{nssmBin} set coredns AppRotateFiles 1
            #{nssmBin} set coredns AppRotateOnline 1
            # Rotate Logs Every 24 hours or 1 gb
            #{nssmBin} set coredns AppRotateSeconds 86400
            #{nssmBin} set coredns AppRotateBytes 1073741824
            #{nssmBin} start coredns
        WINSERVICE

        c = [
           "powershell",
           "-NoLogo",
           "-NoProfile",
           "-NonInteractive",
           "-ExecutionPolicy", "Bypass",
           "-Command",
           windows_service
           ].flatten

        result = Vagrant::Util::Subprocess.execute(*c)
        if result.exit_code != 0
           UI.info "#{result.stdout}, #{result.stderr}".red
           exit
        end

        UI.info "Updating the local DNS setting".yellow
        # Delete the loopback address if it already exists
        DEFAULT_NAMESERVERS.delete("127.0.0.1")

        # create copy of original array
        nameservers = DEFAULT_NAMESERVERS.inject([]) { |a,element| a << element.dup }
        nameservers.unshift '127.0.0.1'
        ns = nameservers.map{|s| "'#{s}'"}.compact.join(',')

        update_dns_servers = <<~POWERSHELL
            # Disable IPv6 across all interfaces
            #Get-NetAdapter | Select-Object name | Disable-NetAdapterBinding –ComponentID ms_tcpip6
            Get-NetAdapterBinding | Where-Object {($_.ElementName -eq 'ms_tcpip6') -and ($_.Enabled -eq $True)} | Disable-NetAdapterBinding -ComponentID ms_tcpip6

            # Update DNSSearchOrder
            $newDNSServers = #{ns}
            $adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { ($_.DNSServerSearchOrder -ne $null) -and ($_.IPAddress -ne $null) -and ($_.IpEnabled -eq $true) }
            $adapters | ForEach-Object {$_.SetDNSServerSearchOrder($newDNSServers)}
        POWERSHELL

        c = [
           "powershell",
           "-NoLogo",
           "-NoProfile",
           "-NonInteractive",
           "-ExecutionPolicy", "Bypass",
           "-Command",
           update_dns_servers
           ].flatten

        result = Vagrant::Util::Subprocess.execute(*c)
        if result.exit_code != 0
           UI.info "#{result.stdout}, #{result.stderr}".red
           exit
        end
    end

    # Check if we are able to resolve "m1.oc.local" domain
    begin
        ldev_master_ip = Socket::getaddrinfo(MASTER_FQDN, 'echo', Socket::AF_INET)[0][3]
    rescue
        ldev_master_ip = ""
    end

    if ldev_master_ip.strip.empty? or ldev_master_ip != MASTER_IP then
        UI.info "Unable to #{MASTER_FQDN} to #{MASTER_IP}, ensure that coreDNS service is running".red
        exit(0)
    end
end

######################################################################
# Cleanup
######################################################################
if ARGV[0] == 'destroy'
    if Vagrant::Util::Platform.darwin?
        coredns_plist_path = "#{ARTIFACT_PATH}/coredns/coredns.plist"
        UI.info 'Stopping CoreDNS service'.yellow
        UI.info 'You might be prompted for admin password for your local system'.pink
        system "sudo launchctl unload #{coredns_plist_path}"
        system "sudo rm -f /etc/resolver/#{OPENSHIFT_DOMAIN}"
        system "sudo killall -HUP mDNSResponder;sudo killall mDNSResponderHelper;sudo dscacheutil -flushcache > /dev/null 2>&1"
    elsif Vagrant::Util::Platform.linux?
        system "sudo systemctl stop coredns.service"

        UI.info "Updating the local DNS setting".yellow
        update_dns_servers = <<~BASH
            if [ -f /etc/resolvconf/resolv.conf.d/head.original ]; then
                sudo mv /etc/resolvconf/resolv.conf.d/head.original /etc/resolvconf/resolv.conf.d/head
            else
                sudo bash -c 'echo "" > /etc/resolvconf/resolv.conf.d/head'
            fi
            sudo resolvconf -u
            sudo service resolvconf restart
        BASH
        system update_dns_servers
    elsif Vagrant::Util::Platform.windows?
        nssmBin = "#{ARTIFACT_PATH}/bin/nssm.exe".gsub('/', '\\')
        system "#{nssmBin} stop coredns"
        system "#{nssmBin} remove coredns confirm"

        # Delete the loopback address if it already exists
        DEFAULT_NAMESERVERS.delete("127.0.0.1")

        # create copy of original array
        nameservers = DEFAULT_NAMESERVERS.inject([]) { |a,element| a << element.dup }
        ns = nameservers.map{|s| "'#{s}'"}.compact.join(',')

        reset_nic = <<~POWERSHELL
            $newDNSServers = #{ns}
            $adapters = Get-WmiObject Win32_NetworkAdapterConfiguration | Where-Object { ($_.DNSServerSearchOrder -ne $null) -and ($_.IPAddress -ne $null) -and ($_.IpEnabled -eq $true) }
            $adapters | ForEach-Object {$_.SetDNSServerSearchOrder($newDNSServers)}
            $adapters | Get-NetAdapter | Restart-NetAdapter
        POWERSHELL

        c = [
            "powershell",
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy", "Bypass",
            "-Command",
            reset_nic
            ].flatten

        result = Vagrant::Util::Subprocess.execute(*c)
        if result.exit_code != 0
            UI.info "#{result.stdout}, #{result.stderr}".red
            exit
        end
    end

    # Cleanup environment
    FileUtils.rm_rf("#{ARTIFACT_PATH}/coredns") if File.exists?("#{ARTIFACT_PATH}/coredns")
    FileUtils.rm_rf("#{ARTIFACT_PATH}/kube") if File.exists?("#{ARTIFACT_PATH}/kube")
    FileUtils.rm_rf(PROVISION_LOGDIR) if File.exists?(PROVISION_LOGDIR)
    #FileUtils.rm_rf("#{ARTIFACT_PATH}/bin")
    #FileUtils.rm_rf("#{ARTIFACT_PATH}")
end

resources = calculate_resource_allocation

if OPENSHIFT_DEPLOYMENT_TYPE == 'origin'
    VAGRANT_BOX_URL            = CENTOS_BOX_URL
    VAGRANT_BOX_NAME           = CENTOS_BOX_NAME
    VAGRANT_MACHINE_NAME       = 'openshift-origin'
elsif OPENSHIFT_DEPLOYMENT_TYPE == 'openshift-enterprise'
    VAGRANT_BOX_URL            = RHEL_BOX_URL
    VAGRANT_BOX_NAME           = RHEL_BOX_NAME
    VAGRANT_MACHINE_NAME       = 'openshift-enterprise'
end

if OPENSHIFT_DEPLOYMENT_TYPE == 'openshift-enterprise' and OPENSHIFT_USE_TIGERA_CNX
    Object.redefine_const(:CALICO_NODE_IMAGE, CNX_NODE_IMAGE)
end

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

    config.vm.provider :virtualbox do |v|
        # On VirtualBox, we don't have guest additions or a functional vboxsf
        # in CentOS, so tell Vagrant that so it can be smarter.
        v.check_guest_additions = false
        v.functional_vboxsf     = false
        if OPENSHIFT_DEPLOYMENT_TYPE == 'openshift-enterprise'
            v.check_guest_additions = true
            v.functional_vboxsf     = true
        end
        v.cpus                  = 1
        v.gui                   = false
    end

    config.ssh.insert_key = false      #always use Vagrant's insecure key
    config.vm.box_check_update = true  #automatically check for updates during any vagrant up
    config.vm.box = VAGRANT_BOX_NAME
    config.vm.box_url = VAGRANT_BOX_URL

    # https://github.com/dustymabe/vagrant-sshfs/issues/19
    # Mount the localdev root folder into guest vm at "/home/vagrant/share"
    # NOTE: CentOS 7 vagrant base box does not support nfs v4, hence we need to use nfs v3
    # config.vm.synced_folder ".", "/home/vagrant/share", type: 'sshfs', ssh_opts_append: "-o Compression=yes -o CompressionLevel=5", sshfs_opts_append: '-o auto_cache -o cache_timeout=115200 -o umask=000 -o uid=1000 -o gid=1000', disabled: false
    if OPENSHIFT_DEPLOYMENT_TYPE == 'origin'
        config.vm.synced_folder ".", "/home/vagrant/share", id: "share", :nfs => true, :nfs_version => 3, :mount_options => ['rw,udp,nolock,vers=3,fsc,noatime,actimeo=1']
    elsif OPENSHIFT_DEPLOYMENT_TYPE == 'openshift-enterprise'
        config.vm.synced_folder ".", "/home/vagrant/share", type: 'virtualbox', disabled: false
    end

    if not ADDITIONAL_SYNCED_FOLDERS.strip.empty?
        ADDITIONAL_SYNCED_FOLDERS.split(",").each do |folder|
            source, destination = folder.split(/=>|=/).map(&:strip)
            UI.info "Setting up host directory sharing:\n\tHost Directory:#{source}\n\tVM Directory:#{destination}".green
            if OPENSHIFT_DEPLOYMENT_TYPE == 'origin'
                config.vm.synced_folder source, destination, id: Pathname.new(source).basename, :nfs => true, :nfs_version => 3, :mount_options => ['rw,udp,nolock,vers=3,fsc,noatime,actimeo=1']
            elsif OPENSHIFT_DEPLOYMENT_TYPE == 'openshift-enterprise'
                config.vm.synced_folder source, destination, type: 'virtualbox', disabled: false
            end
        end
    end

    ## Generate Gluster storage drive names
    glusterfs_drives=[]
    (2..MASTER_VM_DISK_COUNT).each do |idx|
        glusterfs_drives.push("/dev/sd#{idx.to_s(26).each_char.map {|i| ('a'..'z').to_a[i.to_i(26)]}.join}")
    end

    provision_script = ""
    if !SKIP_HTTP_PROXY then
        if on_corporate_network? or ENABLE_HTTP_PROXY then
            provision_script = <<~HEREDOC
                export http_proxy='#{ENV['http_proxy']}'
                export https_proxy='#{ENV['https_proxy']}'
                export no_proxy='#{ENV['no_proxy']}'
                export HTTP_PROXY='#{ENV['HTTP_PROXY']}'
                export HTTPS_PROXY='#{ENV['HTTPS_PROXY']}'
                export NO_PROXY='#{ENV['NO_PROXY']}'
            HEREDOC
        end
    end

    provision_script = <<~HEREDOC
        #{provision_script}
        export OPENSHIFT_USE_CALICO_SDN='#{OPENSHIFT_USE_CALICO_SDN}'
        export OS_SDN_NETWORK_PLUGIN_NAME='#{OS_SDN_NETWORK_PLUGIN_NAME}'
        export CALICO_IPV4POOL_IPIP='#{CALICO_IPV4POOL_IPIP}'
        export CALICO_URL_POLICY_CONTROLLER='#{CALICO_URL_POLICY_CONTROLLER}'
        export OPENSHIFT_USE_TIGERA_CNX='#{OPENSHIFT_USE_TIGERA_CNX}'
        export CALICO_NODE_IMAGE='#{CALICO_NODE_IMAGE}'
        export CALICO_CNI_IMAGE='#{CALICO_CNI_IMAGE}'
        export CALICO_UPGRADE_IMAGE='#{CALICO_UPGRADE_IMAGE}'
        export CALICO_ETCD_IMAGE='#{CALICO_ETCD_IMAGE}'
        export PROVISION_LOGFILE='#{PROVISION_LOGFILE}'
        export OPENSHIFT_CONTAINERIZED='#{OPENSHIFT_CONTAINERIZED}'
        export OPENSHIFT_RELEASE_MAJOR_VERSION='#{OPENSHIFT_RELEASE_MAJOR_VERSION}'
        export OPENSHIFT_RELEASE_MINOR_VERSION='#{OPENSHIFT_RELEASE_MINOR_VERSION}'
        export OPENSHIFT_RELEASE='#{OPENSHIFT_RELEASE}'
        export OPENSHIFT_IMAGE_TAG='#{OPENSHIFT_IMAGE_TAG}'
        export RHSM_ORG='#{RHSM_ORG.strip}'
        export RHSM_ACTIVATION_KEY='#{RHSM_ACTIVATION_KEY.strip}'
        export OPENSHIFT_USE_GIT_RELEASE='#{OPENSHIFT_USE_GIT_RELEASE}'
        export OPENSHIFT_ANSIBLE_GIT_REL='#{OPENSHIFT_ANSIBLE_GIT_REL}'
        export OPENSHIFT_ANSIBLE_GIT_TAG='#{OPENSHIFT_ANSIBLE_GIT_TAG}'
        export OPENSHIFT_DEPLOY_LOGGING='#{OPENSHIFT_DEPLOY_LOGGING}'
        export OPENSHIFT_DEPLOY_MONITORING='#{OPENSHIFT_DEPLOY_MONITORING}'
        export DOCKER_DISK='/dev/sdb'
        export GLUSTERFS_DRIVES='"#{glusterfs_drives.join('", "')}"'

        export OPENSHIFT_DEPLOYMENT_TYPE='#{OPENSHIFT_DEPLOYMENT_TYPE}'
        export OPENSHIFT_DOMAIN='#{OPENSHIFT_DOMAIN}'
        export OPENSHIFT_API_PORT='#{OPENSHIFT_API_PORT}'
        export OPENSHIFT_USER_NAME='#{OPENSHIFT_USER_NAME}'
        export OPENSHIFT_USER_PASSWD='#{OPENSHIFT_USER_PASSWD}'
        export DEFAULT_HOST_IP='#{DEFAULT_HOST_IP}'
        export MASTER_HOSTNAME='#{MASTER_HOSTNAME}'
        export MASTER_IP='#{MASTER_IP}'
        export MASTER_FQDN='#{MASTER_FQDN}'
        export INFRA_HOSTNAME='#{INFRA_HOSTNAME}'
        export INFRA_IP='#{INFRA_IP}'
        export INFRA_FQDN='#{INFRA_FQDN}'
        export VAGRANT_FILE_PATH='#{VAGRANT_FILE_PATH}'
        export TEMPLATE_PATH='#{TEMPLATE_PATH}'
        export CACHE_PATH='#{CACHE_PATH}'
        export ARTIFACT_PATH='#{ARTIFACT_PATH}'

        export PATH="$PATH:/usr/local/bin:/usr/bin"

        currentscript="$0"

        # Function that is called when the script exits:
        function finish {
            echo "Securely shredding ${currentscript}"; shred -u ${currentscript};
        }

        chmod +x /home/vagrant/install-openshift.sh
        #/home/vagrant/install-openshift.sh 2>&1 | stdbuf -i0 -o0 -e0 tee -a ${PROVISION_LOGFILE}
        # Disable buffreing
        stdbuf -i0 -o0 -e0 /home/vagrant/install-openshift.sh 2>&1 | tee -a ${PROVISION_LOGFILE}

        # When your script is finished, exit with a call to the function, "finish":
        trap finish EXIT
    HEREDOC
    ######################################################################
    # Create and start openshift all-in-one node
    ######################################################################
    # See, https://www.vagrantup.com/docs/multi-machine/#specifying-a-primary-machine
    config.vm.define "#{VAGRANT_MACHINE_NAME}", primary: true do |master|
        master.vm.hostname = MASTER_FQDN

        master.vm.provider :virtualbox do |vb|
            vb.name    = VAGRANT_MACHINE_NAME
            vb.memory  = ENV['MASTER_VM_MEMORY'] || resources[:master_memory]
            vb.cpus    = ENV['MASTER_VM_CPUS']   || resources[:master_cpus]

            vb.customize ['modifyvm', :id, '--cableconnected1', 'on']
            # https://serverfault.com/a/453260
            # https://github.com/hashicorp/vagrant/issues/1313#issuecomment-343221070
            # https://github.com/mitchellh/vagrant/issues/1807
            # Manually configure DNS i.e. disable DHCP client configuration for NAT interface
            vb.auto_nat_dns_proxy = false
            # NAT proxy is flakey (times out frequently)
            vb.customize ['modifyvm', :id, '--natdnsproxy1', 'off']
            # Host DNS resolution required to support host proxies and faster global DNS resolution
            vb.customize ['modifyvm', :id, '--natdnshostresolver1', 'off']
            # Change the network card hardware for better performance
            #vb.customize ["modifyvm", :id, "--nictype1", "virtio-net"]
            # Assign unique mac address
            vb.customize ['modifyvm', :id, '--macaddress1', 'auto']
            # ioapic line is needed for multi-core systems
            vb.customize ["modifyvm", :id, "--ioapic", "on"]
            # Guest should sync time if more than 5s off host
            vb.customize ["guestproperty", "set", :id, "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold", 5000 ]
            vb.customize ["modifyvm", :id, "--clipboard", "bidirectional"]
            vb.customize ["modifyvm", :id, "--vram", 8]
            # --paravirtprovider none|default|legacy|minimal|hyperv|kvm: This setting specifies which
            # Paravirtualization interface to provide to the guest operating system.
            vb.customize ["modifyvm", :id, "--paravirtprovider", "default"]
            vb.customize ["modifyvm", :id, "--cpuexecutioncap", "100"]
            # Adding a SATA controller that allows 4 hard drives
            vb.customize ["storagectl", :id, "--name", VBOX_DISK_CONTROLLER, "--add", "sata", "--controller", "IntelAHCI", "--portcount", 4, "--hostiocache", "on"]

            (0..MASTER_VM_DISK_COUNT-1).each do |mdisk|
                master_file_to_disk = File.join(VAGRANT_FILE_PATH, "#{VAGRANT_MACHINE_NAME}_disk#{mdisk}.vdi")
                if Vagrant::Util::Platform.windows?
                    master_file_to_disk = master_file_to_disk.gsub('/', '\\')
                end
                unless File.exist?(master_file_to_disk)
                    if mdisk == 0
                        vb.customize ['createhd', '--filename', master_file_to_disk, '--size', 50 * 1024]
                    else
                        vb.customize ['createhd', '--filename', master_file_to_disk, '--size', VM_STORAGE_DISK_SIZE_IN_GB.to_i * 1024]
                    end
                    vb.customize ['storageattach', :id, '--storagectl', VBOX_DISK_CONTROLLER, '--port', mdisk, '--device', 0, '--type', 'hdd', '--medium', master_file_to_disk]
                end
            end
        end
        master.vm.network "private_network", ip: "#{MASTER_IP}"
        master.vm.synced_folder '.', '/vagrant', disabled: true
        if ARGV[0] == 'up'
            master.vm.provision :file, :source => "#{TEMPLATE_PATH}/openshift/install-openshift.sh", :destination => "/home/vagrant/install-openshift.sh"
            master.vm.provision :file, :source => "#{INVENTORY_FILE_PATH}", :destination => "/home/vagrant/inventory.ini.tmpl"
            master.vm.provision "shell", inline: provision_script, keep_color: false, run: "once", privileged: true
        end
    end

  end
