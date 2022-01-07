# k8s-shell-install

## k8s-kubadm-shell-install


### 安装前的准备

准备三个文件夹，并把相关的文件上传上去
```
install_docker
	--containerd.io-1.4.3-****rpm
	--docker-ce-19***rpm
	--docker-ce-cli-19***rpm
install_k8s
	--coredns.tar
	--etcd.tar
	--kube-apiserver.tar
	--kube-proxy.tar
	--kube-controller-manager.tar
	--kube-scheduler.tar
	--pause.tar
install_tools
	--***rpm 自己下载
```

### 分为4个步骤 开始安装


k8s1.sh 第一个执行，这里对安装环境配置，安装了docker，安装了k8s安装工具（kuebadm kubectl kubelet），加载k8sdocker源
```
./k8s1.sh hw001
./k8s1.sh hw002
./k8s1.sh hw003
```

k8s2.sh 第二个执行，对K8s初始化
只要在node1执行

k8s3.sh 第三个执行，对dashboard安装
只要在node1执行

k8s4.sh 第四个执行，获取加入节点token，和登入dashboard的token
备用 获取token，k8s3.sh已经执行出来了






