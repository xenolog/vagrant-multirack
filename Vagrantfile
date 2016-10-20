# -*- mode: ruby -*-

require "yaml"

class ::Hash
    def deep_merge(second)
        merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge(v2, &merger) : Array === v1 && Array === v2 ? v1 | v2 : [:undefined, nil, :nil].include?(v2) ? v1 : v2 }
        self.merge(second.to_h, &merger)
    end
end

pool = ENV["VAGRANT_MR_POOL"] || "10.250.0.0/16"

ENV["VAGRANT_DEFAULT_PROVIDER"] = "libvirt"
prefix = pool.gsub(/\.\d+\.\d+\/16$/, "")

num_racks = (ENV["VAGRANT_MR_NUM_OF_RACKS"] || "2").to_i
base_as_number = (ENV["VAGRANT_MR_BASE_AS_NUMBER"] || "65000").to_i

vm_memory = 6144
vm_cpus = 2
master_memory = 2048
master_cpus = 1

user = ENV["USER"]

public_subnet_000 = (ENV["VAGRANT_MR_NETWORK_PUBLIC"] || prefix.to_s + ".254.0/24")
public_subnets  = [public_subnet_000]
rack_subnets = ['']
vagrant_cidr = prefix.to_s + ".0.0/24"
nodes_per_rack = [0] # racks numbered from 1

(1..num_racks).each do |rack_no|
  nodes_per_rack << (ENV["VAGRANT_MR_RACK#{rack_no}_NODES"] || "2").to_i
  rack_subnets << (ENV["VAGRANT_MR_RACK#{rack_no}_CIDR"] || prefix.to_s + ".#{rack_no}.0/24")
end

node_name_prefix = "#{user}"
node_name_suffix = ENV["VAGRANT_MR_NAME_SUFFIX"] || ""
node_name_prefix+= "-#{node_name_suffix}" if node_name_suffix != ""

# Boxes with libvirt provider support:
box = "adidenko/ubuntu-1604-k8s"

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
master_node_ipaddr = public_subnets[0].split(".")[0..2].join(".")+".254"

# Create network_metadata for inventory
network_metadata = {
  'racks' => [{'as_number' => "65000"}],  # racks numbered from '1'
  'nodes' => {
    master_node_name => {
      'ipaddr' => master_node_ipaddr,
      'node_roles' => ['master'],
      'as_number'  => "65000",
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
    'as_number' => (ENV["VAGRANT_MR_RACK#{rack_no}_AS_NUMBER"] || base_as_number+rack_no).to_i,
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
      'as_number'  => (ENV["VAGRANT_MR_RACK#{rack_no}_AS_NUMBER"] || base_as_number+rack_no).to_i,
      'rack_no'    => rack_no,
    }
    if 1 == node_no
      network_metadata["nodes"][node_name]['node_roles'] << 'rr'
    end
  end
end
File.open("tmp/network_metadata.yaml", "w") do |file|
  file.write(network_metadata.to_yaml)
end

# Create the lab
Vagrant.configure("2") do |config|
  config.ssh.insert_key = false
  config.vm.box = box

  # prepare ansible deployment facts for master and slave nodes
  # This hash should be assembled before run any provisioners for prevent
  # parallel provisioning race conditions
  ansible_host_vars = {}
  (1..num_racks).each do |rack_no|
    (1..nodes_per_rack[rack_no]).each do |node_no|
      slave_name = "%s-%02d-%03d" % [node_name_prefix, rack_no, node_no]
      ansible_host_vars[slave_name] = {
        "node_name"          => slave_name,
        "master_node_name"   => master_node_name,
        "master_node_ipaddr" => master_node_ipaddr,
        "rack_no"            => "'%02d'" % rack_no,
        "node_no"            => "'%03d'" % node_no,
        "rack_number"        => rack_no,
        "rack_iface"         => "eth1",
        "tor_ipaddr"         => network_metadata['racks'][rack_no]['tor'],
      }
    end
  end
  ansible_host_vars[master_node_name] = {
    "node_name"          => "#{master_node_name}",
    "master_node_name"   => "#{master_node_name}",
    "master_node_ipaddr" => "#{master_node_ipaddr}",
  }

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
      :libvirt__host_ip => public_subnets[0].split(".")[0..2].join(".")+".1",
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
    # Provisioning (per VM)
    master_node.vm.provision "provision-master", type: "ansible" do |a|
      a.sudo = true
      a.playbook = "playbooks/master.yaml"
      a.host_vars = ansible_host_vars.deep_merge({"#{master_node_name}" => {
                                                    "rack_no"     => "'00'",
                                                    "rack_number" => "0",
                                                 }})
    end
    (1..num_racks).each do |r|
      master_node.vm.provision "provision-tor%02d" % r, type: "ansible" do |a|
        a.sudo = true
        a.playbook = "playbooks/master_rack.yaml"
        a.host_vars = ansible_host_vars.deep_merge({"#{master_node_name}" => {
                                                      "rack_no"     => "'%02d'" % r,
                                                      "rack_number" => "#{r}",
                                                   }})
      end
    end
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
          domain.memory = vm_memory
          domain.cpus = vm_cpus
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

        slave_node.vm.provision "provision-#{slave_name}", type: "ansible" do |a|
          a.sudo = true
          a.playbook = "playbooks/node.yaml"
          a.host_vars = ansible_host_vars
        end
      end
    end
  end
end
# vi: set ft=ruby :