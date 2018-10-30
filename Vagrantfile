# -*- mode: ruby -*-

require "yaml"

class ::Hash
    def deep_merge(second)
        merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : Array === v1 && Array === v2 ? v1 | v2 : [:undefined, nil, :nil].include?(v2) ? v1 : v2 }
        self.merge(second.to_h, &merger)
    end
end

Vagrant.require_version ">= 2.1.5"

# workaround for https://app.vagrantup.com/boxes/ usage
# Vagrant::DEFAULT_SERVER_URL.replace('https://vagrantcloud.com')

pool = ENV["VAGRANT_MR_POOL"] || "10.250.0.0/16"
vip_pool = ENV["VAGRANT_MR_VIP_POOL"] || "10.10.0.0/24"

ENV["VAGRANT_DEFAULT_PROVIDER"] = "libvirt"
prefix = pool.gsub(/\.\d+\.\d+\/\d\d$/, "")

# Boxes with libvirt provider support:
box = ENV["VAGRANT_MR_BOX"] || "generic/ubuntu1604" 

user = ENV["USER"]
node_name_prefix = "#{user}"
node_name_suffix = ENV["VAGRANT_MR_NAME_SUFFIX"] || ""
node_name_prefix+= "-#{node_name_suffix}" if node_name_suffix != ""


num_racks = 2
base_as_number = (ENV["VAGRANT_MR_BASE_AS_NUMBER"] || "65000").to_i
public_subnet = (ENV["VAGRANT_MR_NETWORK_PUBLIC"] || prefix.to_s + ".254.0/24")

server_memory = (ENV["VAGRANT_MR_SERVER_MEMORY"] || "1024").to_i
server_cpus = (ENV["VAGRANT_MR_SERVER_CPUS"] || "1").to_i
server_node_name = "%s-server" % [node_name_prefix]
client_memory = (ENV["VAGRANT_MR_SERVER_MEMORY"] || "1024").to_i
client_cpus = (ENV["VAGRANT_MR_SERVER_CPUS"] || "1").to_i
client_node_name = "%s-client" % [node_name_prefix]
client_node_ipaddr = public_subnet.split(".")[0..2].join(".")+".253"
master_memory = (ENV["VAGRANT_MR_MASTER_MEMORY"] || "1024").to_i
master_cpus = (ENV["VAGRANT_MR_MASTER_CPUS"] || "1").to_i
master_node_name = "%s-000" % [node_name_prefix]
master_node_ipaddr = public_subnet.split(".")[0..2].join(".")+".254"

rack_subnets = ['', prefix.to_s + ".1.0/24", prefix.to_s + ".2.0/24"]
vagrant_cidr = prefix.to_s + ".0.0/24"
public_gateway = public_subnet.split(".")[0..2].join(".")+".1"
public_network_name = "mr_#{node_name_prefix}_public"

print("### ENV:\n" +
      "    number of racks: #{num_racks}\n"+
      "    master node MEM: #{master_memory}\n"+
      "    master node CPU: #{master_cpus}\n"+
      "    server node MEM: #{server_memory}\n"+
      "    server node CPU: #{server_cpus}\n"+
      "    client node MEM: #{client_memory}\n"+
      "    client node CPU: #{client_cpus}\n"+
      "     control subnet: #{vagrant_cidr}\n"+
      "      public subnet: #{public_subnet}\n"+
      "         VIP subnet: #{vip_pool}\n")


# Create SSH keys for future lab
system "bash scripts/ssh-keygen.sh"

# Create network_metadata for inventory
network_metadata = {
  'racks' => [{'as_number' => base_as_number.to_i, 'tor' => master_node_ipaddr}],  # racks numbered from '1'
  'nodes' => {
    master_node_name => {
      'ipaddr' => master_node_ipaddr,
      'node_roles' => ['master'],
      'rack_no'    => "0",
    },
  },
}
transit_subnet = (ENV["VAGRANT_MR_NETWORK_TRANSIT"] || "192.168.192")
router_if_shift = 1
(1..num_racks).each do |rack_no|
  network_metadata['racks'] << {
    'subnet' => rack_subnets[rack_no],
    'tor'    => rack_subnets[rack_no].split(".")[0..2].join(".")+".254",
    'phy_if' => "eth#{rack_no+router_if_shift}",
    'veth' => [
      "#{transit_subnet}.#{rack_no*4+1}",
      "#{transit_subnet}.#{rack_no*4+2}"
    ]
  }
