#!/usr/bin/env bash
# Filename:                ansible-diff-apply.sh
# Description:             copys yml from ceph-ansible-diff
# Supported Langauge(s):   GNU Bash 4.2.x
# Time-stamp:              <2016-05-06 11:17:17 jfulton> 
# -------------------------------------------------------
# Change the following based on where ceph-ansible-diff is
# e.g. $TLD/ceph-ansible-diff
TLD=~/hci0/conv-osp-ceph
# -------------------------------------------------------
echo "Deleting old ceph-ansible directory"
cd /home/stack/
rm -rf ceph-ansible 

echo "Copying the shipped /usr/share/ceph-ansible"
cp -r /usr/share/ceph-ansible/ ~/ceph-ansible

echo "Using default site.yml.sample for ~/ceph-ansible/site.yml"
cp /usr/share/ceph-ansible/site.yml.sample ~/ceph-ansible/site.yml

echo "Copying environment specific files from samples into ceph-ansible: all, osds, mons"
cp $TLD/ceph-ansible-diff/group_vars/all ~/ceph-ansible/group_vars/
cp $TLD/ceph-ansible-diff/group_vars/osds ~/ceph-ansible/group_vars/
cp $TLD/ceph-ansible-diff/group_vars/mons ~/ceph-ansible/group_vars/

echo "Making the following customizations to ceph-ansible"
for f in roles/ceph-mon/tasks/ceph_keys.yml roles/ceph-mon/tasks/openstack_config.yml roles/ceph-fetch-keys/tasks/main.yml; do 
    echo -e "\n";
    dist=~/ceph-ansible/$f
    new=$TLD/ceph-ansible-diff/$f
    echo "diff -u $dist $new"
    diff -u $dist $new
    echo "cp -f $new $dist"
    cp -f $new $dist
    echo -e "\n";
done 

echo "Modifying ceph.conf j2 file to use underscores consistently with ~/templates/puppet/hieradata/ceph.yaml"
# If $conf has a variable in $vars but with spaces instead of underscores, 
# then update $conf so that the variable has underscores instead of spaces. 

conf=/home/stack/ceph-ansible/roles/ceph-common/templates/ceph.conf.j2
conf_short=$(basename $conf)

vars=(osd_journal_size osd_pool_default_pg_num osd_pool_default_pgp_num osd_pool_default_size osd_pool_default_min_size auth_service_required auth_cluster_required auth_client_required);

for var in ${vars[@]}; do
    sans_under=$(echo $var | sed 's/_/\ /g');
    if [[ $(grep "$sans_under" $conf) ]] 
    then
        echo "Changing '$sans_under' to '$var' in $conf_short";
        sans_under_backslashed=$(echo $var | sed 's/_/\\\ /g');
        sed "s/$sans_under_backslashed/$var/g" -i $conf;
    fi
done                

# update ~/ceph-ansible/rolling_update.yml from shipped defaults

echo "Increasing both retries and delay in ~/ceph-ansible/rolling_update.yml to 15 (for all)"
sed -i \
    -e s/delay:\ '[0-9]\{1,2\}'/delay:\ 15/g \
    -e s/retries:\ '[0-9]\{1,2\}'/retries:\ 15/g \
    ~/ceph-ansible/rolling_update.yml

echo "Updating ~/ceph-ansible/rolling_update.yml to not update ceph packages (config updates only)"
sed -i \
    -e s/'upgrade_ceph_packages: True'/'upgrade_ceph_packages: False'/g \
    ~/ceph-ansible/rolling_update.yml

