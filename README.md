# k8s-shell-install

## k8s-kubadm-shell-install
分为4个步骤

k8s1.sh 第一个执行，这里对安装环境配置，安装了docker，安装了k8s安装工具（kuebadm kubectl kubelet），加载k8sdocker源

k8s2.sh 第二个执行，对K8s初始化

k8s3.sh 第三个执行，对dashboard安装

k8s4.sh 第四个执行，获取加入节点token，和登入dashboard的token

## k8s-binary-shell-install