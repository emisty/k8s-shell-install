# k8s-shell-install

## k8s-kubadm-shell-install
分为4个步骤

k8s1.sh 第一个执行，这里对安装环境配置，安装了docker，安装了k8s安装工具（kuebadm kubectl kubelet），加载k8sdocker源

k8s2.sh 第二个执行，对K8s初始化

k8s3.sh 第三个执行，对dashboard安装

k8s4.sh 第四个执行，获取加入节点token，和登入dashboard的token

## k8s-binary-shell-install

### 1申请三个虚拟机

### 2 把binary_install上传到三个虚拟机上面，docker可以先下载好一起传比较快

### 3 修改shell里面的IP地址

### 4 给权限chmod -R 777 binary_install

### 5 按照数字顺序执行脚本

#### 1)脚本01需要分别在三台机子上执行

```
./k8s01-环境准备.sh node1
./k8s01-环境准备.sh node2
./k8s01-环境准备.sh node3
```
重启确定ip和主机名字
 
#### 2)脚本02只需要在主服务器执行
./k8s02-证书vip.sh
进入之后需要看提示：一直回车3下，yes 密码 yes密码yes yes
确认安装成功，分别在每台机子执行ping 192.168.0.100 可以成功
#### 3）脚本03 在主服务器执行就可以了
./k8s03-安装etcd.sh
安装到最后，需要分别去子节点启动etcd，最后有提示启动命令
```
sudo systemctl daemon-reload
sudo systemctl enable etcd.service
sudo systemctl restart etcd.service
```
确认安装成功与否，需要执行最后提示的句子，成功则显示：
 
#### 04）脚本04主服务器执行就可以了
安装到最后，需要分别去子节点启动etcd，最后有提示启动命令
```
systemctl daemon-reload
systemctl enable kube-apiserver.service
systemctl restart kube-apiserver.service
systemctl status kube-apiserver.service
```
 
最后ctrl+c结束
检查curl --insecure https://192.168.0.100:9443/ 返回如下成功
 
#### 05）脚本05主服务器执行就可以了
./k8s05-kubectl.sh
 
最后显示如图，则为正确
#### 06）脚本06主服务器执行就可以了
./k8s06-kcm.sh
   
安装到最后，需要分别去子节点启动
```
systemctl daemon-reload
systemctl enable kube-controller-manager.service
systemctl restart kube-controller-manager.service
systemctl status kube-controller-manager.service
```
#### 07）脚本07 主服务器执行就可以了
安装到最后，需要分别去子节点启动

./k8s07-scheduler.sh
 
#### 08）脚本08 分别在三个机子执行
./k8s08-docker.sh
检查看看docker里面是否有镜像
 
#### 09) 脚本09在主服务器安装
安装到最后，去子节点启动
```
systemctl daemon-reload
systemctl enable kubelet.service
systemctl restart kubelet.service
systemctl status kubelet.service
```

在回到主服务器执行
```
for csr in `kubectl get csr |awk 'NR>1 {print $1}'`;do kubectl certificate approve $csr;done
```
出现如图的样子，则成功
#### 10）脚本10 和脚本11在跑一下就可以了

#### 11）安装nginx
```
Kubectl apply -f nginx.yaml
```
