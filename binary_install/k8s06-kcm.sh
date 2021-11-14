#!/bin/bash
#部署kube-controller-manager

N1=node1
N2=node2
N3=node3
IP1=192.168.0.27
IP2=192.168.0.19
IP3=192.168.0.20
VIP=192.168.0.100
SERIP=10.96.0.0/16
CLUSTERIP=10.97.0.0/16
NOWPATH=$(cd `dirname $0`; pwd)
now=`date +%s`
function log() {
  echo "[$((`date +%s` - now ))]  $@"
}

log "创建请求kube-controller-manager ca证书文件"

cd $NOWPATH/pki
cat > $NOWPATH/pki/kube-controller-manager-csr.json << EOF
{
    "CN": "system:kube-controller-manager",
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
        "O": "system:kube-controller-manager",
        "OU": "system"
      }
    ]
}
EOF


log "创建kube-controller-manager ca证书"
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-controller-manager-csr.json  | cfssljson -bare kube-controller-manager

cd $NOWPATH/pki
log "设置集群参数 设置客户端认证参数 设置上下文参数 设置默认上下文"
#设置集群参数 设置客户端认证参数 设置上下文参数 设置默认上下文
# kubectl config set-cluster kubernetes --certificate-authority=ca.pem --embed-certs=true \
#   --server=https://$VIP:9443 --kubeconfig=kube-controller-manager.kubeconfig
# kubectl config set-credentials system:kube-controller-manager --client-certificate=kube-controller-manager.pem \
#   --client-key=kube-controller-manager-key.pem --embed-certs=true --kubeconfig=kube-controller-manager.kubeconfig
# kubectl config set-context system:kube-controller-manager --cluster=kubernetes --user=system:kube-controller-manager \
#   --kubeconfig=kube-controller-manager.kubeconfig
# kubectl config use-context system:kube-controller-manager --kubeconfig=kube-controller-manager.kubeconfig

cat > $NOWPATH/work/kube-controller-manager.kubeconfig << EOF
apiVersion: v1
clusters:
- cluster:
    certificate-authority: $NOWPATH/pki/ca.pem
    server: https://$IP1:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: system:kube-controller-manager
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: system:kube-controller-manager
  user:
    client-certificate: $NOWPATH/pki/kube-controller-manager.pem
    client-key: $NOWPATH/pki/kube-controller-manager-key.pem
EOF
  
mkdir -p /var/log/kubernetes
cat > $NOWPATH/work/kube-controller-manager.service << EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \
  --kubeconfig=$NOWPATH/work/kube-controller-manager.kubeconfig \
  --service-cluster-ip-range=$SERIP \
  --cluster-name=kubernetes \
  --cluster-signing-cert-file=$NOWPATH/pki/ca.pem \
  --cluster-signing-key-file=$NOWPATH/pki/ca-key.pem \
  --allocate-node-cidrs=true \
  --cluster-cidr=$CLUSTERIP  \
  --root-ca-file=$NOWPATH/pki/ca.pem  \
  --service-account-private-key-file=$NOWPATH/pki/ca-key.pem \
  --leader-elect=false \
  --client-ca-file=$NOWPATH/pki/ca.pem  \
  --tls-cert-file=$NOWPATH/pki/kube-controller-manager.pem \
  --tls-private-key-file=$NOWPATH/pki/kube-controller-manager-key.pem \
  --use-service-account-credentials=true \
  --logtostderr=false \
  --log-dir=/var/log/kubernetes \
  --port=0 \
  --bind-address=127.0.0.1 \
  --experimental-cluster-signing-duration=87600h \
  --feature-gates=RotateKubeletServerCertificate=true \
  --controllers=*,bootstrapsigner,tokencleaner \
  --alsologtostderr=true \
  --v=2

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF


log "kube-controller-manager.service放到system目录"
chmod -R 777 $NOWPATH/work/kube-controller-manager.service 
cp $NOWPATH/work/kube-controller-manager.service /usr/lib/systemd/system/

log "拷贝kube-controller-manager配置文件到子节点"
for i in $N2 $N3;do
  rsync -vaz $NOWPATH/work/kube-controller-manager.service  $i:/usr/lib/systemd/system/
  rsync -vaz $NOWPATH/pki/kube-controller-manager*.pem $i:$NOWPATH/pki/;
  rsync -vaz $NOWPATH/work/kube-controller-manager.kubeconfig $i:$NOWPATH/work/;
done

log "kube-controller-manager 要手动去启动一下节点的api"
#三台机子上都要打开kube-apiserver
#for i in $N1 $N2 $N3;do
#  log "启动$i:kube-controller-manager"
  systemctl daemon-reload
  systemctl enable kube-controller-manager.service
  systemctl restart kube-controller-manager.service
  systemctl status kube-controller-manager.service
#done

log "systemctl daemon-reload
  systemctl enable kube-controller-manager.service
  systemctl restart kube-controller-manager.service
  systemctl status kube-controller-manager.service"
log "kube-scheduler 如果还有不健康的，去手动启动一下"
kubectl get cs





