#!/bin/bash
#ResourcesDir=/usr/share/sangfor/EasyConnect/resources
ResourcesDir=./resources
usr=0 #root
#文件权限处理
chmod +x ${ResourcesDir}/bin/easyconn
chmod +x ${ResourcesDir}/bin/ECAgent
chmod +x ${ResourcesDir}/bin/svpnservice
chmod +x ${ResourcesDir}/bin/CSClient
#保证logs文件夹存在
mkdir -p ${ResourcesDir}/logs
chmod 777 ${ResourcesDir}/logs
###CSClient创建的域套接字的句柄在这, 加写权限
chmod 777 ${ResourcesDir}/conf-v* -R
chmod +x ${ResourcesDir}/shell/*
#更改所有者
chown ${usr}:${usr} ${ResourcesDir}/bin/ECAgent
chown ${usr}:${usr} ${ResourcesDir}/bin/svpnservice
chown ${usr}:${usr} ${ResourcesDir}/bin/CSClient
#添加s权限
chmod +s ${ResourcesDir}/bin/ECAgent
chmod +s ${ResourcesDir}/bin/svpnservice
chmod +s ${ResourcesDir}/bin/CSClient
