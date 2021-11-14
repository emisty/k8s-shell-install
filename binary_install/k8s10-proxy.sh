#!/bin/bash
#部署kube-proxy

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

log "创建kube-proxy ca请求证书文件"
cd $NOWPATH/pki
cat > $NOWPATH/pki/kube-proxy-csr.json << EOF
{
  "CN": "system:kube-proxy",
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

log "创建kube-proxy ca证书"
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-proxy-csr.json | cfssljson -bare kube-proxy



cd $NOWPATH/pki
log "设置集群参数 设置客户端认证参数 设置上下文参数 设置默认上下文 创建角色绑定"
kubectl config set-cluster kubernetes \
  --certificate-authority=ca.pem --embed-certs=true \
  --server=https://$VIP:9443 \
  --kubeconfig=kube-proxy.kubeconfig
kubectl config set-credentials kube-proxy \
  --client-certificate=kube-proxy.pem \
  --client-key=kube-proxy-key.pem --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig
kubectl config set-context default --cluster=kubernetes \
  --user=kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig
kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig


log "生成kube-proxy配置文件"
cd $NOWPATH/pki
# clusterCIDR此处网段必须与网络组件网段保持一致，否则部署网络组件时会报错
cat > $NOWPATH/pki/kube-proxy.yml << EOF
apiVersion: kubeproxy.config.k8s.io/v1alpha1
bindAddress: 0.0.0.0
clientConnection:
  kubeconfig: $NOWPATH/pki/kube-proxy.kubeconfig
clusterCIDR: $CLUSTERIP
healthzBindAddress: 0.0.0.0:10256
kind: KubeProxyConfiguration
metricsBindAddress: 0.0.0.0:10249
mode: ipvs
ipvs:
  scheduler: "rr"
EOF


log "生成kube-proxy.service服务文件"
mkdir -p /var/lib/kube-proxy
mkdir -p /var/log/kubernetes/kube-proxy
#kubeconfig空目录
cat > $NOWPATH/work/kube-proxy.service << EOF
[Unit]
Description=Kubernetes kube-proxy
Documentation=https://github.com/kubernetes/kubernetes
After=network.target

[Service]
WorkingDirectory=/var/lib/kube-proxy
ExecStart=/usr/local/bin/kube-proxy \
  --config=$NOWPATH/pki/kube-proxy.yaml \
  --alsologtostderr=true \
  --logtostderr=false \
  --log-dir=/var/log/kubernetes/kube-proxy \
  --v=2
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF



log "kube-proxy.service放到system目录"
chmod -R 777 $NOWPATH/work/kube-proxy.service 
cp $NOWPATH/work/kube-proxy.service /usr/lib/systemd/system/


log "拷贝kube-proxy配置文件到子节点"
for i in $N2 $N3;do
  rsync -vaz $NOWPATH/pki/kube-proxy.kubeconfig $NOWPATH/pki/kube-proxy.yml $i:$NOWPATH/pki/;
  rsync -vaz $NOWPATH/work/kube-proxy.service  $i:/usr/lib/systemd/system/
  ssh -n root@$i "mkdir -p /var/lib/kube-proxy"
  ssh -n root@$i "mkdir -p /var/log/kubernetes/kube-proxy"

  if [ "$i" == "$N2" ]; then
    ssh -n root@$i "sed -i 's/$IP1/$IP2/g'  $NOWPATH/pki/kube-proxy.yml;"
  else
    ssh -n root@$i "sed -i 's/$IP1/$IP3/g'  $NOWPATH/pki/kube-proxy.yml;"
  fi
done


#------------------节点为完成一下
log "kube-kube-proxy 要手动去启动一下节点的服务"
log "systemctl daemon-reload
systemctl enable kube-proxy.service
systemctl restart kube-proxy.service
systemctl status kube-proxy.service"





