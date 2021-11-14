#!/bin/bash
#

N1=node1
N2=node2
N3=node3
IP1=192.168.0.27
IP2=192.168.0.19
IP3=192.168.0.20
VIP=192.168.0.100
SERIP=10.96.0.0/16
SERIP1=10.96.0.1

NOWPATH=$(cd `dirname $0`; pwd)
now=`date +%s`
function log() {
  echo "[$((`date +%s` - now ))]  $@"
}

#部署api-server
log "创建k8s api-server请求ca证书文件"

#kube-apiserver 指定的 service-cluster-ip-range 网段的第一个IP，如 10.254.0.1
cat > $NOWPATH/pki/kube-apiserver-csr.json << EOF
{
  "CN": "kubernetes",
  "hosts": [
    "127.0.0.1",
    "$IP1",
    "$IP2",
    "$IP3",
    "$VIP",
    "$SERIP1",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local",
    "$N1",
    "$N2",
    "$N3"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "Fujian",
      "L": "Fuzhou",
      "O": "k8s",
      "OU": "system"
    }
  ]
}
EOF

cd $NOWPATH/pki
log "创建k8s api-server请求ca证书文件"
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-apiserver-csr.json | cfssljson -bare kube-apiserver

log "为了省事 创建TLS机制所需TOKEN"
cat > token.csv << EOF
$(head -c 16 /dev/urandom | od -An -t x | tr -d ' '),kubelet-bootstrap,10001,"system:node-bootstrapper"
EOF

#注意排查错误直接用ExecStart

#官网文档
#https://kubernetes.io/zh/docs/reference/command-line-tools-reference/kube-apiserver/
#https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/
mkdir -p $NOWPATH/logs
touch $NOWPATH/logs/k8s-audit.log
cat > $NOWPATH/work/kube-apiserver.service << EOF
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes
After=etcd.service
Wants=etcd.service

[Service]
ExecStart=/usr/local/bin/kube-apiserver --logtostderr=false \
  --feature-gates=RemoveSelfLink=false \
  --v=2 \
  --log-dir=/opt/k8s/logs \
  --bind-address=0.0.0.0 \
  --secure-port=6443 \
  --advertise-address=$IP1 \
  --anonymous-auth=false \
  --allow-privileged=true \
  --runtime-config=api/all=true \
  --service-cluster-ip-range=$SERIP \
  --enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,ResourceQuota,NodeRestriction,DefaultStorageClass \
  --enable-bootstrap-token-auth \
  --token-auth-file=$NOWPATH/pki/token.csv \
  --authorization-mode=Node,RBAC \
  --service-node-port-range=30000-32767 \
  --kubelet-client-certificate=$NOWPATH/pki/kube-apiserver.pem \
  --kubelet-client-key=$NOWPATH/pki/kube-apiserver-key.pem \
  --tls-cert-file=$NOWPATH/pki/kube-apiserver.pem \
  --tls-private-key-file=$NOWPATH/pki/kube-apiserver-key.pem \
  --client-ca-file=$NOWPATH/pki/ca.pem \
  --etcd-servers=https://$IP1:2379,https://$IP2:2379,https://$IP3:2379 \
  --etcd-cafile=$NOWPATH/pki/ca.pem \
  --etcd-certfile=$NOWPATH/pki/kube-apiserver.pem \
  --apiserver-count=1 \
  --service-account-issuer=https://kubernetes.default.svc.cluster.local \
  --service-account-key-file=$NOWPATH/pki/ca-key.pem \
  --service-account-signing-key-file=$NOWPATH/pki/ca-key.pem\
  --etcd-keyfile=$NOWPATH/pki/kube-apiserver-key.pem \
  --requestheader-client-ca-file=$NOWPATH/pki/ca.pem \
  --proxy-client-cert-file=$NOWPATH/pki/kube-apiserver.pem \
  --proxy-client-key-file=$NOWPATH/pki/kube-apiserver-key.pem \
  --requestheader-allowed-names=kubernetes \
  --requestheader-extra-headers-prefix=X-Remote-Extra- \
  --requestheader-group-headers=X-Remote-Group \
  --requestheader-username-headers=X-Remote-User \
  --enable-aggregator-routing=true \
  --audit-log-maxage=30 \
  --audit-log-maxbackup=3 \
  --audit-log-maxsize=100 \
  --event-ttl=1h \
  --audit-log-path=$NOWPATH/logs/k8s-audit.log
Restart=on-failure
RestartSec=5
Type=notify
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

log "kube-apiserver.service放到system目录"
chmod -R 777 $NOWPATH/work/kube-apiserver.service
cp $NOWPATH/work/kube-apiserver.service /usr/lib/systemd/system/

log "拷贝kube-apiserver配置文件到子节点"
for i in $N2 $N3;do
  rsync -vaz $NOWPATH/logs/k8s-audit.log $i:$NOWPATH/logs/;
  rsync -vaz $NOWPATH/work/kube-apiserver.service $i:$NOWPATH/work/;
  rsync -vaz $NOWPATH/pki/kube-apiserver*.pem token.csv $i:$NOWPATH/pki/;
  if [ "$i" == "$N2" ]; then
    log "修改$N2 kube-apiserver配置文件"
    ssh -n root@$i "sed -i 's/--bind-address=$IP1/--bind-address=$IP2/g' $NOWPATH/work/kube-apiserver.service;"
    ssh -n root@$i "sed -i 's/--advertise-address=$IP1/--advertise-address=$IP2/g' $NOWPATH/work/kube-apiserver.service;"
    ssh -n root@$i "mv $NOWPATH/work/kube-apiserver.service /usr/lib/systemd/system/"
  
  elif [[ "$i" == "$N3" ]]; then
    log "修改$N3 kube-apiserver配置文件"
    ssh -n root@$i "sed -i 's/--bind-address=$IP1/--bind-address=$IP3/g' $NOWPATH/work/kube-apiserver.service;"
    ssh -n root@$i "sed -i 's/--advertise-address=$IP1/--advertise-address=$IP3/g' $NOWPATH/work/kube-apiserver.service;"
    ssh -n root@$i "mv $NOWPATH/work/kube-apiserver.service /usr/lib/systemd/system/"
  fi
done

log "kube-apiserver"
log "三台机子上都要打开kube-apiserver"
log "systemctl daemon-reload
  systemctl enable kube-apiserver.service
  systemctl restart kube-apiserver.service
  systemctl status kube-apiserver.service"
#三台机子上都要打开kube-apiserver
log "启动node1:kube-apiserver"
systemctl daemon-reload
systemctl enable kube-apiserver.service
systemctl restart kube-apiserver.service
systemctl status kube-apiserver.service


log "journalctl -xe"
log "检查3个主机，如果有错误，手动重启"

log "curl --insecure https://$IP1:6443/"
log "curl --insecure https://192.168.0.100:9443/ 设置了VIP:9443对6443"


