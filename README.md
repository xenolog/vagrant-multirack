vagrant-multirack
=================
Scripts to:

* Create libvirt lab with multi-rack network topology with Ubuntu 16.04 on the nodes.

Often developer need lab for emulate amount of nodes, located into
defferent racks with no L2 connectivity between racks. This lab implements case where using ExaBGP as iBGP announcer. One AS used as whole env. TOR switches a classic L2 switches without any L3 functionality

![Network_topology](https://raw.githubusercontent.com/xenolog/vagrant-multirack/test_exabgp_ibgp/img/LAB_for_ExaBGP.svg?sanitize=true)

The features of this LAB:

* One AS per rack, iBGP will be used
* BGP speaker on the nodes is only announcer. It does not receive any route information from Core router or neighboors.
* The TOR switches works only on L2 level. "L2 per rack" means, that 802.1q vlan inside rack terminated on the TOR and converted to vxlan or another method of L2 virtualization.  The only Core router is gateway for nodes, not a TOR !!!


Typical server for this lab is:

![Network_topology](https://raw.githubusercontent.com/xenolog/vagrant-multirack/test_exabgp_ibgp/img/LAB_for_ExaBGP__server.svg?sanitize=true)


Requirements
------------

* `libvirt`
* `ansible v2.7+`
* `vagrant v2.1.5+`
* `vagrant-libvirt` plugin (`vagrant plugin install vagrant-libvirt`)
* `$USER` should be able to connect to libvirt (test with `virsh list --all`)

LAB preparation
---------------

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

You can define variable VAGRANT_MR_NO_PROVISION to prevent nodes provision. Only blank VMs and networks will be created. It may be helpful for creating snapshot of virt lab and run provisioning by direct ansible run. In this case Ansible will be run by Vagrant with fake provisioning file for creating true inventory file.


* Destroy the virtual lab

```bash
./cluster.sh destroy
```

By default will be deployed environmert, contains:

* Master node (combined with core router)
* two racks
* two server nodes into 1st rack
* one server node into 2nd rack

You able to re-define following default constants:

* DEFAULT_SERVER_URL -- Depends of your Vagrant distributions. Possible, you should to redefine it to '<https://vagrantcloud.com>'
* VAGRANT_MR_BOX -- Vagrant box name. It should be
* VAGRANT_MR_NAME_SUFFIX -- virtual env name suffix to able deploy different ENVs from one repo.
* VAGRANT_MR_BASE_AS_NUMBER -- AS number of core router and master node
* VAGRANT_MR_NETWORK_PUBLIC -- Public network CIDR
* VAGRANT_MR_NUM_OF_RACKS -- amount of virtual racks
* VAGRANT_MR_RACK{N}_NODES -- specify nodes amount for rack N
* VAGRANT_MR_RACK{N}\_CP\_NODES -- specify nodes which will used for control plane (in the 1,2,3 format).
* VAGRANT_MR_RACK{N}_CIDR -- specify CIDR for network inside rack
* VAGRANT_MR_RACK{N}_AS_NUMBER -- specify rack AS number
* VAGRANT_MR_MASTER_MEMORY -- amount of memory for master node (default: 1024)
* VAGRANT_MR_MASTER_CPUS -- amount of CPUs for master node (default: 1)
* VAGRANT_MR_NODE_MEMORY -- amount of memory for nodes (default: 1024)
* VAGRANT_MR_NODE_CPUS -- amount of CPUs for nodes (default: 1)
* VAGRANT_MR_CLIENT_MEMORY -- amount of memory for client node (default: 1024)
* VAGRANT_MR_CLIENT_CPUS -- amount of CPUs for client node (default: 1)
* VAGRANT_MR_NO_PROVISION -- may be defined to prevent provisioning nodes. It helpfull to debug purpose.
* VAGRANT_MR_VIP_POOL -- network, which will announced from nodes, (def: 10.10.0.0/24)
* VAGRANT_MR_VIP1 -- pre-defined VIP (def: 10.10.0.10) which will be applied after deployment, NGiNX will answer.
