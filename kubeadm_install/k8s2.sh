#!/bin/bash
#该shell脚本是 kubeadm安装 k8s的文件，有国内安装k8s的方法
#centos 8.4
#该脚本需要在主节点运行

now=`date +%s`
function log() {
  echo "[$((`date +%s` - now ))]  $@"
}

log "kubadm安装k8s2开始 "
sudo kubeadm reset
log "k8s 初始化... "
sudo kubeadm init --kubernetes-version=v1.22.3 --pod-network-cidr=10.244.0.0/16 --service-cidr=10.96.0.0/12 

log "复制k8s配置文件"

mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

export KUBECONFIG=/etc/kubernetes/admin.conf 

log "开启IP转发功能，为安装安装flannel网络组件做准备"
cat > /etc/sysctl.d/kubernetes.conf << EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

modprobe br_netfilter
sysctl --system

log "k8s 用flannel作为网络规划服务"
cd install_k8s
kubectl apply -f kube-flannel.yml

log "生成加入k8s节点的token"
kubeadm token create --print-join-command --ttl 0



