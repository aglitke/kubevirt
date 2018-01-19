set -e

echo "Setting up ceph"

cat <<EOM >/etc/yum.repos.d/ceph.repo
[ceph]
name=Ceph packages
baseurl=https://download.ceph.com/rpm/el7/x86_64
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc

[ceph-noarch]
name=Ceph noarch packages
baseurl=https://download.ceph.com/rpm/el7/noarch
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc

[ceph-source]
name=Ceph noarch packages
baseurl=https://download.ceph.com/rpm/el7/SRPMS
enabled=1
gpgcheck=1
type=rpm-md
gpgkey=https://download.ceph.com/keys/release.asc
EOM

#yum -y update
yum -y install ceph-deploy
yum -y install ntp ntpdate ntp-doc

# Set up ceph-deploy user
useradd -m -s /bin/bash ceph-deploy
echo "ceph-deploy ALL = (root) NOPASSWD:ALL" | tee /etc/sudoers.d/ceph-deploy
chmod 0440 /etc/sudoers.d/ceph-deploy

# The ceph-deploy tool requires key-based ssh login
sudo -niu ceph-deploy -- bash -c "cat /dev/zero | ssh-keygen -q -N \"\""
sudo -niu ceph-deploy -- bash -c "cat /home/ceph-deploy/.ssh/id_rsa.pub >> /home/ceph-deploy/.ssh/authorized_keys"
chmod 600 /home/ceph-deploy/.ssh/authorized_keys

# Run ceph-deploy tool
sudo -niu ceph-deploy -- mkdir /home/ceph-deploy/my-cluster
echo "192.168.201.2 master.localdomain" >> /etc/hosts
sudo -niu ceph-deploy -- bash -c "ssh-keyscan -t rsa master.localdomain >> ~/.ssh/known_hosts"
sudo -niu ceph-deploy -- bash -c "cd my-cluster && ceph-deploy new master.localdomain"

# Configure the cluster
echo "osd pool default size = 2" >> /home/ceph-deploy/my-cluster/ceph.conf 
echo "osd crush chooseleaf type = 0" >> /home/ceph-deploy/my-cluster/ceph.conf 

# Install this node
sudo -niu ceph-deploy -- ceph-deploy install master.localdomain 

# Create ceph mon
sudo -niu ceph-deploy -- bash -c "cd my-cluster && ceph-deploy mon create-initial"

# Prepare and activate OSDs
sudo -niu ceph-deploy -- bash -c "cd my-cluster && ceph-deploy osd prepare master.localdomain:vdb"
sudo -niu ceph-deploy -- bash -c "cd my-cluster && ceph-deploy osd prepare master.localdomain:vdc"
sudo -niu ceph-deploy -- bash -c "cd my-cluster && ceph-deploy osd prepare master.localdomain:vdd"
sudo -niu ceph-deploy -- bash -c "cd my-cluster && ceph-deploy osd activate master.localdomain:vdb1"
sudo -niu ceph-deploy -- bash -c "cd my-cluster && ceph-deploy osd activate master.localdomain:vdc1"
sudo -niu ceph-deploy -- bash -c "cd my-cluster && ceph-deploy osd activate master.localdomain:vdd1"

# Create volumes pool
ceph osd pool create volumes 128

# Set up standalone cinder
yum -y install git
sudo -niu vagrant git clone https://github.com/splitwood/cinder-standalone.git
sudo -niu vagrant cinder-standalone/cinder-standalone.sh -e cinder-standalone/environments/cinder-standalone-ceph.yaml