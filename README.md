# Converged OpenStack and Ceph

Scripts and Templates to deploy OpenStack with Nova Computes and Ceph-OSDs running on the same server using OSP-Director and Ceph-Ansible.

## Usage Outline

1. Install OSP-Director and introspect hardware
2. Clone this repo
3. Use `heat-diff-apply.sh` to create custom `~/templates`
4. Modify `~/templates` for your enviornment:
   * Update `advanced-networking.yaml` and `nic-configs/*` for your network
   * Update `puppet-ceph-external.yaml` and `ceph.yaml` for your *planned* Ceph deployment
   * Update `environment-rhel-registration.yaml` with your Red Hat account
   * Only use `clean_osd.yaml` for practice deployments
5. Use `configure_fence.sh` to configure pacemaker fencing
6. Install OpenStack
7. Install Ansible and ceph-ansible on OSP-Director
8. Use `ansible-inventory.sh` to populate `/etc/ansible/hosts`
9. Use `ansible-diff-apply.sh` to create a custom `~/ceph-ansible`
   * modify `all`, `mons`, and `osds` to suit your environment
10. Deploy Ceph on the same hardware with OSDs on Computes and Mons on Controllers
11. Run `connect_osp_ceph.sh` to update `~/templates` and restart Glance, Cinder, and Nova

## Disclaimer

I work for Red Hat but this repo _by itself_ is not officially supported. 
