## How to apply this diff

Modify four Heat templates so that the compute role 
includes the StorageMgmt network. 
```
 cd /home/stack/
 patch -p3 < storage_mgmt_net_to_compute.patch
```
## How was this diff made

Two Heat templates were modified to produce the diff with the following commands. 
```
 cp -r /usr/share/openstack-tripleo-heat-templates ~/templates-net
 cp -r /usr/share/openstack-tripleo-heat-templates ~/templates
 
 vi templates-net/kilo/compute.yaml
 vi templates-net/kilo/puppet/compute-puppet.yaml

 diff -Naur /home/stack/templates /home/stack/templates-net > storage_mgmt_net_to_compute.patch
```
