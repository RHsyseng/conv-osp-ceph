## How to apply this diff

Modify four Heat templates so that the compute role 
includes the StorageMgmt network. 
```
 cd /home/stack/
 patch -p3 < storage_mgmt_net_to_compute.patch
```
## How as this diff made

The four Heat templates were modified to produce the 
diff with the following commands. 
```
 cp -r /usr/share/openstack-tripleo-heat-templates ~/templates-net
 cp -r /usr/share/openstack-tripleo-heat-templates ~/templates

 vi templates-net/puppet/compute-puppet.yaml
 vi templates-net/compute.yaml
 vi templates-net/environments/network-isolation.yaml
 vi templates-net/overcloud-resource-registry-puppet.yaml

 diff -Naur /home/stack/templates /home/stack/templates-net > storage_mgmt_net_to_compute.patch
```
