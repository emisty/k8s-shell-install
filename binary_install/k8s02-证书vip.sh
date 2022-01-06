#!/bin/bash
#主服务器执行
N1=node1
N2=node2
N3=node3

IP1=192.168.0.131
IP2=192.168.0.11
IP3=192.168.0.232
VIP=192.168.0.100
SERIP=10.96.0.0/16
CLUSTERIP=10.97.0.0/16

now=`date +%s`
function log() {
  echo "[$((`date +%s` - now ))]  $@"
}

NOWPATH=$(cd `dirname $0`; pwd)
# if [[ ${#NODE_NAME} -eq 0 || ${#NODE_NAME2} -eq 0 || ${#NODE_NAME3} -eq 0 ]];then
#     log "需要传入主机名字参数 1当前主机 2其他 3其他"
#     exit
# fi

log "生成秘钥,即一个公钥id_rsa.pub一个私钥id_rsa"
cd ~
mkdir -p ~/.ssh
if [ ! -f "/root/.ssh/id_rsa.pub" ];then
    log "生成秘钥..."
    ssh-keygen -t rsa -b 2048
fi

log "对本机免密登入..."
cd /root/.ssh
cat id_rsa.pub >> authorized_keys
chmod 600 authorized_keys

log "对节点机免密登入..."
for i in $N2 $N3;
do ssh-copy-id -i id_rsa.pub $i;done



log "准备cfssl安装包，进入cfssl下载路径"
cd $NOWPATH/cfssl

#cfssl golang编写 openssl C编写
#https://github.com/cloudflare/cfssl/releases
log "检查cfssl"
if [ ! -f "cfssljson_1.6.1_linux_amd64" ];then
  log "请手动下载cfssljson_1.6.1_linux_amd64"
  log "请手动下载cfssl_1.6.1_linux_amd64"
  log "请手动下载cfssl-certinfo_1.6.1_linux_amd64"
fi

log "安装cfssl"
chmod +x cfssl*
cp -r cfssl_1.6.1_linux_amd64 /usr/local/bin/cfssl
cp -r cfssljson_1.6.1_linux_amd64 /usr/local/bin/cfssljson
cp -r cfssl-certinfo_1.6.1_linux_amd64 /usr/local/bin/cfssl-certinfo


log "进入kubernetes文件夹"
cd $NOWPATH/k8sbinary/kubernetes

log "准备docker安装包"
cd $NOWPATH/docker/



if [ ! -f "docker-ce-20.10.9-3.el7.x86_64.rpm" ];then
  log "docker-ce-19.03.15文件不存在....正在去下载"
  wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-20.10.9-3.el7.x86_64.rpm
elif [ ! -f "containerd.io-1.4.9-3.1.el7.x86_64.rpm" ];then
  log "containerd.io-1.4.9文件不存在....正在去下载"
  wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/containerd.io-1.4.9-3.1.el7.x86_64.rpm
elif [ ! -f "docker-ce-cli-20.10.9-3.el7.x86_64.rpm" ];then
  log "docker-ce-cli-19.03.15文件不存在....正在去下载"
  wget https://download.docker.com/linux/centos/7/x86_64/stable/Packages/docker-ce-cli-20.10.9-3.el7.x86_64.rpm
else
  log "docker-ce containerd.io docker-ce-cli文件存在"
fi

log "将docker包导入 子节点"
for i in $N2 $N3;do
  rsync -vaz $NOWPATH/docker/  $i:$NOWPATH/docker/ 
done


log "binary安装k8s2开始"

log "进入k8sbinary文件夹"
cd $NOWPATH/k8sbinary

if [ ! -f "kubernetes-server-linux-amd64.tar.gz" ];then
  log "下载k8s二进制包..."
  wget https://storage.googleapis.com/kubernetes-release/release/v1.22.3/kubernetes-server-linux-amd64.tar.gz
fi

if [ ! -d "kubernetes" ];then
  log "对k8s二进制包解压"
  tar -zxvf kubernetes-server-linux-amd64.tar.gz
fi

chmod -R 777 $NOWPATH/k8sbinary/kubernetes/server/bin/
cd $NOWPATH/k8sbinary/kubernetes/server/bin/
log "安装k8s master"
#这个本来安装master
for i in $N1 $N2 $N3;do
  rsync -vaz kube-apiserver kube-controller-manager kube-scheduler kubectl $i:/usr/local/bin/
done