end
network_metadata["nodes"][client_node_name] = {
  'ipaddr'     => [client_node_ipaddr],
  'node_roles' => ['general','client'],
  'rack_no'    => 0,
}
subnet1_part = rack_subnets[1].split(".")[0..2].join(".")
subnet2_part = rack_subnets[2].split(".")[0..2].join(".")
network_metadata["nodes"][server_node_name] = {
  'ipaddr'     => ["#{subnet1_part}.1","#{subnet2_part}.1"],
  'gateway'    => ["#{subnet1_part}.254","#{subnet2_part}.254"],
  'node_roles' => ['general','server'],
  'rack_no'    => 12,
}

File.open("tmp/network_metadata.yaml", "w") do |file|
  file.write(network_metadata.to_yaml)
end

# prepare ansible deployment facts for master and slave nodes
# This hash should be assembled before run any provisioners for prevent
# parallel provisioning race conditions
racks=["1","2"]
ansible_host_vars = {}
ansible_host_vars[client_node_name] = {
  "ansible_python_interpreter" => "/usr/bin/python3",
  "node_name"                  => client_node_name,
  "rack_iface"                 => "eth1",
  "public_gateway"             => public_gateway,
}
ansible_host_vars[server_node_name] = {
  "ansible_python_interpreter" => "/usr/bin/python3",
  "node_name"                  => server_node_name,
  "rack_iface"                 => "eth1",
  "rack_gateway"               => network_metadata['nodes'][server_node_name]['gateway'][0],
}
ansible_host_vars[master_node_name] = {
  "ansible_python_interpreter" => "/usr/bin/python3",
  "node_name"                  => "#{master_node_name}",
}

