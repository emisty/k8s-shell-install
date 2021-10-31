#!/bin/bash
#该shell脚本是 二进制安装k8s的文件，有国内安装k8s的方法
#centos 8.4

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

log "binary安装k8s1开始"

log "进入k8sbinary文件夹"
cd k8sbinary

if [ -f "kubernetes-server-linux-amd64.tar.gz" ];then
	log "自己下载 安装工具包 kubelet kubeadm kubectl"
	rpm -ivh --replacefiles --replacepkgs *.rpm
else
	log "用阿里源 安装工具包 kubelet kubeadm kubectl"
	wget https://storage.googleapis.com/kubernetes-release/release/v1.22.3/kubernetes-server-linux-amd64.tar.gz
fi


