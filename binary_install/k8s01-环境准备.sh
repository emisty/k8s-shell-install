#!/bin/bash
#该shell脚本是 二进制安装k8s的文件，有国内安装k8s的方法
#centos 8.4
#3台服务器都要执行,3台执行完，之后在运行后面的
#主服务器需要完整的文件目录结构，并且下载好相关的安装包，脚本自动拷贝到子节点
#IP规划为pod全用10.80.0.0/16段, service的IP段为10.90.0.0/16段

#文件目录
#centos8_k8s_install
#--cfssl
#--etcd
#--k8sbinary
#--pki
#--work
#--k8s1.sh
#--k8s2.sh
#--k8s3.sh
#--k8s4.sh
#--k8s5.sh

IP1=192.168.0.27
N1=node1
IP2=192.168.0.19
N2=node2
IP3=192.168.0.20
N3=node3
VIP=192.168.0.100

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

#配置项 变量等于号要紧凑
NODE_NAME=$1
if [ ${#NODE_NAME} -eq 0 ];then
    log "需要传入当前主机名字参数..."
    exit
fi

NOWPATH=$(cd `dirname $0`; pwd)

log "binary安装k8s1开始"


log "更改节点hostname为..."
hostnamectl set-hostname $NODE_NAME

log "关闭防火墙 关闭swap"
systemctl stop firewalld.service
systemctl disable firewalld.service
setenforce 0

log "关闭swap"
swapoff -a
#sed -ri 's/.*swap.*/#&/' /etc/fstab
sudo sed -i '/ swap / s/^/#/' /etc/fstab
echo "vm.swappiness = 0" >> /etc/sysctl.conf 
sysctl -p


log "更改配置文件参数enforcing为disabled 关闭selinux"
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

log "更改配置host文件 ip << 追加"
cat >> /etc/hosts << EOF
$IP1 $N1
$IP2 $N2
$IP3 $N3
EOF

log "设置ip转发规则,>只能创建新文件"
cat > /etc/sysctl.d/k8s.conf << EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
fs.may_detach_mounts = 1
vm.overcommit_memory=1
vm.panic_on_oom=0
fs.inotify.max_user_watches=89100
fs.file-max=52706963
fs.nr_open=52706963
net.netfilter.nf_conntrack_max=2310720

net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl =15
net.ipv4.tcp_max_tw_buckets = 36000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_orphans = 327680
net.ipv4.tcp_orphan_retries = 3
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.ip_conntrack_max = 131072
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_timestamps = 0
net.core.somaxconn = 16384
EOF

sysctl --system

log "追加ipvs文件"
sudo yum install ipset ipvsadm sysstat conntrack libseccomp -y
cat <<EOF >/etc/sysconfig/modules/ipvs.modules
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack
EOF
 
sudo chmod 755 /etc/sysconfig/modules/ipvs.modules
sudo bash /etc/sysconfig/modules/ipvs.modules
sudo lsmod | grep -e ip_vs -e nf_conntrack

log "创建工作目录"
mkdir -p $NOWPATH/work

log "放CA证书"
mkdir -p $NOWPATH/pki

log "安装同步软件"
yum install -y rsync

log "安装keepalived haproxy 获取虚拟ip k8s5文件配置"
yum -y install keepalived haproxy

#
log "需要重启一下reboot"







#github完整代码 和一些跟新
#https://github.com/emisty/k8s-shell-install

