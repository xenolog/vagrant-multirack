#!/usr/bin/env python

# A simple dynamic replacemant of 'kargo prepare'
# Generates ansible inventory from a list of IPs in 'nodes' file.

import argparse
import json
import os
import yaml

def read_network_metadata_file(filename):
    with open(filename, 'r') as f:
        content = yaml.load(f)
    return content

def read_vars_from_file(src="/root/kargo/inventory/group_vars/all.yml"):
    with open(src, 'r') as f:
        content = yaml.load(f)
    return content

def nodes_to_hash(network_metadata, group_vars):
    nodes = {
          'all': {
              'hosts': [],
              'vars': group_vars
          },
          'etcd': {
              'hosts': [],
          },
          'kube-master': {
              'hosts': [],
          },
          'kube-node': {
              'hosts': [],
          },
          'k8s-cluster': {
              'children': ['kube-node', 'kube-master']
          },
          '_meta': {
              'hostvars': {}
          }
    }

    #for node_ip in network_metadata:
    mn_nodes = network_metadata.get('nodes', {})
    for node_name in mn_nodes:
        node = mn_nodes[node_name]
        node_roles = node.get('node_roles', [])
        if 'master' in node_roles:
            continue
        nodes['all']['hosts'].append(node_name)
        nodes['_meta']['hostvars'][node_name] = {
            'ansible_ssh_host': node['ipaddr'],
            'ip': node['ipaddr'],
        }
        nodes['kube-node']['hosts'].append(node_name)
        if 'kube_master' in node_roles:
            nodes['kube-master']['hosts'].append(node_name)
        if 'kube_etcd' in node_roles:
            nodes['etcd']['hosts'].append(node_name)
    nodes['kube-master']['hosts'].sort()
    nodes['kube-node']['hosts'].sort()
    nodes['etcd']['hosts'].sort()
    return nodes

def main():
    parser = argparse.ArgumentParser(description='Kargo inventory simulator')
    parser.add_argument('--list', action='store_true')
    parser.add_argument('--host', default=False)
    args = parser.parse_args()

    # Read params from ENV since ansible does not support passing args to dynamic inv scripts
    if os.environ.get('K8S_NETWORK_METADATA'):
        nodes_file = os.environ['K8S_NETWORK_METADATA']
    else:
        nodes_file = '/etc/network_metadata.yaml'

    if os.environ.get('KARGO_GROUP_VARS'):
        vars_file = os.environ['KARGO_GROUP_VARS']
    else:
        vars_file = "/root/kargo/inventory/group_vars/all.yml"

    network_metadata = read_network_metadata_file(nodes_file)

    nodes = nodes_to_hash(network_metadata, read_vars_from_file(vars_file))

    if args.host:
        print json.dumps(nodes['_meta']['hostvars'][args.host])
    else:
        print json.dumps(nodes)

if __name__ == "__main__":
    main()
