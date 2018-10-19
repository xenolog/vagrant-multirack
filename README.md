vagrant-multirack
=================
Scripts to:

* Create libvirt lab with multi-rack network topology with Ubuntu 16.04 on the nodes.

Often developer need lab for emulate amount of nodes, located into
defferent racks with no L2 connectivity between racks. Typical scheme of clean lab is

![Network_topology](https://cdn.rawgit.com/xenolog/vagrant-multirack/master/img/Typical_multirack.svg)

For example, k8s multi-rack deployment with AS per rack topology and Calico usage may look

![Network_topology](https://cdn.rawgit.com/xenolog/vagrant-multirack/master/img/Typical_multirack_k8s_calico.svg)

Into KVM virtual environment this network topology will be implemented as:

![Implementation scheme](https://cdn.rawgit.com/xenolog/vagrant-multirack/master/img/VENV_multirack.svg)


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
* VAGRANT_MR_NUM_OF_RACKS -- amount of virtual racks
* VAGRANT_MR_RACK{N}_NODES -- specify nodes amount for rack N
* VAGRANT_MR_RACK{N}\_CP\_NODES -- specify nodes which will used for control plane (in the 1,2,3 format).
* VAGRANT_MR_RACK{N}_CIDR -- specify CIDR for network inside rack
* VAGRANT_MR_RACK{N}_AS_NUMBER -- specify rack AS number
* VAGRANT_MR_MASTER_MEMORY -- amount of memory for master node (default: 4096)
* VAGRANT_MR_MASTER_CPUS -- amount of CPUs for master node (default: 2)
* VAGRANT_MR_NODE_MEMORY -- amount of memory for nodes (default: 2048)
* VAGRANT_MR_NODE_CPUS -- amount of CPUs for nodes (default: 1)
* VAGRANT_MR_NO_PROVISION -- may be defined to prevent provisioning nodes. It helpfull to debug purpose.
