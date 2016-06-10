#!/usr/bin/env bash
# Filename:                connect_osp_ceph.sh
# Description:             Connects HCI OSP to Ceph
# Supported Langauge(s):   bash-4.2.x & ansible-1.9.x
# Time-stamp:              <2016-06-10 13:21:46 jfulton> 
# -------------------------------------------------------
# This script only needs to be run once during initial deployment
# Restarts glance, cinder, nova so they repoll the new ceph cluster
# -------------------------------------------------------
# HARD CODED VARIABLES 
inventory_file=/etc/ansible/hosts
# -------------------------------------------------------
# SAFETY CHECKS

test "$(whoami)" != 'stack' && (echo "This must be run by the stack user on the undercloud"; exit 1)

mon=$(grep mons $inventory_file -A 1 | tail -1 | awk {'print $1'})
if [[ -z $mon ]]; then
    echo "No host under [mons] in $inventory_file. Exiting. "
    exit 1
fi

if ! hash ansible 2>/dev/null; then
    echo "Cannot find ansible command. Exiting. "
    exit 1
fi

# -------------------------------------------------------
# RESTART OPENSTACK SERVICES 

echo "Restarting Glance (with Pacemaker)"
ansible $mon -b -m shell -a "pcs resource disable openstack-glance-api-clone"
ansible $mon -b -m shell -a "pcs status | grep -A 2 glance-api"
ansible $mon -b -m shell -a "pcs resource enable openstack-glance-api-clone"
ansible $mon -b -m shell -a "pcs status | grep -A 2 glance-api"

echo "Restarting Cinder (with Pacemaker)"
ansible $mon -b -m shell -a "pcs resource disable openstack-cinder-volume "
ansible $mon -b -m shell -a "pcs status | grep -A 2 openstack-cinder-volume "
ansible $mon -b -m shell -a "pcs resource enable openstack-cinder-volume "
ansible $mon -b -m shell -a "pcs status | grep -A 2 openstack-cinder-volume "

echo "Restarting Nova-Compute on all compute nodes (with Systemd)"
ansible osds -b -m shell -a "systemctl status openstack-nova-compute.service "
ansible osds -b -m shell -a "systemctl restart openstack-nova-compute.service "
ansible osds -b -m shell -a "systemctl status openstack-nova-compute.service "

# -------------------------------------------------------
echo "The overcloud should be ready to use. Please test. "
exit 0
