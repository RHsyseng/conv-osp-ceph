#!/usr/bin/env bash
# Filename:                master.sh
# Description:             Controlls full HCI deployment
# Supported Langauge(s):   Bash 4.2.x
# Time-stamp:              <2016-08-01 11:54:17 jfulton> 
# -------------------------------------------------------
# VERIFY 

test "$(whoami)" != 'stack' && (echo "This must be run by the stack user on the undercloud"; exit 1)

pub_count=$(ls /pub/ | wc -l)
if [ ! "$pub_count" -gt "0" ] 
then 
  echo "NetApp not mounted (https://engineering.redhat.com/trac/refarch/wiki/netapp)"
  exit 1
fi

if [ ! -e "stackrc" ]
then
  echo "stackrc does not exist"
  exit 1
fi
source stackrc

ironic_servers=$(ironic node-list | awk {'print $2'} | egrep -v 'UUID|^$' | wc -l) 
if [ ! "$ironic_servers" -gt "0" ] 
then 
  echo "No bare metal nodes to deploy"
  exit 1
fi

nova_servers=$(nova list | awk {'print $2'} | egrep -v 'ID|^$' | wc -l) 
if [ "$nova_servers" -gt "0" ] 
then 
  echo "Overcloud Nova nodes found ( heat stack-delete overcloud ?)"
  exit 1
fi

if [ -d "~/hci0" ]; 
then
    echo "No hci0 directory; clone it from git"
    echo "  git clone git@gitlab.cee.redhat.com:johfulto/hci0.git"
    exit 1
fi

echo "Assuming the following: "
echo "- the undercloud is already installed as per undercloud.sh"
echo "- this is being run in screen"
read -r -p "Are the above true? [y/N] " prompt
if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]] 
  then
    echo "Installing HCI Overcloud";
else
    echo "Aborting as per your request"
    exit 1
fi

# -------------------------------------------------------
# PREPARE 

echo "Removing old deployment scripts"

rm -f ~/heat-diff-apply.sh
rm -f ~/deploy.sh
rm -f ~/validate.sh
rm -f ~/ansible-inventory.sh
rm -f ~/ansible-install.sh
rm -f ~/ansible-diff-apply.sh
rm -f ~/connect_osp_ceph.sh 
rm -f ~/add_compute_osd.sh
rm -f ~/remove_compute_osd.sh
rm -f ~/configure_fence.sh
rm -f ~/ceph-iso.sh
rm -rf ~/setup_perf.sh
rm -f ~/check_jumbo_frames.sh
rm -f ~/time-to-running-instance.sh

echo "Copying in deployment scripts from ~/hci0/"
# This is handy if you make an update in git 

cp ~/hci0/conv-osp-ceph/scripts/heat-diff-apply.sh ~/heat-diff-apply.sh
cp ~/hci0/conv-osp-ceph/scripts/ansible-diff-apply.sh ~/ansible-diff-apply.sh
cp ~/hci0/conv-osp-ceph/scripts/ansible-inventory.sh ~/ansible-inventory.sh
cp ~/hci0/conv-osp-ceph/scripts/connect_osp_ceph.sh ~/connect_osp_ceph.sh 
cp ~/hci0/conv-osp-ceph/scripts/configure_fence.sh  ~/configure_fence.sh

cp ~/hci0/private-scripts/deploy.sh ~/deploy.sh
cp ~/hci0/private-scripts/validate.sh ~/validate.sh
cp ~/hci0/private-scripts/ansible-install.sh ~/ansible-install.sh
cp ~/hci0/private-scripts/add_compute_osd.sh ~/add_compute_osd.sh
cp ~/hci0/private-scripts/remove_compute_osd.sh ~/remove_compute_osd.sh
cp ~/hci0/private-scripts/ceph-iso.sh ~/ceph-iso.sh
cp ~/hci0/private-scripts/setup_perf.sh ~/setup_perf.sh
cp ~/hci0/private-scripts/check_jumbo_frames.sh ~/check_jumbo_frames.sh
cp ~/hci0/private-scripts/time-to-running-instance.sh ~/time-to-running-instance.sh 

# -------------------------------------------------------
# INSTALL OSP

echo "Putting OSP Heat Templates in place and applying HCI changes to them"
~/heat-diff-apply.sh

echo "Updating CDN password"
sh /pub/projects/rhos/liberty/scripts/hci/cdn_passwd.sh

echo "Installing OpenStack"
~/deploy.sh

if [ $(heat stack-list | grep CREATE_FAILED | wc -l) -gt "0" ]; then 
    echo "Overcloud deployment failure. (CREATE_FAILED) Aborting."; 
    exit 1;
fi 

if [ $(heat stack-list | grep -i overcloud | wc -l) -eq "0" ]; then 
    echo "Overcloud deployment failure. (no overcloud found) Aborting."; 
    exit 1;
fi 

echo "Enabling pacemaker fencing"
~/configure_fence.sh enable

# -------------------------------------------------------
# INSTALLL CEPH

echo "Installing Ansible"
~/ansible-install.sh  

echo "Building Ansible Inventory from OpenStack"
~/ansible-inventory.sh

echo "Putting ceph-ansible Playbooks in place and applying HCI changes to them"
~/ansible-diff-apply.sh

echo "Updating ceph-ansible to use ISO"
~/ceph-iso.sh

echo "Checking Jumbo Frames"
~/check_jumbo_frames.sh

echo "Installing Ceph"
pushd ~/ceph-ansible && time ansible-playbook site.yml && popd

# -------------------------------------------------------
# CONNECT OSP AND CEPH

echo "Connecting OSP and Ceph"
~/connect_osp_ceph.sh 

# -------------------------------------------------------
# VALIDATE
echo "Running short validation"
~/validate.sh
~/validate.sh show 
#~/validate.sh clean
time ~/time-to-running-instance.sh 8 > ~/time-to-running-report.txt

# -------------------------------------------------------
echo "Setting up information that browbeat needs on NFS server"
~/setup_perf.sh

# -------------------------------------------------------
# ADD/REMOVE EXTRA NODE IN U35

# echo "Adding new compute/osd node (with validation of compute only)"
# ~/add_compute_osd.sh

# echo "Running short validation with new node as compute and OSD"
# ~/validate.sh
# ~/validate.sh show 
# ~/validate.sh clean

#echo "Removing new compute/osd node"
#~/remove_compute_osd.sh