log "安装k8s node"
#这个本来安装到node
for i in $N1 $N2 $N3;do 
  rsync -vaz kubelet kube-proxy $i:/usr/local/bin/;
done

log "创建k8s文件夹"
cd $NOWPATH/work/

# kubernetes组件证书/配置文件存放目录
mkdir -p $NOWPATH/work/k8s/conf
# kubernetes组件日志文件存放目录
mkdir -p $NOWPATH/work/k8s/log




#-----------------------------对keepalived haproxy进行配置---------------
log "对keepalived haproxy进行配置"

#log "备份老的haproxy配置文件"
#for i in node1 node2 node3;
#do mv $i:/etc/haproxy/haproxy.cfg $i:/etc/haproxy/haproxy.cfg.backup;done

log "创建新的haproxy配置文件"
cat > /etc/haproxy/haproxy.cfg << EOF
global
    maxconn 2000
    ulimit-n 16384
    log 127.0.0.1 local0 err
    stats timeout 30s

defaults
    log global
    mode http
    option httplog
    timeout connect 5000
    timeout client 50000
    timeout server 50000
    timeout http-request 15s
    timeout http-keep-alive 15s

frontend k8s-master
    bind 0.0.0.0:9443
    bind 127.0.0.1:9443
    mode tcp
    option tcplog
    tcp-request inspect-delay 5s
    default_backend k8s-master

backend k8s-master
    mode tcp
    option tcplog
    option tcp-check
    balance roundrobin
    default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100
    server node1 $IP1:6443 check
    server node2 $IP2:6443 check
    server node3 $IP3:6443 check
EOF

log "将新的haproxy复制到节点机"
for i in $N2 $N3;
do rsync -vaz /etc/haproxy/haproxy.cfg $i:/etc/haproxy/haproxy.cfg;done

#log "备份老的keepalived配置文件x"
#for i in node1 node2 node3;
#do mv $i:/etc/keepalived/keepalived.conf $i:/etc/keepalived/keepalived.conf.backup;done

log "将新的keepalived配置文件写入"
cat > /etc/keepalived/keepalived.conf << EOF
global_defs {
    router_id LVS_DEVEL
}
vrrp_script chk_apiserver {
    script "/etc/keepalived/check_apiserver.sh"
    interval 2
    weight -5
    fall 3
    rise 2
}
vrrp_instance VI_1 {
    state MASTER
    interface ens33
    mcast_src_ip $IP1
    virtual_router_id 51
    priority 200
    advert_int 2
    authentication {
        auth_type PASS
        auth_pass K8SHA_KA_AUTH
    }
    virtual_ipaddress {
        $VIP
    }
    track_script {
      chk_apiserver
    } 
}
EOF

log "对keepalived配置文件备份"
for i in $N2 $N3;
do rsync -vaz /etc/keepalived/keepalived.conf $i:/etc/keepalived/keepalived.conf;done

log "修改节点的keepalived文件的的ip"
ssh -n root@$N2 "sed -i 's/$IP1/$IP2/g' /etc/keepalived/keepalived.conf";
ssh -n root@$N3 "sed -i 's/$IP1/$IP3/g' /etc/keepalived/keepalived.conf";


log "keepalived检查文件"
cat > /etc/keepalived/check_apiserver.sh << EOF
#!/bin/bash
err=0
for k in $(seq 1 5)
do
    check_code=$(pgrep kube-apiserver)
    if [[ $check_code == "" ]]; then
        err=$(expr $err + 1)
        sleep 5
        continue
    else
        err=0
        break
    fi
done

if [[ $err != "0" ]]; then
    echo "systemctl stop keepalived"
    /usr/bin/systemctl stop keepalived
    exit 1
else
    exit 0
fi
EOF

for i in $N2 $N3;
do rsync -vaz /etc/keepalived/check_apiserver.sh $i:/etc/keepalived/check_apiserver.sh;done

for i in $N2 $N3;
do chmod -R 777 /etc/keepalived/check_apiserver.sh;done

log "启动haproxy 启动keeplived"
for i in $N1 $N2 $N3;do
  systemctl enable haproxy
  systemctl restart haproxy
  systemctl enable keepalived
  systemctl restart keepalived
done

#journalctl -xe
log "自行检查 ping $VIP"
log "自行检查 systemctl status haproxy"
log "自行检查 systemctl status keepalived"



#github完整代码 和一些跟新
#https://github.com/emisty/k8s-shell-install