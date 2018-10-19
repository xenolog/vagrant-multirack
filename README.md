vagrant-multirack
=================
Scripts to:

* Create libvirt lab for testing ECMP and L3 link balancing.

Often developer need lab for emulate multipath between nodes.
Typical scheme of clean lab is

![Network_topology](https://raw.githubusercontent.com/xenolog/vagrant-multirack/testing_ecmp/img/LAB_for_ECMP_testing.svg?sanitize=true)

Into KVM environment virtual TOR switches and virtual core router will be implemented as network namespaces into one VM:

![Implementation scheme](https://raw.githubusercontent.com/xenolog/vagrant-multirack/testing_ecmp/img/VENV_multirack.svg?sanitize=true)

Requirements
------------

* `libvirt`
* `ansible v2.7+`
* `vagrant v2.1.5+`
* `vagrant-libvirt` plugin (`vagrant plugin install vagrant-libvirt`)
* `$USER` should be able to connect to libvirt (test with `virsh list --all`)

Vargant lab preparation
-----------------------

* Change default IP pool for vagrant networks if you want

```bash
export VAGRANT_MR_POOL="10.100.0.0/16"

```

* Define pool for VIP addresses.

```bash
export VAGRANT_MR_VIP_POOL="10.10.0.0/24"

```

* Clone this repo

```bash
git clone https://github.com/xenolog/vagrant-multirack
cd vagrant-multirack
```

* Prepare the virtual lab

```bash
./cluster.sh create
```

You can define variable VAGRANT_MR_NO_PROVISION to prevent ansible provision. It may be helpful for creating snapshot of virt lab and run provisioning by hands. In this case Ansible will be run with fake provisioning file for creating true inventory file.


* Destroy the virtual lab

```bash
./cluster.sh destroy
```

By default will be deployed environmert, contains:

* Master node
* two racks
* two nodes per rack
* First node of each rack is a k8s control-plane node.
* First node of each rack contains RouteReflector container.
* virtual TORs implemented as network namespaces into master node VM

You able to re-define following default constants:

* DEFAULT_SERVER_URL -- Depends of your Vagrant distributions. Possible, you should to redefine it to 'https://vagrantcloud.com'
* VAGRANT_MR_BOX -- Vagrant box name. It should be 
* VAGRANT_MR_NAME_SUFFIX -- virtual env name suffix to able deploy different ENVs from one repo.
* VAGRANT_MR_BASE_AS_NUMBER -- AS number of core router and master node
* VAGRANT_MR_NETWORK_PUBLIC -- Public network CIDR
* VAGRANT_MR_MASTER_MEMORY -- amount of memory for master node (default: 1024)
* VAGRANT_MR_MASTER_CPUS -- amount of CPUs for master node (default: 1)
* VAGRANT_MR_SERVER_MEMORY -- amount of memory for server node (default: 1024)
* VAGRANT_MR_SERVER_CPUS -- amount of CPUs for server node (default: 1)
* VAGRANT_MR_CLIENT_MEMORY -- amount of memory for client node (default: 1024)
* VAGRANT_MR_CLIENT_CPUS -- amount of CPUs for client node (default: 1)
* VAGRANT_MR_NO_PROVISION -- may be defined to prevent provisioning nodes. It helpfull to debug purpose.
