# ha-nfs-vs
## Prereq
```
apt-get install -y nfs-kernel-server drbd8-utils ntp pacemaker crmsh haveged
```

## Configuration of DRDB

1. create volume with partition
```bash
fdisk /dev/vdb
```
2. add sysctl.conf parameters
``` bash
# drbd tuning
net.ipv4.tcp_no_metrics_save = 1
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.ipv4.tcp_rmem = 4096 87380 33554432
net.ipv4.tcp_wmem = 4096 87380 33554432
vm.dirty_ratio = 10
vm.dirty_background_ratio = 4
```
3. edit configuration of DRDB in /etc/drdb.conf and /etc/drbd.d/*.res (see examples in this repo)

4. create drdb device
``` bash
modprobe drbd
drbdadm create-md r0
drbdadm up r0
#only on one side run 
drbdadm primary test_drive --force
#monitoring sync 
watch cat /proc/drbd
```
5. create device and map to server 
``` bash
mkfs.ext4 /dev/drbd0
mount /dev/drdb0 /mnt
```
6. Disable drdb service because it will be managed by pacemaker
``` bash
systemctl disable drbd
drbdadm down r0
```
## Configuring corosync

1. add corosync config on both node (see examples in this repo)
2. generate key at primary node
``` bash
sudo corosync-keygen
```
3. copy key to second node
``` bash
sudo scp /etc/corosync/authkey username@server_B_ip:  /etc/corosync/
sudo chown root: /etc/corosync/authkey
sudo chmod 400 /etc/corosync/authkey
```
4. enable corosync
``` bash
sudo mkdir -p /etc/corosync/service.d
```

/etc/corosync/service.d/pcmk
```
# add 
service {
  name: pacemaker
  ver: 1
}
```
/etc/default/corosync
```# add 
START=yes

systemctl restart corosync
systemctl status corosync
```
5. Check status
``` bash
sudo corosync-cmapctl | grep members
```

## Configure pacemaker
1. Update service order because pacemaker depend on corosync
``` bash
sudo update-rc.d pacemaker defaults 20 01
```
2. Start Pacemaker
``` bash
systemctl start pacemaker
```
3. check status
``` bash
systemctl status pacemaker
```
4. add pacemaker configuration
``` bash
node 1: ubuntu18-nfs1
node 2: ubuntu18-nfs2
primitive drbd_nfs ocf:linbit:drbd \
	params drbd_resource=r0 \
	op monitor interval=15s
primitive fs_nfs Filesystem \
	params device="/dev/drbd0" directory="/oxus/nfs" fstype=ext4 options="noatime,nodiratime" \
	op start interval=0 timeout=60 \
	op stop interval=0 timeout=120
primitive nfs nfsserver \
	params nfs_init_script="/etc/init.d/nfs-kernel-server" nfs_shared_infodir="/oxus/nfs" nfs_ip=10.96.1.150 \
	op monitor interval=5s
primitive p_ip_nfs IPaddr2 \
	params ip=10.96.1.150 cidr_netmask=24 nic=ens3 \
	op monitor interval=30s --group HA
group HA fs_nfs p_ip_nfs nfs \
	meta target-role=Started
ms ms_drbd_nfs drbd_nfs \
	meta master-max=1 master-node-max=1 clone-max=2 clone-node-max=1 notify=true
order fs-nfs-before-nfs inf: fs_nfs:start nfs:start
order ms-drbd-nfs-before-fs-nfs inf: ms_drbd_nfs:promote fs_nfs:start
colocation ms-drbd-nfs-with-ha inf: ms_drbd_nfs:Master HA
property cib-bootstrap-options: \
	have-watchdog=false \
	dc-version=1.1.18-2b07d5c5a9 \
	cluster-infrastructure=corosync \
	cluster-name=debian \
	stonith-enabled=false \
	no-quorum-policy=ignore
```

## links
https://www.howtoforge.com/high-availability-nfs-with-drbd-plus-heartbeat
https://www.linuxtechi.com/configure-nfs-server-clustering-pacemaker-centos-7-rhel-7/
https://medium.com/@yenthanh/high-availability-using-corosync-pacemaker-on-ubuntu-16-04-bdebc6183fc5
