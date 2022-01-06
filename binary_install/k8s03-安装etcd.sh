#!/bin/bash
#一台主服务器执行 公钥私钥生成 并复制到节点

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

log "创建请求ca证书文件"

cd $NOWPATH/pki
cat > $NOWPATH/pki/ca-csr.json << EOF
{
  "CN": "kubernetes",
  "key": {
      "algo": "rsa",
      "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "Fujian",
      "L": "Fuzhou",
      "O": "system:masters", 
      "OU": "system"
    }
  ],
  "ca": {
      "expiry": "87600h"
  }
}
EOF

log "创建ca证书"
cfssl gencert -initca ca-csr.json  | cfssljson -bare ca

log "配置ca证书策略"
cat > $NOWPATH/pki/ca-config.json << EOF
{
  "signing": {
    "default": {
        "expiry": "87600h"
      },
    "profiles": {
        "kubernetes": {
            "usages": [
                "signing",
                "key encipherment",
                "server auth",
                "client auth"
            ],
            "expiry": "87600h"
        }
    }
  }
}
EOF

log "配置etcd请求csr文件"
cat > $NOWPATH/pki/etcd-csr.json << EOF
{
  "CN": "etcd",
  "hosts": [
    "127.0.0.1",
    "$IP1",
    "$IP2",
    "$IP3"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [{
    "C": "CN",
    "ST": "Fujian",
    "L": "Fuzhou",
    "O": "k8s",
    "OU": "system"
  }]
}
EOF

log "生成证书 etcd-key.pem  etcd.pem"
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes etcd-csr.json | cfssljson  -bare etcd
ls etcd*.pem


log "安装etcd集群"
log "进入etcd下载路径"
cd $NOWPATH/etcd
#https://github.com/etcd-io/etcd/releases/tag/v3.5.0
if [ ! -f "etcd-v3.5.0-linux-amd64.tar.gz" ];then
  log "请手动下载etcd-v3.5.0"
  exit
fi

log "安装etcd"
tar -xf etcd-v3.5.0-linux-amd64.tar.gz
chmod -R 777 etcd-v3.5.0-linux-amd64/etcd*
cp -p etcd-v3.5.0-linux-amd64/etcd* /usr/local/bin/

log "子节点安装etcd"
rsync -vaz etcd-v3.5.0-linux-amd64/etcd* node2:/usr/local/bin/
rsync -vaz etcd-v3.5.0-linux-amd64/etcd* node3:/usr/local/bin/

log "创建etcd.conf文件"
cat > $NOWPATH/work/etcd.conf << EOF
#[Member]
ETCD_NAME="etcd1"
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="https://$IP1:2380"
ETCD_LISTEN_CLIENT_URLS="https://$IP1:2379,http://127.0.0.1:2379"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://$IP1:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://$IP1:2379"
ETCD_INITIAL_CLUSTER="etcd1=https://$IP1:2380,etcd2=https://$IP2:2380,etcd3=https://$IP3:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF


log "创建etcd2.conf文件"
cat > $NOWPATH/work/etcd2.conf << EOF
#[Member]
ETCD_NAME="etcd2"
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="https://$IP2:2380"
ETCD_LISTEN_CLIENT_URLS="https://$IP2:2379,http://127.0.0.1:2379"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://$IP2:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://$IP2:2379"
ETCD_INITIAL_CLUSTER="etcd1=https://$IP1:2380,etcd2=https://$IP2:2380,etcd3=https://$IP3:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF

log "创建etcd3.conf文件"
cat > $NOWPATH/work/etcd3.conf << EOF
#[Member]
ETCD_NAME="etcd3"
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
ETCD_LISTEN_PEER_URLS="https://$IP3:2380"
ETCD_LISTEN_CLIENT_URLS="https://$IP3:2379,http://127.0.0.1:2379"

#[Clustering]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://$IP3:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://$IP3:2379"
ETCD_INITIAL_CLUSTER="etcd1=https://$IP1:2380,etcd2=https://$IP2:2380,etcd3=https://$IP3:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
EOF


log "创建etcd.service文件"
cat > $NOWPATH/work/etcd.service << EOF
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
EnvironmentFile=$NOWPATH/work/etcd.conf
WorkingDirectory=/var/lib/etcd/
ExecStart=/usr/local/bin/etcd \
  --cert-file=$NOWPATH/pki/etcd.pem \
  --key-file=$NOWPATH/pki/etcd-key.pem \
  --trusted-ca-file=$NOWPATH/pki/ca.pem \
  --peer-cert-file=$NOWPATH/pki/etcd.pem \
  --peer-key-file=$NOWPATH/pki/etcd-key.pem \
  --peer-trusted-ca-file=$NOWPATH/pki/ca.pem \
  --peer-client-cert-auth \
  --client-cert-auth
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

log "etcd.service放到system目录"
chmod -R 777 $NOWPATH/work/etcd.service
cp $NOWPATH/work/etcd.service /usr/lib/systemd/system/
mkdir -p /var/lib/etcd/default.etcd

log "拷贝配置文件到子节点"
for i in $N2 $N3;do
  rsync -vaz $NOWPATH/pki/etcd*.pem $NOWPATH/pki/ca*.pem $i:$NOWPATH/pki/;
  rsync -vaz $NOWPATH/work/etcd.service $i:/usr/lib/systemd/system/;
done

log "修改节点配置文件"
#==用于字符串比较 -eq用于数字比较
for i in $N2 $N3;do
  if [ "$i" == "$N2" ]; then
    log "修改节点$i 配置文件"
    rsync -vaz $NOWPATH/work/etcd2.conf $i:$NOWPATH/work/;
    ssh -n root@$N2 "mv $NOWPATH/work/etcd2.conf $NOWPATH/work/etcd.conf"
  elif [[ "$i" == "$N3" ]]; then
    log "修改节点$i 配置文件"
    rsync -vaz $NOWPATH/work/etcd3.conf $i:$NOWPATH/work/;
    ssh -n root@$N3 "mv $NOWPATH/work/etcd3.conf $NOWPATH/work/etcd.conf"
  fi
  ssh -n root@$i "chmod -R 777 /usr/local/bin/etcd*"
  ssh -n root@$i "chmod -R 777 /usr/lib/systemd/system/etcd.service"
  log "创建ETCD_DATA_DIR=default.etcd目录"
  ssh -n root@$i "mkdir -p /var/lib/etcd/default.etcd"
done



#systemctl status etcd

log "启动etcd"
log "启动etcd1的时候，要手动去启动node2 node3的etcd"
log "sudo systemctl daemon-reload
  sudo systemctl enable etcd.service
  sudo systemctl restart etcd.service"
#三台机子上都要打开etcd(现在第一个启动，等待好了，可能会报错，没关系，在2 3 启动)
for i in $N1 $N2 $N3;do
  log "启动$i:etcd"
  sudo systemctl daemon-reload
  sudo systemctl enable etcd.service
  sudo systemctl restart etcd.service
  #systemctl status etcd
done
log "如果报错分别手动启动三个etcd"
log "ETCDCTL_API=3 /usr/local/bin/etcdctl --write-out=table --cacert=$NOWPATH/pki/ca.pem --cert=$NOWPATH/pki/etcd.pem --key=$NOWPATH/pki/etcd-key.pem --endpoints=https://$IP1:2379,https://$IP2:2379,https://$IP3:2379 endpoint health"



#ETCDCTL_API=3 /usr/local/bin/etcdctl --write-out=table --cacert=/root/binary_install/pki/ca.pem --cert=/root/binary_install/pki/etcd.pem --key=/root/binary_install/pki/etcd-key.pem --endpoints=https://192.168.0.10:2379,https://192.168.0.17:2379,https://192.168.0.16:2379 endpoint health










#github完整代码 和一些跟新
#https://github.com/emisty/k8s-shell-install