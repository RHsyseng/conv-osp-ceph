#!/usr/bin/env bash
# Filename:                connect_osp_ceph.sh
# Description:             Connects HCI OSP to Ceph
# Supported Langauge(s):   bash-4.2.x & ansible-1.9.x
# Time-stamp:              <2016-04-11 13:16:52 jfulton> 
# -------------------------------------------------------
# This script only needs to be run once during initial deployment
# 
# It does two things:
#  1. ensure puppet-ceph-external.yaml has correct mon_host IPs
#  2. restarts glance, cinder, nova
# -------------------------------------------------------
# HARD CODED VARIABLES 
network_file=~/templates/advanced-networking.yaml
ext_ceph_file=~/templates/environments/puppet-ceph-external.yaml
inventory_file=/etc/ansible/hosts
# -------------------------------------------------------
# SAFETY CHECKS

test "$(whoami)" != 'stack' && (echo "This must be run by the stack user on the undercloud"; exit 1)

for f in $ext_ceph_file $network_file $inventory_file; do 
    if [[ ! -f $f ]]; then
	echo "$f does not exist. Exiting. "
	exit 1
    fi
done

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
# DERIVED VARIABLES
short_ext_ceph_file=$(basename $ext_ceph_file)

echo -e "The overcloud needs $short_ext_ceph_file to have the correct CephExternalMonHost IPs\n"
echo -e "Retrieving CephExternalMonHost IPs from overcloud deployment\n"

# 1. get full CephExternalMonHost line from puppet-ceph-external.yaml
# 2. split on ':' and take what's the right of it. 
# 3. remove single or double quotes
# 4. xargs has side effect of trimming whitespace
current_ips=$(grep CephExternalMonHost $ext_ceph_file \
    | awk 'BEGIN { FS = ":" } ; { print $2 }' \
    | sed -e s/\'//g -e s/\"//g \
    | xargs)

# 1. get full StorageNetCidr line from $network_file
# 2. split on ':' and take what's the right of it. 
# 3. xargs has side effect of trimming whitespace
storage_net_cidr=$(grep StorageNetCidr $network_file \
    | awk 'BEGIN { FS = ":" } ; { print $2 }' \
    | xargs)

# split on /, take to the right
cidr=$(echo $storage_net_cidr | awk 'BEGIN { FS = "/" } ; { print $2 }')

# split on /, take to the left
storage_net_dot_zero=$(echo $storage_net_cidr | awk 'BEGIN { FS = "/" } ; { print $1 }')

# remove last character
storage_net_3_octet="${storage_net_dot_zero::-1}"

# 1. ansible SSH to all hosts and use shell
# 2. list all IPs and grep for the storage IP by cidr to exclude the vip with a /32
# 3. get only the string after 'inet' but drop the /$cidr
# 4. the order in which ansible returns varies so sort to make it consistent
# 5. concatenate all the lines into one string
correct_ips=$(ansible mons -b -m shell -a \
    "ip a | grep $storage_net_3_octet | grep $cidr" \
    | awk '/inet / {gsub(/\/.*/,"",$2); print $2}' \
    | sort \
    | sed -e ':a;N;$!ba;s/\n/, /g') 

# -------------------------------------------------------
# 1. ensure puppet-ceph-external.yaml has correct mon_host IPs

# update puppet-ceph-external.yaml but only if necessary
if [[ ! $correct_ips == $current_ips ]]; then
    echo -e "$short_ext_ceph_file has '$current_ips' but the correct IPs are '$correct_ips'\n" 
    echo "Updating $short_ext_ceph_file with: "
    echo sed -i "s/'$current_ips'/'$correct_ips'/g" $ext_ceph_file
    sed -i "s/'$current_ips'/'$correct_ips'/g" $ext_ceph_file
    echo -e "\nIPs in $short_ext_ceph_file updated"
else
    echo -e "$short_ext_ceph_file has the correct CephExternalMonHost IPs\n" 
fi

# show IPs in puppet-ceph-external.yaml
grep CephExternalMonHost $ext_ceph_file
echo ""

# -------------------------------------------------------
# 2. restart openstack services 

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
