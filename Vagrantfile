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
vip1 = ENV["VAGRANT_MR_VIP1"] || "10.10.0.10"

ENV["VAGRANT_DEFAULT_PROVIDER"] = "libvirt"
prefix = pool.gsub(/\.\d+\.\d+\/\d\d$/, "")

# Boxes with libvirt provider support:
box = ENV["VAGRANT_MR_BOX"] || "generic/ubuntu1804"

num_racks = (ENV["VAGRANT_MR_NUM_OF_RACKS"] || "2").to_i
user = ENV["USER"]
node_name_prefix = "#{user}"
node_name_suffix = ENV["VAGRANT_MR_NAME_SUFFIX"] || ""
node_name_prefix+= "-#{node_name_suffix}" if node_name_suffix != ""
base_as_number = (ENV["VAGRANT_MR_BASE_AS_NUMBER"] || "65000").to_i
public_subnet = (ENV["VAGRANT_MR_NETWORK_PUBLIC"] || prefix.to_s + ".254.0/24")

node_memory = (ENV["VAGRANT_MR_NODE_MEMORY"] || "1024").to_i
node_cpus = (ENV["VAGRANT_MR_NODE_CPUS"] || "1").to_i
client_memory = (ENV["VAGRANT_MR_SERVER_MEMORY"] || "1024").to_i
client_cpus = (ENV["VAGRANT_MR_SERVER_CPUS"] || "1").to_i
client_node_name = "%s-client" % [node_name_prefix]
client_node_ipaddr = public_subnet.split(".")[0..2].join(".")+".253"
master_memory = (ENV["VAGRANT_MR_MASTER_MEMORY"] || "1024").to_i
master_cpus = (ENV["VAGRANT_MR_MASTER_CPUS"] || "1").to_i
master_node_name = "%s-000" % [node_name_prefix]
master_node_ipaddr = public_subnet.split(".")[0..2].join(".")+".254"

public_subnet = (ENV["VAGRANT_MR_NETWORK_PUBLIC"] || prefix.to_s + ".254.0/24")
rack_subnets = ['']
vagrant_cidr = prefix.to_s + ".0.0/24"
nodes_per_rack = [0] # racks numbered from 1
public_gateway = public_subnet.split(".")[0..2].join(".")+".1"
public_network_name = "mr_#{node_name_prefix}_public"

print("### ENV:\n" +
      "    number of racks: #{num_racks}\n"+
      "    master node MEM: #{master_memory}\n"+
      "    master node CPU: #{master_cpus}\n"+
      "          nodes MEM: #{node_memory}\n"+
      "          nodes CPU: #{node_cpus}\n"+
      "    client node MEM: #{client_memory}\n"+
      "    client node CPU: #{client_cpus}\n"+
      "     control subnet: #{vagrant_cidr}\n"+
      "      public subnet: #{public_subnet}\n"+
      "           demo VIP: #{vip1}\n" +
      "         VIP subnet: #{vip_pool}\n")

(1..num_racks).each do |rack_no|
  nodes_per_rack << (ENV["VAGRANT_MR_RACK#{rack_no}_NODES"] || "2").to_i
  rack_subnets << (ENV["VAGRANT_MR_RACK#{rack_no}_CIDR"] || prefix.to_s + ".#{rack_no}.0/24")
  print("### RACK #{rack_no}:\n" +
        "    nodes: #{nodes_per_rack[rack_no]}\n"+
        "   subnet: #{rack_subnets[rack_no]}\n\n")
end

# Create SSH keys for future lab
system "bash scripts/ssh-keygen.sh"

# Create nodes list for future kargo deployment
nodes=[]
(1..num_racks).each do |rack_no|
  (1..nodes_per_rack[rack_no]).each do |node_no|
    nodes << rack_subnets[rack_no].split(".")[0..2].join(".")+".#{node_no}"
  end
end
File.open("tmp/nodes", "w") do |file|
  file.write(nodes.join("\n"))
  file.write("\n")
end

master_node_name = "%s-000" % [node_name_prefix]
master_node_ipaddr = public_subnet.split(".")[0..2].join(".")+".254"

