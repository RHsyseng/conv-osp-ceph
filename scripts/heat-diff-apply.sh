#!/usr/bin/env bash
# Filename:                heat-diff-apply.sh
# Description:             Puts overcloud templates in place
# Supported Langauge(s):   GNU Bash 4.2.x
# Time-stamp:              <2016-06-09 09:32:16 jfulton> 
# -------------------------------------------------------
# Change the following based on where tempalates-diff is
# e.g. $TLD/templates-diff 
TLD=~/hci0/conv-osp-ceph
# ASSUMPTION: templates-diff is not in ~ and this script
# will create templates-diff and then modify ~/templates
# -------------------------------------------------------
# Use a tempaltes-diff directory so that I apply changes 
# to the templates provided by the package and to minimize
# the rebase all of ~/templates for each release. 
# -------------------------------------------------------
echo "Deleting old versions of ~/templates and ~/templates-diff"
rm -rf ~/templates/
rm -rf ~/templates-diff/

echo "Copying default templates provided by package"
cp -r /usr/share/openstack-tripleo-heat-templates ~/templates/ 

echo "Copying my templates-diff"
cp -r $TLD/templates-diff/ ~/templates-diff

echo "Adding yaml to make environment-specific network changes to ~/templates/"
cp ~/templates-diff/advanced-networking.yaml ~/templates/
mkdir ~/templates/nic-configs/
cp ~/templates-diff/nic-configs/controller-nics.yaml ~/templates/nic-configs/controller-nics.yaml
cp ~/templates-diff/nic-configs/compute-nics.yaml ~/templates/nic-configs/compute-nics.yaml

echo "Adding environment-specific ceph prep clean_osd.yaml and userdata_clean_osd.yaml"
cp ~/templates-diff/clean_osd.yaml ~/templates/clean_osd.yaml
cp ~/templates-diff/firstboot/userdata_clean_osd.yaml ~/templates/firstboot/userdata_clean_osd.yaml

echo "Updating puppet-ceph-external.yaml with the following diff"
diff -u ~/templates/environments/puppet-ceph-external.yaml ~/templates-diff/environments/puppet-ceph-external.yaml
cp -f ~/templates-diff/environments/puppet-ceph-external.yaml ~/templates/environments/puppet-ceph-external.yaml 

echo "Updating ceph.yaml with the following diff"
diff -u ~/templates/puppet/hieradata/ceph.yaml ~/templates-diff/puppet/hieradata/ceph.yaml
cp -f ~/templates-diff/puppet/hieradata/ceph.yaml ~/templates/puppet/hieradata/ceph.yaml 

echo "Updating environment-rhel-registration.yaml"
cp ~/templates-diff/extraconfig/pre_deploy/rhel-registration/environment-rhel-registration.yaml ~/templates/extraconfig/pre_deploy/rhel-registration/environment-rhel-registration.yaml

timezone=$(basename $(readlink /etc/localtime))
echo "Creating ~/templates/timezone.yaml so Overcloud nodes to have same timzone as Director ($timezone)"
echo "parameter_defaults:" > ~/templates/timezone.yaml
echo "  TimeZone: '$timezone'" >> ~/templates/timezone.yaml