# Create the lab
Vagrant.configure("2") do |config|
  config.ssh.insert_key = false
  config.vm.box = box

  # This fake ansible provisioner required for creating inventory for
  # true ansible privisioner, which should be run outside Vagrant
  # due Vagrant used featured method to run Ansible with unwanted features.
  config.vm.provision :ansible, preserve_order: true do |a|
    a.become = true  # it's a sudo !!!
    a.playbook = "playbooks/fake.yaml"
    a.host_vars = ansible_host_vars
    a.verbose = true
    a.limit = "all"  # fake provisioner will be run
    a.groups = {
      "clients" => [client_node_name],
      "servers" => [server_node_name],
      "masters" => [master_node_name],
      "all:children" => ["masters", "clients", "servers"],
      "masters:vars" => {
        "virt_racks" => racks,
      },
      "all:vars" => {
        "master_node_name"   => master_node_name,
        "master_node_ipaddr" => master_node_ipaddr,    
        "vip_pool" => vip_pool,
      },
    }
  end

  # configure Master&router VM
  config.vm.define "#{master_node_name}", primary: true do |master_node|
    master_node.vm.hostname = "#{master_node_name}"
    # Libvirt provider settings
    master_node.vm.provider(:libvirt) do |domain|
      domain.uri = "qemu+unix:///system"
      domain.memory = master_memory
      domain.cpus = master_cpus
      domain.driver = "kvm"
      domain.host = "localhost"
      domain.connect_via_ssh = false
      domain.username = user
      domain.storage_pool_name = "default"
      domain.nic_model_type = "e1000"
      domain.management_network_name = "mr_#{node_name_prefix}_vagrant"
      domain.management_network_address = "#{vagrant_cidr}"
      domain.nested = true
      domain.cpu_mode = "host-passthrough"
      domain.volume_cache = "unsafe"
      domain.disk_bus = "virtio"
      # DISABLED: switched to new box which has 100G / partition
      #domain.storage :file, :type => "qcow2", :bus => "virtio", :size => "20G", :device => "vdb"
    end
    ### Networks and interfaces
    # "public" network with nat forwarding
    master_node.vm.network(:private_network,
      :ip => master_node_ipaddr,
      :libvirt__host_ip => public_gateway,
      :model_type => "e1000",
      :libvirt__network_name => "mr_#{node_name_prefix}_public",
      :libvirt__dhcp_enabled => false,
      :libvirt__forward_mode => "nat"
    )
    # "rack" isolated networks per rack
    (1..num_racks).each do |rack_no|
      master_node.vm.network(:private_network,
        :ip => rack_subnets[rack_no].split(".")[0..2].join(".")+".254",
        :libvirt__host_ip => rack_subnets[rack_no].split(".")[0..2].join(".")+".253",
        :model_type => "e1000",
        :libvirt__network_name => "mr_#{node_name_prefix}_rack%02d" % [rack_no],
        :libvirt__dhcp_enabled => false,
        :libvirt__forward_mode => "none"
      )
    end
    config.vm.synced_folder ".", "/vagrant", disabled: true
    
  end

  # configure Client node VM
  config.vm.define "#{client_node_name}" do |client_node|
    client_node.vm.hostname = "#{client_node_name}"
    # Libvirt provider settings
    client_node.vm.provider(:libvirt) do |domain|
      domain.uri = "qemu+unix:///system"
      domain.memory = client_memory
      domain.cpus = client_cpus
      domain.driver = "kvm"
      domain.host = "localhost"
      domain.connect_via_ssh = false
      domain.username = user
      domain.storage_pool_name = "default"
      domain.nic_model_type = "e1000"
      domain.management_network_name = "mr_#{node_name_prefix}_vagrant"
      domain.management_network_address = "#{vagrant_cidr}"
      domain.nested = true
      domain.cpu_mode = "host-passthrough"
      domain.volume_cache = "unsafe"
      domain.disk_bus = "virtio"
      # DISABLED: switched to new box which has 100G / partition
      #domain.storage :file, :type => "qcow2", :bus => "virtio", :size => "20G", :device => "vdb"
    end
    ### Networks and interfaces
    # "public" network with nat forwarding
    client_node.vm.network(:private_network,
      :ip => client_node_ipaddr,
      :libvirt__host_ip => public_gateway,
      :model_type => "e1000",
      :libvirt__network_name => public_network_name,
      :libvirt__dhcp_enabled => false,
      :libvirt__forward_mode => "nat"
    )
    config.vm.synced_folder ".", "/vagrant", disabled: true
  end

  config.vm.define "#{server_node_name}", primary: true do |server_node|
    server_node.vm.hostname = "#{server_node_name}"
    # Libvirt provider settings
    server_node.vm.provider(:libvirt) do |domain|
      domain.uri = "qemu+unix:///system"
      domain.memory = server_memory
      domain.cpus = server_cpus
      domain.driver = "kvm"
      domain.host = "localhost"
      domain.connect_via_ssh = false
      domain.username = user
      domain.storage_pool_name = "default"
      domain.nic_model_type = "e1000"
      domain.management_network_name = "mr_#{node_name_prefix}_vagrant"
      domain.management_network_address = "#{vagrant_cidr}"
      domain.nested = true
      domain.cpu_mode = "host-passthrough"
      domain.volume_cache = "unsafe"
      domain.disk_bus = "virtio"
      # DISABLED: switched to new box which has 100G / partition
      #domain.storage :file, :type => "qcow2", :bus => "virtio", :size => "20G", :device => "vdb"
    end
    ### Networks and interfaces
    # "rack" isolated networks per rack
    (1..num_racks).each do |rack_no|
      server_node.vm.network(:private_network,
        :ip => rack_subnets[rack_no].split(".")[0..2].join(".")+".1",
        :libvirt__host_ip => rack_subnets[rack_no].split(".")[0..2].join(".")+".253",
        :model_type => "e1000",
        :libvirt__network_name => "mr_#{node_name_prefix}_rack%02d" % [rack_no],
        :libvirt__dhcp_enabled => false,
        :libvirt__forward_mode => "none"
      )
    end
    config.vm.synced_folder ".", "/vagrant", disabled: true
  end

end
# vi: set ft=ruby :