# Create network_metadata for inventory
network_metadata = {
  'racks' => [{'as_number' => base_as_number, 'tor' => master_node_ipaddr}],  # racks numbered from '1'
  'nodes' => {
    master_node_name => {
      'ipaddr' => master_node_ipaddr,
      'node_roles' => ['master'],
      'as_number'  => base_as_number,
      'rack_no'    => 0,
    },
  },
  client_node_name => {
    'ipaddr' => client_node_ipaddr,
    'node_roles' => ['general','client'],
    'as_number'  => 0,
    'rack_no'    => 0,
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
  (1..nodes_per_rack[rack_no]).each do |node_no|
    node_name = "%s-%02d-%03d" % [node_name_prefix, rack_no, node_no]
    subnet_part = rack_subnets[rack_no].split(".")[0..2].join(".")
    network_metadata["nodes"][node_name] = {
      'ipaddr'     => "#{subnet_part}.#{node_no}",
      'gateway'    => "#{subnet_part}.254",
      'node_roles' => ['general'],
      'rack_no'    => rack_no,
    }
    network_metadata["nodes"][node_name]['node_roles'] << 'server'
  end
end
File.open("tmp/network_metadata.yaml", "w") do |file|
  file.write(network_metadata.to_yaml)
end

# prepare ansible deployment facts for master and slave nodes
# This hash should be assembled before run any provisioners for prevent
# parallel provisioning race conditions
nodes=[]
racks=[]
ansible_host_vars = {}
(1..num_racks).each do |rack_no|
  racks << "%d" % rack_no
  (1..nodes_per_rack[rack_no]).each do |node_no|
    slave_name = "%s-%02d-%03d" % [node_name_prefix, rack_no, node_no]
    nodes << slave_name
    ansible_host_vars[slave_name] = {
      "node_name"                  => slave_name,
      "rack_no"                    => "'%02d'" % rack_no,
      "node_no"                    => "'%03d'" % node_no,
      "rack_number"                => rack_no,
      "rack_iface"                 => "eth1",
      "tor_ipaddr"                 => network_metadata['racks'][rack_no]['tor'],
      # "rack_gateway"               => network_metadata['nodes'][slave_name]['gateway'],
    }
  end
end
ansible_host_vars[master_node_name] = {
  "node_name"                  => "#{master_node_name}",
}
ansible_host_vars[client_node_name] = {
  "node_name"                  => client_node_name,
  "rack_iface"                 => "eth1",
  "public_gateway"             => public_gateway,
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
      "nodes"   => nodes,
      "clients" => [client_node_name],
      "masters" => [master_node_name],
      "masters:vars" => {
        "virt_racks" => racks,
      },
      "all:children" => ["masters", "clients", "nodes"],
      "all:vars" => {
        "ansible_python_interpreter" => "/usr/bin/python3",
        "master_node_name"   => master_node_name,
        "master_node_ipaddr" => master_node_ipaddr,
        "client_node_name"   => client_node_name,
        "client_node_ipaddr" => client_node_ipaddr,
        "vip_pool" => vip_pool,
        "vip1" => vip1,
        "as_number" => base_as_number,
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

  # configure Racks VMs
  (1..num_racks).each do |rack_no|
    (1..nodes_per_rack[rack_no]).each do |node_no|
      slave_name = "%s-%02d-%03d" % [node_name_prefix, rack_no, node_no]
      config.vm.define "#{slave_name}" do |slave_node|
        slave_node.vm.hostname = "#{slave_name}"
        # Libvirt provider settings
        slave_node.vm.provider :libvirt do |domain|
          domain.uri = "qemu+unix:///system"
          domain.memory = node_memory
          domain.cpus = node_cpus
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

        # "rack" isolated network
        slave_node.vm.network(:private_network,
          :ip => network_metadata["nodes"][slave_name]["ipaddr"],
          :libvirt__host_ip => rack_subnets[rack_no].split(".")[0..2].join(".")+".253",
          :model_type => "e1000",
          :libvirt__network_name => "mr_#{node_name_prefix}_rack%02d" % [rack_no],
          :libvirt__dhcp_enabled => false,
          :libvirt__forward_mode => "none"
        )
      end
    end
  end
end

# vi: set ft=ruby :