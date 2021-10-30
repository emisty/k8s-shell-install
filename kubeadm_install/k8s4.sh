#!/bin/bash
#该shell脚本是 kubeadm安装 k8s的文件，有国内安装k8s的方法
#centos 8.4


now=`date +%s`
function log() {
  echo "[$((`date +%s` - now ))]  $@"
}

log "生成加入k8s节点的token"
kubeadm token create --print-join-command --ttl 0


log "获取登入dashboard token"
kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}"