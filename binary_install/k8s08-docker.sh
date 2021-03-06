#!/bin/bash
#在每个子节点 跑一遍

N1=node1
N2=node2
N3=node3

IP1=192.168.0.131
IP2=192.168.0.11
IP3=192.168.0.232
VIP=192.168.0.100
SERIP=10.96.0.0/16
CLUSTERIP=10.97.0.0/16

NOWPATH=$(cd `dirname $0`; pwd)
now=`date +%s`
function log() {
  echo "[$((`date +%s` - now ))]  $@"
}

cd $NOWPATH/docker/

sudo yum remove -y containerd.io
sleep 1
sudo yum remove -y docker-ce-cli docker-scan-plugin
sleep 1
sudo yum remove -y docker-ce docker-ce-rootless-extras


log "进入docker安装进程"
sudo yum install -y containerd.io-1.4.9-3.1.el7.x86_64.rpm
sleep 1
sudo yum install -y docker-ce-cli-20.10.9-3.el7.x86_64.rpm docker-scan-plugin-0.9.0-3.el7.x86_64.rpm
sleep 1
sudo yum install -y docker-ce-20.10.9-3.el7.x86_64.rpm docker-ce-rootless-extras-20.10.9-3.el7.x86_64.rpm


log "普通用户需要加到 添加用户(当前)到组docker里"
#sudo groupadd docker
#sudo usermod -aG docker $USER

#log "手动 切换用户到新的用户组"
#newgrp docker


log "docker华为镜像加速"
sudo mkdir -p /etc/docker

sudo tee /etc/docker/daemon.json <<-'EOF'  
{
  "registry-mirrors": ["https://0a6b87ac200025770fdec00b87313bc0.mirror.swr.myhuaweicloud.com"],
  "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF


sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl restart containerd
systemctl enable docker.service
systemctl enable containerd.service
docker info | grep Cgroup




docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.4.1
docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.4.1 k8s.gcr.io/pause:3.4.1
docker rmi registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.4.1

docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/coredns:1.8.0
docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/coredns:1.8.0 k8s.gcr.io/coredns:1.8.0
docker rmi registry.cn-hangzhou.aliyuncs.com/google_containers/coredns:1.8.0

docker images

