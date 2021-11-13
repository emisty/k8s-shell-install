#!/bin/bash
#建立kubectl和apiserver通信

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

log "创建请求admin ca证书文件"

cd $NOWPATH/pki
cat > $NOWPATH/pki/admin-csr.json << EOF
{
  "CN": "admin",
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
  ]
}
EOF

log "创建admin ca证书"
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin

#kubectl 默认从 ~/.kube/config 配置文件获取访问 kube-apiserver 地址、证书、用户名等信息
mkdir -p ~/.kube/
touch ~/.kube/config

cd $NOWPATH/pki
log "设置集群参数 设置客户端认证参数 设置上下文参数 设置默认上下文"
#设置集群参数 设置客户端认证参数 设置上下文参数 设置默认上下文
kubectl config set-cluster kubernetes --certificate-authority=ca.pem --embed-certs=true --server=https://$VIP:9443 --kubeconfig=kube.config
kubectl config set-credentials admin --client-certificate=admin.pem --client-key=admin-key.pem --embed-certs=true --kubeconfig=kube.config
kubectl config set-context kubernetes --cluster=kubernetes --user=admin --kubeconfig=kube.config
kubectl config use-context kubernetes --kubeconfig=kube.config
cp kube.config ~/.kube/config

log "授权kubernetes证书访问kubelet api权限"
kubectl create clusterrolebinding kube-apiserver:kubelet-apis --clusterrole=system:kubelet-api-admin --user kubernetes
#kubectl create clusterrolebinding kube-apiserver:kubelet-apis --clusterrole=system:kubelet-api-admin --user kubernetes


log "kubectl cluster-info"
log "kubectl get componentstatuses"
log "kubectl get all --all-namespaces"
kubectl cluster-info
kubectl get componentstatuses
kubectl get nodes
kubectl get csr


