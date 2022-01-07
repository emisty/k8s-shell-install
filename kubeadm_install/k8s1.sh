#!/bin/bash
#该shell脚本是 kubeadm安装 k8s的文件
#centos 8.4
#该脚本需要在每个节点运行

#多层注释不能用数字 <<这个是sh脚本的多层注释，不执行
#查看版本号
<<check_release
#cat  /etc/redhat-release
#uname -a
#查看你要的版本docker1.19版本 这里下载好上传文件
#https://download.docker.com/linux/centos/
check_release

#需要一个香港的服务器 centos 7.9
#下载k8s rpm工具包 
<<download_kstools
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


#mkdir install_k8s
#cd install_k8s
#下载kubelet kubeadm kubectl rpm包
yumdownloader --resolve  -y kubelet kubeadm kubectl

#把下载的包 导入到rpm
#rpm -ivh --replacefiles --replacepkgs ~/install_k8s/*.rpm


#用yum从本地安装
yum install -y kubelet kubeadm kubectl
#查看要下载的k8s docker源
kubeadm config images list 
download_kstools

#mkdir install_k8s
#cd install_k8s
#下载k8s docker容器包
<<download_dockers
#下载
docker pull k8s.gcr.io/kube-apiserver:v1.23.1
docker pull k8s.gcr.io/kube-controller-manager:v1.23.1
docker pull k8s.gcr.io/kube-scheduler:v1.23.1
docker pull k8s.gcr.io/kube-proxy:v1.23.1
docker pull k8s.gcr.io/pause:3.6
docker pull k8s.gcr.io/etcd:3.5.1-0
docker pull k8s.gcr.io/coredns/coredns:v1.8.6

#保存 另存为
docker save k8s.gcr.io/kube-apiserver:v1.23.1 > kube-apiserver:v1.23.1
docker save k8s.gcr.io/kube-controller-manager:v1.23.1 > kube-controller-manager:v1.23.1
docker save k8s.gcr.io/kube-scheduler:v1.23.1 > kube-scheduler:v1.23.1
docker save k8s.gcr.io/kube-proxy:v1.23.1 > kube-proxy:v1.23.1
docker save k8s.gcr.io/pause:3.6 > pause:3.6
docker save k8s.gcr.io/etcd:3.5.1-0 > etcd:3.5.1-0
docker save k8s.gcr.io/coredns/coredns:v1.8.6 > coredns:v1.8.6
download_dockers


#文件目录
#centos8_k8s_install
#--install_docker
#--install_tools
#--install_k8s
#--k8s1.sh
#--k8s2.sh


#配置项 变量等于号要紧凑
NODE_NAME=$1
if [ ${#NODE_NAME} -eq 0 ];then
    log "需要传入当前主机名字参数..."
    exit
fi
k8s_version="v1.23.1"


echo "centos7 同步网络时间"
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


containerd_id="containerd.io-1.4.3-3.1.el7.x86_64.rpm"
docker_ce="docker-ce-19.03.9-3.el7.x86_64.rpm"
docker_ce_cli="docker-ce-cli-19.03.9-3.el7.x86_64.rpm"

if [ ! -f $docker_ce ];then
	log "docker-ce-19.03.15文件不存在....正在去下载"
	wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/$docker_ce
elif [ ! -f $containerd_id ];then
	log "containerd.io文件不存在....正在去下载"
	wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/$containerd_id
elif [ ! -f $docker_ce_cli ];then
	log "docker-ce-cli-19.03.15文件不存在....正在去下载"
	wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/$docker_ce_cli
else
  log "docker-ce containerd.io docker-ce-cli文件存在"
fi

log "开始安装docker"
sudo yum install -y $containerd_id
sleep 1
sudo yum install -y $docker_ce_cli
sleep 1
sudo yum install -y $docker_ce



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

log "rpm工具包安装"
#yum从自己的本地包安装
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
if [ -f "coredns:v1.8.6" ];then
	log "加载下载好的docker"
  docker load < kube-apiserver:v1.23.1
  docker load < kube-controller-manager:v1.23.1
  docker load < kube-scheduler:v1.23.1
  docker load < kube-proxy:v1.23.1
  docker load < pause:3.6
  docker load < etcd:3.5.1-0
  docker load < coredns:v1.8.6
else
	log "需要翻墙下载好相关的docker容器"
fi


log "没有报错的话，第一步全部安装完成"



