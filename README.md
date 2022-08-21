# minimal-Easyconnect

基于 docker 的最小化Easyconnect CLI镜像，使用dante-server提供socks连接
主要移植&修改自 https://github.com/shmilee/scripts/tree/master/easyconnect-in-docker，以及https://github.com/Hagb/docker-easyconnect
体积变化：打包65.52 MB(shmilee)->36.71 MB(Hagb)->15.56MB, 解压后 ~130MB(shmilee)->~100MB(Hagb)->40MB

练习docker压榨打包产物，自用为主，没得测试不考虑VNC/浏览器登录问题

## TAGS
ultranity/easyconnect:cli 主要版本，squash from distroless(推荐)
ultranity/easyconnect:alpine 采用alpine+glibc方案,部分host目前报错
ultranity/easyconnect:distroless 采用distroless:cc-cc-debian10，移植自shmilee方案
ultranity/easyconnect:buster 采用shmilee方案基础上优化


## 可能问题
[] alpine镜像在部分host上出现futex error
[] 未移植的[docker-easyconnect][1]中的修复


## 结构
```
├── src
│   ├── change_authority.sh:ec资源包文件权限&所有者设置
│   ├── Dockerfile.cli:squash的distroless镜像， 解压后48.5MB
│   ├── Dockerfile.cli.alpine: 构建alpine镜像，解压后41.6MB
│   ├── Dockerfile.cli.buster:优化版原镜像， 解压后96.5MB
│   ├── Dockerfile.cli.distroless: 构建distroless镜像，解压后64MB
│   ├── dpkg.cfg.excludes
│   ├── easyconnect.sh : 主逻辑 from [docker-easyconnect][1] and [easyconnect-in-docker][2]
│   ├── easyconn_resources_x64_7.6-378.tar.gz : ec资源包 packed from get_cli_resources.sh, 7.85MB
│   ├── get_cli_resources.sh : 下载并打包ec资源包
│   └── readme.md
├── Dockerfile.dev : 开发用基础镜像
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
    -v verbose: 默认添加方便DEBUG，可用QUIET
	```
	例如 `CLI_OPTS="-d 服务器地址 -u 用户名 -p 密码"` 可实现原登录信息失效时自动登录。
- `SOCKS_USER`: 默认为空，为dantd添加连接认证
- `SOCKS_PASSWD`: 默认为空，为dantd添加连接认证
- `NODANTED`: 不启动sockd服务器
- `MAX_RETRY`: 最大尝试登录次数，默认为5
- `IPTABLES`: 设置IPTABLES
- `IPTABLES_LEGACY`: 不支持 nftables 时使用 iptables-legacy
- `QUIET`: 减少运行中stdout
```
docker run --device /dev/net/tun --cap-add NET_ADMIN -t -i -p 1080:1080 -e VERSION=7.6.8 -e CLI_OPTS="-d <address> -u <username> -p <password>" --name='ec' ultranity/easyconnect:cli
```
以后只需要 `docker start ec`

## alpine等无默认tun设备的宿主机建立tun
```bash
    mkdir -p /dev/net
    rm /dev/net/tun
    mknod /dev/net/tun c 10 200
    chmod 600 /dev/net/tun
```

## 开放端口路由
使开放端口无法被宿主机外的设备直接访问，
来自 [docker-easyconnect][1]

### 在宿主机处解决

将传入连接的源地址转换成宿主机地址：

``` bash
container_ip=docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 容器名
iptables -I POSTROUTING -d ${container_ip} -p tcp -m tcp --dport 容器侧端口号 -j MASQUERADE -t nat
```

或者大胆一点直接对docker0子网做转换
``` bash
iptables -I POSTROUTING -d 172.17.0.0/8 -p tcp -m tcp -j MASQUERADE -t nat
```

# 记录
## 打包
### ultranity/easyconnect:alpine =>
glibc 2.35-r0 有bug缺少``*_chk`入口，待修复前使用2.34

alpine-pkg-glibc 2.34-r0 完美运行

### ultranity/easyconnect:alpine-gcompact =>
gcompact官方推荐,有apk源支持体积更小（ 解压后34.6MB）&使用更方便，大多情况可用，但当前缺少部分函数
```
    Error relocating /usr/share/sangfor/EasyConnect/resources/bin/svpnservice: __strdup: symbol not found
    Error relocating /usr/share/sangfor/EasyConnect/resources/bin/svpnservice: __stpcpy_chk: symbol not found
    Error relocating /usr/share/sangfor/EasyConnect/resources/bin/svpnservice: __getpagesize: symbol not found
    Error relocating /usr/share/sangfor/EasyConnect/resources/bin/svpnservice: __strcat_chk: symbol not found
    Error relocating /usr/share/sangfor/EasyConnect/resources/bin/svpnservice: backtrace: symbol not found
    Error relocating /usr/share/sangfor/EasyConnect/resources/bin/svpnservice: backtrace_symbols_fd: symbol not found
    Error relocating /usr/share/sangfor/EasyConnect/resources/bin/svpnservice: __memcpy_chk: symbol not found
```
导致可用性不如 alpine-pkg-glibc
### ultranity/easyconnect:buster =>
docker中chown会新增layer克隆文件导致镜像变大,对此以及其他部分优化的成果，换用minideb 可以比debian-slim小一点点（~2MB），ubuntu-essential还能更小些。

### ultranity/easyconnect:distroless =>
利用gcr.io/distroless 提供无包管理等功能的基本debian环境。
### ultranity/easyconnect:cli =>
distroless+多阶段构建+squash into scratch!!!基本上是最优方案了，dpkg 安装利用解包技巧。

### ultranity/easyconnect:docker-slim =>
docker-slim 调用fanotify监控文件调用实现image精简, 所得包有点过于极限需要内置充分场景测试，但可以达到理论最优。

### ultranity/easyconnect:slim =>
反过来从原镜像移除apt、dpkg等装完包后无用的依赖，利用squash into scratch技巧同样可以实现精简，且可控

## 其它

使用libpam代替user方案实现dante-sever 加密认证 [danted – .bashrc](https://bashrc.xyz/tag/danted/)

## bin精简
/usr/bin/tini-static 无用

psmisc 只用到killall

busybox 可代替 coreutils、debian-utils等包

## 对比
| name|tag|size|COMPRESSED SIZE |
|-|-|-|-|
|busybox                |glibc         |4.79MB| |
|alpine                 |latest        |5.54MB| |
|debian                 |buster-slim   |69.3MB| |
|distroless/cc-debian10 |latest        |21.2MB| |
|hagb/docker-easyconnect|cli           |~100MB|36.71 MB|
|ultranity/easyconnect  |buster        |95.4MB|35.43 MB|
|ultranity/easyconnect  |slim          |42.9MB|16.79 MB|
|ultranity/easyconnect  |alpine        |41.6MB|16.06 MB|
|ultranity/easyconnect  |distroless    |  64MB|25.12 MB|
|ultranity/easyconnect  |cli           |  40MB|15.56 MB|
|ultranity/easyconnect  |docker-slim   |  35MB| |
~~|ultranity/easyconnect  |alpine-gcompat|34.6MB| |~~


# 参考致谢
[1]: https://github.com/Hagb/docker-easyconnect
[2]: https://github.com/shmilee/scripts/tree/master/easyconnect-in-docker
[3]: https://github.com/sgerrand/alpine-pkg-glibc
