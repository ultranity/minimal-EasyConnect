# Easyconnect-alpine

基于 docker-alpine 的最小化Easyconnect CLI镜像，使用dante-server提供socks连接
移植&修改自 https://github.com/shmilee/scripts/tree/master/easyconnect-in-docker
体积变化：打包65.52 MB(shmilee)->36.71 MB(Hagb)->15.6MB, 解压后 ~130MB(shmilee)->~100MB(Hagb)->41.6MB

练习docker压榨打包产物，不考虑VNC/浏览器登录问题

## TAGS
ultranity/easyconnect:cli 主要版本，squash from distroless(推荐)
ultranity/easyconnect:alpine 采用alpine+glibc方案
ultranity/easyconnect:distroless 采用distroless:cc-cc-debian10，移植自shmilee方案
ultranity/easyconnect:buster 采用shmilee方案基础上优化


## 可能问题
[] alpine镜像在部分host上出现futex error


## 结构
```
├── src
│   ├── change_authority.sh:ec资源包文件权限&所有者设置
│   ├── Dockerfile.cli:优化版原镜像
│   ├── Dockerfile.cli.alpine: 构建alpine镜像
│   ├── Dockerfile.cli.distroless: 构建distroless镜像
│   ├── dpkg.cfg.excludes
│   ├── easyconnect.sh : 主逻辑 from [2][2]
│   ├── easyconn_resources_x64_7.6-378.tar.gz : ec资源包 packed from get_cli_resources.sh, 7.85MB
│   ├── get_cli_resources.sh : 下载并打包ec资源包
│   └── readme.md
├── Dockerfile.alpine : alpine-glibc 基础镜像
├── Dockerfile.debfetch : alpine-glibc 基础镜像
└── README.md
```
## 使用
### 获取镜像
### docker pull
直接转到启动
```
docker pull ultranity/easyconnect:cli
```
#### 下载导出包
```
wget https://github.com/ultranity/EasyConnect-alpine/releases/download/1.0/uec.tar.gz -O uec.tar.gz
gunzip -c uec.tar.gz|docker load
rm uec.tar.gz
```
#### 自行打包
```
git clone --depth 1 github.com/ultranity/Easyconnect-alpine
cd Easyconnect-alpine/src
docker build --rm -t ultranity/easyconnect:cli -f Dockerfile.cli.alpine .
```
### 启动
可用参数：
- `VERSION`: 指定运行的 EasyConnect 版本，必填

- `CLI_OPTS`: 默认为空，给 `easyconn login` 加上的额外参数，可用参数如下：
	```
	-d vpn address, make sure it's assigned and the format is right, like "199.201.73.191:443"
	-t login type, "pwd" means username/password authentication
	               "cert" means certificate authentication
	-u username
	-p password
	-c certificate path
	-m password for certificate
	-l certificate used to be authentication
    -v verbose: 默认添加，可用QUIET
	```
	例如 `CLI_OPTS="-d 服务器地址 -u 用户名 -p 密码"` 可实现原登录信息失效时自动登录。
- `SOCKS_USER`: 默认为空，为dantd添加连接认证
- `SOCKS_PASSWD`: 默认为空，为dantd添加连接认证
- `QUIET`: 减少stdout
```
docker run --device /dev/net/tun --cap-add NET_ADMIN -t -i -p 1080:1080 -e VERSION=7.6.8 -e CLI_OPTS="-d <address> -u <username> -p <password>" --name='ec' ultranity/easyconnect:cli
```
以后只需要 `docker start ec`


# 记录
~gcompact 可用性不如 alpine-pkg-glibc~,
glibc 2.35-r0 有bug缺少``*_chk`入口，待修复前使用2.34

gcompact官方推荐，好用

docker中chown会新增layer克隆文件导致镜像变大

minideb 比debian-slim小一点点（~2MB）
distroless!!!


# 参考致谢
[1]: https://github.com/Hagb/docker-easyconnect
[2]: https://github.com/shmilee/scripts/tree/master/easyconnect-in-docker
[3]: https://github.com/sgerrand/alpine-pkg-glibc
