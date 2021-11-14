#!/bin/bash
#主服务器执行一次


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

kubectl delete -f $NOWPATH/coredns/coredns.yaml

#log "安装coredns"
#curl https://docs.projectcalico.org/manifests/calico-etcd.yaml -o calico.yaml
#https://github.com/coredns/deployment/blob/master/kubernetes/coredns.yaml.sed
kubectl apply -f $NOWPATH/coredns/coredns.yaml

#log "kubectl get pods -n kube-system"
#动态查看
#kubectl get pods -n kube-system -w
#查看ip
#kubectl get pods -n kube-system -o wide
#强制删除
#kubectl delete --force --grace-period=0  pod coredns-86f4cdc7bc-qttsq -n kube-system 




