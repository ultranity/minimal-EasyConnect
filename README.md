# Easyconnect-alpine

基于 docker-alpine 的最小化Easyconnect CLI镜像，使用dante-server提供socks连接
移植&修改自 https://github.com/shmilee/scripts/tree/master/easyconnect-in-docker
体积变化：打包65.52 MB(shmilee)->36.71 MB(Hagb)->15.6MB, 解压后 ~100MB(Hagb)->41.6MB



练习docker压榨打包产物，不考虑VNC/浏览器登录问题，采用alpine+glibc方案

## 结构

├── src
│   ├── change_authority.sh:ec资源包文件权限&所有者设置
│   ├── Dockerfile.cli:优化版原镜像
│   ├── Dockerfile.cli.alpine: 构建镜像
│   ├── dpkg.cfg.excludes
│   ├── easyconnect.sh : 主逻辑 from [2][2]
│   ├── easyconn_resources_x64_7.6-378.tar.gz : ec资源包 packed from get_cli_resources.sh 
│   ├── get_cli_resources.sh : 下载并打包ec资源包
│   └── readme.md

├── Dockerfile.alpine : alpine-glibc 基础镜像 
└── README.md

## 使用
### 获取镜像
#### 自行打包
```
git clone --depth 1 github.com/ultranity/Easyconnect-alpine
cd Easyconnect-alpine/src
docker build --rm -t ec/alpine:cli -f Dockerfile.cli.alpine .
```

#### 下载导出包
```
wget https://github.com/ultranity/Easyconnect-alpine/releases/download/latest/uec.tar.gz -O uec.tar.gz
gunzip uec.tar.gz|docker load
rm uec.tar.gz
```
### 启动

```
docker run --device /dev/net/tun --cap-add NET_ADMIN -t -i -p 1080:1080 -e VERSION=7.6.8 -e CLI_OPTS="-d <address> -u <username> -p <password>" --name='ec' sangfor/easyconnect:cli
```
以后只需要 `docker start ec`


#记录
gcompact 可用性不如 alpine-pkg-glibc
minideb 比debian-slim小一点点（~2MB）
docker中chown会新增layer克隆文件导致镜像变大

glibc 2.35-r0 有bug缺少``*_chk`入口，待修复前使用2.34

# 参考致谢
[1]: https://github.com/Hagb/docker-easyconnect
[2]: https://github.com/shmilee/scripts/tree/master/easyconnect-in-docker
[3]: https://github.com/sgerrand/alpine-pkg-glibc
