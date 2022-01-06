
#### 0）申请三个虚拟机
 
2 把binary_install上传到三个虚拟机上面
3 修改shell里面的IP地址和节点名称
4 给权限chmod -R 777 binary_install
5 按照数字顺序执行脚本

#### 1)脚本01需要分别在三台机子上执行
```
./k8s01-环境准备.sh node1
./k8s01-环境准备.sh node2
./k8s01-环境准备.sh node3
```

重启确定ip和主机名字
 
#### 2）脚本02只需要在主服务器执行

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
 
#### 4）脚本04主服务器执行就可以了

安装到最后，需要分别去子节点启动etcd，最后有提示启动命令
```
systemctl daemon-reload
systemctl enable kube-apiserver.service
systemctl restart kube-apiserver.service
systemctl status kube-apiserver.service
```

最后ctrl+c结束
检查curl --insecure https://192.168.0.100:9443/ 返回如下成功
 
#### 5）脚本05主服务器执行就可以了
./k8s05-kubectl.sh
 
最后显示如图，则为正确
#### 6）脚本06主服务器执行就可以了
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
```
./k8s07-scheduler.sh
```

#### 08）脚本08 分别在三个节点的机子执行
./k8s08-docker.sh
检查看看docker里面是否有镜像
 
#### 09) 脚本09在主服务器安装

安装到最后，去两个子节点启动kubelet
```
systemctl daemon-reload
systemctl enable kubelet.service
systemctl restart kubelet.service
systemctl status kubelet.service
```

如果没有approve，在回到主服务器执行（一般这句可以不要执行
```
for csr in `kubectl get csr |awk 'NR>1 {print $1}'`;do kubectl certificate approve $csr;done
```

出现如图的样子，则成功

#### 10) 脚本10 proxy
安装到最后，去两个子节点启动proxy
```
systemctl daemon-reload
systemctl enable kube-proxy.service
systemctl restart kube-proxy.service
systemctl status kube-proxy.service
```

#### 11) 脚本11在主服务器安装

等待下载好，kubectl get pod -n kube-system查看1/1 running

#### 12) 脚本12在主服务器安装

等待下载好，kubectl get pod -n kube-system查看1/1 running
13）安装nginx
Kubectl apply -f nginx.yaml
 

