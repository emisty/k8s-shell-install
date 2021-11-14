#!/bin/bash
#部署kube-scheduler

N1=node1
N2=node2
N3=node3
IP1=192.168.0.27
IP2=192.168.0.19
IP3=192.168.0.20
VIP=192.168.0.100
NOWPATH=$(cd `dirname $0`; pwd)
now=`date +%s`
function log() {
  echo "[$((`date +%s` - now ))]  $@"
}

log "创建请求kube-scheduler ca证书文件"

cd $NOWPATH/pki
cat > $NOWPATH/pki/kube-scheduler-csr.json << EOF
{
    "CN": "system:kube-scheduler",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "hosts": [
      "127.0.0.1",
      "$IP1",
      "$IP2",
      "$IP3"
    ],
    "names": [
      {
        "C": "CN",
        "ST": "Fujian",
        "L": "Fuzhou",
        "O": "system:kube-scheduler",
        "OU": "system"
      }
    ]
}
EOF


log "创建kube-scheduler ca证书"
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-scheduler-csr.json  | cfssljson -bare kube-scheduler

cd $NOWPATH/pki
log "设置集群参数 设置客户端认证参数 设置上下文参数 设置默认上下文"
#设置集群参数 设置客户端认证参数 设置上下文参数 设置默认上下文
kubectl config set-cluster kubernetes --certificate-authority=ca.pem --embed-certs=true --server=https://$VIP:9443 --kubeconfig=kube-scheduler.kubeconfig
kubectl config set-credentials system:kube-scheduler --client-certificate=kube-scheduler.pem --client-key=kube-scheduler-key.pem --embed-certs=true --kubeconfig=kube-scheduler.kubeconfig
kubectl config set-context system:kube-scheduler --cluster=kubernetes --user=system:kube-scheduler --kubeconfig=kube-scheduler.kubeconfig
kubectl config use-context system:kube-scheduler --kubeconfig=kube-scheduler.kubeconfig


cat > $NOWPATH/work/kube-scheduler.service << EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler --address=127.0.0.1 \
  --kubeconfig=$NOWPATH/pki/kube-scheduler.kubeconfig \
  --leader-elect=true \
  --alsologtostderr=true \
  --logtostderr=false \
  --log-dir=/var/log/kubernetes \
  --v=4
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

log "kube-scheduler.service放到system目录"
chmod -R 777 $NOWPATH/work/kube-scheduler.service 
cp $NOWPATH/work/kube-scheduler.service /usr/lib/systemd/system/

log "拷贝kube-scheduler配置文件到子节点"
for i in $N2 $N3;do
  rsync -vaz $NOWPATH/work/kube-scheduler.service  $i:/usr/lib/systemd/system/
  rsync -vaz $NOWPATH/pki/kube-scheduler*.pem $i:$NOWPATH/pki/;
  rsync -vaz $NOWPATH/pki/kube-scheduler.kubeconfig $i:$NOWPATH/pki/;
done

log "kube-scheduler 要手动去启动一下节点的api"
#三台机子上都要打开kube-apiserver

systemctl daemon-reload
systemctl enable kube-scheduler.service
systemctl restart kube-scheduler.service
systemctl status kube-scheduler.service


log "  systemctl daemon-reload
  systemctl enable kube-scheduler.service
  systemctl restart kube-scheduler.service
  systemctl status kube-scheduler.service"

log "kube-scheduler 如果还有不健康的，去手动启动一下"
kubectl get cs





