#!/bin/bash
#该shell脚本是 kubeadm安装 k8s的文件，有国内安装k8s的方法
#centos 8.4
#该脚本需要在每个节点运行

#多层注释不能用数字
<<download_docker
#cat  /etc/redhat-release
#uname -a
#查看你要的版本docker1.19版本 这里下载好上传文件
#https://download.docker.com/linux/centos/
download_docker

#需要一个香港的服务器 centos 8.4
<<download_kstools
#下载k8s rpm工具包 
yum install yum-utils -y

cat <<EOF > /etc/yum.repos.d/kubernetes.repo 
[kubernetes] 
name=Kubernetes 
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64 
enabled=1 
gpgcheck=1 
repo_gpgcheck=1 
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

yumdownloader --resolve  -y kubelet kubeadm kubectl
rpm -ivh --replacefiles --replacepkgs ~/k8s/*.rpm

#查看要下载的k8s docker源
kubeadm config images list 
download_kstools


#下载k8s docker容器包
<<download_dockerks
docker pull k8s.gcr.io/kube-apiserver:v1.22.3
docker pull k8s.gcr.io/kube-controller-manager:v1.22.3
docker pull k8s.gcr.io/kube-scheduler:v1.22.3
docker pull k8s.gcr.io/kube-proxy:v1.22.3
docker pull k8s.gcr.io/pause:3.5
docker pull k8s.gcr.io/etcd:3.5.0-0
docker pull k8s.gcr.io/coredns/coredns:v1.8.4

docker save k8s.gcr.io/kube-apiserver:v1.22.3 > kube-apiserver.tar
docker save k8s.gcr.io/kube-controller-manager:v1.22.3 > kube-controller-manager.tar
docker save k8s.gcr.io/kube-scheduler:v1.22.3 > kube-scheduler.tar
docker save k8s.gcr.io/kube-proxy:v1.22.3 > kube-proxy.tar
docker save k8s.gcr.io/pause:3.5 > pause.tar
docker save k8s.gcr.io/etcd:3.5.0-0 > etcd.tar
docker save k8s.gcr.io/coredns/coredns:v1.8.4 > coredns.tar
download_dockerks


#文件目录
#centos8_k8s_install
#--install_docker
#--install_tools
#--install_k8s
#--k8s1.sh
#--k8s2.sh

#配置项 变量等于号要紧凑
NODE_NAME="hw001"

echo "centos8 同步网络时间"
cat << EOF >> /etc/chrony.conf
server ntp.aliyun.com iburst
EOF

systemctl restart chronyd.service
chronyc sources -v
timedatectl set-timezone Asia/Shanghai

#输出 执行到时间减开始时间+message
#+%s获取绝对秒数
now=`date +%s`
function log() {
  echo "[$((`date +%s` - now ))]  $@"
}

log "kubadm安装k8s1开始 "

log "更改节点hostname为..."
hostnamectl set-hostname $NODE_NAME

log "需要root权限"
[[ `whoami` != "root" ]] && echo "需要root，或者使用sudo" && exit 1

log "追加host，fannel跨外网下载"
cat << EOF >> /etc/hosts
127.0.0.1       $NODE_NAME
199.232.28.133  raw.githubusercontent.com
EOF

log "yum跟新"
yum update -y

log "yum跟新成功"

log "关闭防火墙 关闭swap"
systemctl stop firewalld.service
systemctl disable firewalld.service
setenforce 0
swapoff -a

log "更改配置文件参数enforcing为disabled 关闭selinux"
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config


log "进入docker安装进程"

if [ ! -d "install_docker" ];then
  mkdir install_docker
else
  log "install_docker 文件夹存在"
fi

cd install_docker

if [ ! -f "docker-ce-19.03.15-3.el8.x86_64.rpm" ];then
	log "docker-ce-19.03.15文件不存在....正在去下载"
	wget https://download.docker.com/linux/centos/8/x86_64/stable/Packages/docker-ce-19.03.15-3.el8.x86_64.rpm
elif [ ! -f "containerd.io-1.4.9-3.1.el8.x86_64.rpm" ];then
	log "containerd.io-1.4.9文件不存在....正在去下载"
	wget https://download.docker.com/linux/centos/8/x86_64/stable/Packages/containerd.io-1.4.9-3.1.el8.x86_64.rpm
elif [ ! -f "docker-ce-cli-19.03.15-3.el8.x86_64.rpm" ];then
	log "docker-ce-cli-19.03.15文件不存在....正在去下载"
	wget https://download.docker.com/linux/centos/8/x86_64/stable/Packages/docker-ce-cli-19.03.15-3.el8.x86_64.rpm
else
  log "docker-ce containerd.io docker-ce-cli文件存在"
fi

log "开始安装docker"
sudo yum install -y containerd.io-1.4.9-3.1.el8.x86_64.rpm
sleep 1
sudo yum install -y docker-ce-cli-19.03.15-3.el8.x86_64.rpm
sleep 1
sudo yum install -y docker-ce-19.03.15-3.el8.x86_64.rpm



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
systemctl enable docker.service
docker info | grep Cgroup

cd ../install_tools

if [ -f "socat-1.7.3.3-2.el8.x86_64.rpm" ];then
	log "自己下载 安装工具包 kubelet kubeadm kubectl"
	rpm -ivh --replacefiles --replacepkgs *.rpm
else
	log "用阿里源 安装工具包 kubelet kubeadm kubectl"
	cat << EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
fi

yum install -y kubelet kubeadm kubectl
systemctl enable kubelet && systemctl start kubelet


source <(kubectl completion bash)
kubectl completion bash > /etc/bash_completion.d/kubectl

cd ../install_k8s
if [ -f "coredns.tar" ];then
	log "加载下载好的docker"
	docker load < coredns.tar
    docker load < kube-proxy.tar
    docker load < etcd.tar
    docker load < kube-scheduler.tar
    docker load < kube-apiserver.tar
    docker load < pause.tar
    docker load < kube-controller-manager.tar
else
	log "需要翻墙下载好相关的docker容器"
fi


log "没有报错的话，第一步全部安装完成"



