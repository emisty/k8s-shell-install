#!/bin/bash
#该shell脚本是 kubeadm安装 k8s的文件，有国内安装k8s的方法
#centos 8.4
<<recommend_yaml
#增加直接访问端口
kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  type: NodePort #增加
  ports:
    - port: 443
      targetPort: 8443
      nodePort: 30043 #增加
  selector:
    k8s-app: kubernetes-dashboard
recommend_yaml

now=`date +%s`
function log() {
  echo "[$((`date +%s` - now ))]  $@"
}

log "进入dashboard_token文件夹"
cd dashboard_token

log "安装dashboard"
#https://kubernetes.io/zh/docs/tasks/access-application-cluster/web-ui-dashboard/
if [ ! -f "recommended.yaml" ];then
  log "recommended文件不存在....正在去下载"
  wget https://raw.githubusercontent.com/kubernetes/dashboard/v2.2.0/aio/deploy/recommended.yaml
else
  kubectl apply -f recommended.yaml
fi

log "生成dashboard 生成角色和权限"
kubectl apply -f db_role.yaml
kubectl apply -f db_svc.yaml
kubectl apply -f db_account.yaml


PRIMARY_IP=$(ip route get 8.8.8.8 | head -1 | awk '{print $7}')
#如果出现不能访问提示不安全，请输入thisisunsafe
log "chrome访问 https://$PRIMARY_IP:30043"

log "获取登入token"
kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get sa/admin-user -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}"
