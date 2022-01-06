#!/bin/bash
#主服务器执行一次


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

#apiserver "10.255.0.1"
#网络kcm  --service-cluster-ip-range=10.255.0.0/24 \
#  --cluster-cidr=10.0.0.0/16  \
#
#kubelet clusterDNS:
#- 10.255.0.2
#
#proxy "192.168.0.0.0/16"
#
#calico - name: CALICO_IPV4POOL_CIDR
#value: "10.0.0.0/16"
#
#coredns  clusterIP: 10.255.0.2

cd $NOWPATH/coredns
kubectl delete -f calico.yaml

rm -rf /run/calico \
/sys/fs/bpf/calico \
/var/lib/calico \
/var/lib/cni/ \
/var/log/calico \
/opt/cluster/plugins/calico \
/opt/cni/bin/calico \
/etc/cni/net.d


# ETCD 地址
ETCD_ENDPOINTS="https://$IP1:2379"
sed -i "s#.*etcd_endpoints:.*#  etcd_endpoints: \"${ETCD_ENDPOINTS}\"#g" calico.yaml
sed -i "s#__ETCD_ENDPOINTS__#${ETCD_ENDPOINTS}#g" calico.yaml

# ETCD 证书信息
ETCD_CA=`cat $NOWPATH/pki/ca.pem | base64 | tr -d '\n'`
ETCD_CERT=`cat $NOWPATH/pki/kube-apiserver.pem | base64 | tr -d '\n'`
ETCD_KEY=`cat $NOWPATH/pki/kube-apiserver-key.pem | base64 | tr -d '\n'`

# 替换修改
sed -i "s#.*etcd-ca:.*#  etcd-ca: ${ETCD_CA}#g" calico.yaml
sed -i "s#.*etcd-cert:.*#  etcd-cert: ${ETCD_CERT}#g" calico.yaml
sed -i "s#.*etcd-key:.*#  etcd-key: ${ETCD_KEY}#g" calico.yaml

sed -i 's#.*etcd_ca:.*#  etcd_ca: "/calico-secrets/etcd-ca"#g' calico.yaml
sed -i 's#.*etcd_cert:.*#  etcd_cert: "/calico-secrets/etcd-cert"#g' calico.yaml
sed -i 's#.*etcd_key:.*#  etcd_key: "/calico-secrets/etcd-key"#g' calico.yaml

sed -i "s#__ETCD_CA_CERT_FILE__#$NOWPATH/pki/ca.pem#g" calico.yaml
sed -i "s#__ETCD_CERT_FILE__#$NOWPATH/pki/kube-apiserver.pem#g" calico.yaml
sed -i "s#__ETCD_KEY_FILE__#$NOWPATH/pki/kube-apiserver-key.pem#g" calico.yaml

sed -i "s#__KUBECONFIG_FILEPATH__#/etc/cni/net.d/calico-kubeconfig#g" calico.yaml

#下载的还需要写入这些 有两个要写 calico-kube-controllers 和calico-node
# - name: KUBERNETES_SERVICE_HOST
#   value: "192.168.0.100"
# - name: KUBERNETES_SERVICE_PORT
#   value: "9443"
# - name: KUBERNETES_SERVICE_PORT_HTTPS
#   value: "9443"

log "配置网络组件"
#https://docs.projectcalico.org/v3.20/manifests/calico-etcd.yaml 
#https://docs.projectcalico.org/v3.20/manifests/calico/templates/calico-etcd-secrets.yaml
#wget https://docs.projectcalico.org/v3.20/manifests/calico.yaml
# --cluster-cidr=10.244.0.0/16  这个是kube-controller-manager的pod ip范围
#sed -i 's/192.168.0.0/10.244.0.0/g' calico.yaml
kubectl apply -f $NOWPATH/coredns/calico.yaml


#如果重新部署需要删除calico网络环境 
# #清理网络环境
# kubectl delete -f calico.yaml
# rm -rf /run/calico \
# /sys/fs/bpf/calico \
# /var/lib/calico \
# /var/log/calico \
# /opt/cluster/plugins/calico \
# /opt/cni/bin/calico

# #查看是否还有残留的calico的pod
# kubectl get pods -n kube-system

# #强制删除Pod
# kubectl delete pod  <pod名字> -n kube-system --force --grace-period=0
#查看容器事件描述，用来排查故障
#kubectl describe pod -n kube-system calico-node-**
#kubectl logs -f -n kube-system calico-node-wzmz5   -c calico-node
#kubectl logs -f -n kube-system coredns-86f4cdc7bc-wh6zx -c coredns

#查看calico日志
#tail -f /var/log/calico/cni/cni.log


