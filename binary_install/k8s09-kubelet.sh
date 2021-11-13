#!/bin/bash
#部署kube-kubelet

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

kubectl delete csr --all
kubectl delete clusterrolebinding kubelet-bootstrap

cd $NOWPATH/pki
log "设置集群参数 设置客户端认证参数 设置上下文参数 设置默认上下文 创建角色绑定"
#设置集群参数 设置客户端认证参数 设置上下文参数 设置默认上下文
KUBE_CONFIG="bootstrap.kubeconfig"
KUBE_APISERVER="https://$VIP:9443"
# 与token.csv里保持一致
TOKEN=`cat $NOWPATH/pki/token.csv|awk -F',' '{print $1}'` 

# 生成 kubelet bootstrap kubeconfig 配置文件
kubectl config set-cluster kubernetes \
  --certificate-authority=$NOWPATH/pki/ca.pem \
  --embed-certs=true \
  --server=$KUBE_APISERVER \
  --kubeconfig=$KUBE_CONFIG
kubectl config set-credentials kubelet-bootstrap \
  --token=$TOKEN \
  --kubeconfig=$KUBE_CONFIG
kubectl config set-context default \
  --cluster=kubernetes \
  --user=kubelet-bootstrap \
  --kubeconfig=$KUBE_CONFIG
kubectl config use-context default --kubeconfig=$KUBE_CONFIG
kubectl create clusterrolebinding kubelet-bootstrap \
  --clusterrole=system:node-bootstrapper \
  --user=kubelet-bootstrap
kubectl create clusterrolebinding node-client-auto-approve-csr \
  --clusterrole=system:certificates.k8s.io:certificatesigningrequests:nodeclient \
  --group=system:node-bootstrapper
kubectl create clusterrolebinding node-client-auto-renew-crt \
  --clusterrole=system:certificates.k8s.io:certificatesigningrequests:selfnodeclient \
  --group=system:nodes

log "生成kubelet节点2配置文件"
cd $NOWPATH/pki
## 如果docker的驱动为systemd，处修改为systemd。否则后面node节点无法加入到集群
#address: 0.0.0.0 可以改为各自的ip
cat > $NOWPATH/pki/kubelet-config.yml << EOF
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: $IP1
port: 10250
readOnlyPort: 10255
cgroupDriver: systemd
clusterDNS:
- 10.90.0.10
clusterDomain: cluster.local.
failSwapOn: false
authentication:
  anonymous:
    enabled: false
  webhook:
    cacheTTL: 2m0s
    enabled: true
  x509:
    clientCAFile: $NOWPATH/pki/ca.pem 
authorization:
  mode: Webhook
  webhook:
    cacheAuthorizedTTL: 5m0s
    cacheUnauthorizedTTL: 30s
evictionHard:
  imagefs.available: 15%
  memory.available: 100Mi
  nodefs.available: 10%
  nodefs.inodesFree: 5%
maxOpenFiles: 1000000
maxPods: 110
EOF


log "生成kubelet.service服务文件"
mkdir -p /var/lib/kubelet
mkdir -p /var/log/kubernetes/kubelet
#kubeconfig空目录
cat > $NOWPATH/work/kubelet.service << EOF
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=docker.service
Requires=docker.service

[Service]
WorkingDirectory=/var/lib/kubelet
ExecStart=/usr/local/bin/kubelet \
  --bootstrap-kubeconfig=$NOWPATH/pki/bootstrap.kubeconfig \
  --cert-dir=$NOWPATH/pki \
  --kubeconfig=$NOWPATH/work/kubelet.kubeconfig \
  --config=$NOWPATH/pki/kubelet-config.yml \
  --pod-infra-container-image=k8s.gcr.io/pause:3.4.1 \
  --alsologtostderr=true \
  --network-plugin=cni
  --cni-bin-dir=/usr/k8s/cni
  --logtostderr=false \
  --log-dir=/var/log/kubernetes \
  --v=4
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF



log "kube-kubelet.service放到system目录"
chmod -R 777 $NOWPATH/work/kubelet.service 
cp $NOWPATH/work/kubelet.service /usr/lib/systemd/system/


log "拷贝kube-kubelet配置文件到子节点"
for i in $N2 $N3;do
  rsync -vaz $NOWPATH/pki/bootstrap.kubeconfig $NOWPATH/pki/kubelet-config.yml $i:$NOWPATH/pki/;
  rsync -vaz $NOWPATH/work/kubelet.service  $i:/usr/lib/systemd/system/
  ssh -n root@$i "mkdir -p /var/lib/kubelet"
  ssh -n root@$i "mkdir -p /var/log/kubernetes/kubelet"

  if [ "$i" == "$N2" ]; then
    ssh -n root@$i "sed -i 's/$IP1/$IP2/g'  $NOWPATH/pki/kubelet-config.yml;"
  else
    ssh -n root@$i "sed -i 's/$IP1/$IP3/g'  $NOWPATH/pki/kubelet-config.yml;"
  fi
done

#------------------节点为完成一下
log "kube-kubelet 要手动去启动一下节点的服务"
log "systemctl daemon-reload
systemctl enable kubelet.service
systemctl restart kubelet.service
systemctl status kubelet.service"
log "kubectl get csr"
log "此时全部都是pending的状态"
log "kubectl get nodes没有资源"
log "for csr in `kubectl get csr |awk 'NR>1 {print $1}'`;do kubectl certificate approve $csr;done"
log "kubectl certificate approve 你的node"

#用于调试
#for csr in `kubectl get csr |awk 'NR>1 {print $1}'`;do kubectl certificate approve $csr;done

# cat > $NOWPATH/pki/kubelet-bootstrap-rbac.yaml << EOF
# apiVersion: rbac.authorization.k8s.io/v1
# kind: ClusterRoleBinding
# metadata:
#   name: create-csrs-for-bootstrapping
# subjects:
# - kind: Group
#   name: system:bootstrappers
#   apiGroup: rbac.authorization.k8s.io
# roleRef:
#   kind: ClusterRole
#   name: system:node-bootstrapper
#   apiGroup: rbac.authorization.k8s.io  
# EOF

# kubectl apply -f $NOWPATH/pki/kubelet-bootstrap-rbac.yaml

