#!/bin/bash
# $1 wait for volume
# $2 path of hook_script.sh
sleep ${1:-5}

## from deb postinst
EasyConnectDir=${EasyConnectDir:-/usr/share/sangfor/EasyConnect}
ResourcesDir=${EasyConnectDir}/resources
EASYCONN=${ResourcesDir}/bin/easyconn
DANTEDCONF=/etc/danted.conf
[ -f /etc/danted.conf ] || DANTEDCONF=/etc/sockd.conf
## run cmd in ${ResourcesDir}/bin
## from sslservice.sh EasyMonitor.sh
run_cmd() {
    local cmd=$1
    local background=${2:-foreground} # background, foreground
    local params="${@:3}"
    if [ ! -f "${ResourcesDir}/bin/$cmd" ]; then
        echo ">> '$cmd' not found in ${ResourcesDir}/bin!"
        exit 21
    fi
    pidof $cmd >/dev/null && killall $cmd
    pidof $cmd >/dev/null && killall -9 $cmd
    if [ x"$background" = "xbackground" ]; then
        echo "Run CMD: ${ResourcesDir}/bin/$cmd $params &"
        ${ResourcesDir}/bin/$cmd $params &
    else
        echo "Run CMD: ${ResourcesDir}/bin/$cmd $params"
        ${ResourcesDir}/bin/$cmd $params
    fi
    if [ $? -eq 0 ]; then
        echo "Start $cmd success!"
    else
        echo ">> Start $cmd fail"
        exit 22
    fi
}

## run CLI EC cmd easyconn
start_easyconn() {
    local params="-v "
    [ -n "$QUIET" ] && params=" "
    #[ -n "$ECADDRESS" ] && params+=" -d $ECADDRESS"
    #[ -n "$ECUSER" ] && params+=" -u $ECUSER"
    #[ -n "$ECPASSWD" ] && params+=" -p $ECPASSWD"
    params+="$CLI_OPTS"
    [ -n "$QUIET" ] || echo "Run CMD: $EASYCONN login $params"
    k=5
    (while [ ${k} -ge 0 ]; do
        local flag=0
        if [ -n "$QUIET" ]; then
            $EASYCONN login $params | grep -i FAIL
            flag=$?
        else
            echo "trying to login for less than ${k} times"
            $EASYCONN login $params |tee /tmp/login.log
            cat /tmp/login.log | grep -i FAIL
            flag=$?
            rm /tmp/login.log
        fi
        if [ $flag -ne 0 ]; then
            break
        else
            echo -e "\login failed, try again\n"
            $EASYCONN logout;
        fi
        sleep 3
    done)
    [ ${k} -ge 0 ] && echo login success ||exit 10
}

## from github.com/Hagb/docker-easyconnect/ start.sh
hook_iptables() { #{{{
    local interface=${1:-tun0}
    [ -n "$QUIET" ] || echo "Run hook_iptables"
    # 不支持 nftables 时使用 iptables-legacy
    # 感谢 @BoringCat https://github.com/Hagb/docker-easyconnect/issues/5
    if { [ -z "$IPTABLES_LEGACY" ] && iptables-nft -L 1>/dev/null 2>/dev/null ;}
    then
        ln -sf /usr/sbin/iptables-nft /usr/sbin/iptables 
        ln -sf /sbin/ip6tables-nft /usr/sbin/ip6tables 
    else
        ln -sf /usr/sbin/iptables-legacy /usr/sbin/iptables
        ln -sf /usr/sbin/ip6tables-legacy /usr/sbin/ip6tables 
    fi

    # https://github.com/Hagb/docker-easyconnect/issues/20
    # https://serverfault.com/questions/302936/configuring-route-to-use-the-same-interface-for-outbound-traffic-as-that-of-inbo
    iptables -t mangle -I OUTPUT -m state --state ESTABLISHED,RELATED -j CONNMARK --restore-mark
    iptables -t mangle -I PREROUTING -m connmark ! --mark 0 -j CONNMARK --save-mark
    iptables -t mangle -I PREROUTING -m connmark --mark 1 -j MARK --set-mark 1
    iptables -t mangle -I PREROUTING -i eth0 -j CONNMARK --set-mark 1
    (
    IFS=$'\n'
    for i in $(ip route show); do
        IFS=' '
        ip route add $i table 2
    done
    ip rule add fwmark 1 table 2
    )

    iptables -t nat -A POSTROUTING -o ${interface} -j MASQUERADE

    # 拒绝 interface tun0 侧主动请求的连接.
    iptables -I INPUT -p tcp -j REJECT
    iptables -I INPUT -i eth0 -p tcp -j ACCEPT
    iptables -I INPUT -i lo -p tcp -j ACCEPT
    iptables -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # 删除深信服可能生成的一条 iptables 规则，防止其丢弃传出到宿主机的连接
    # 感谢 @stingshen https://github.com/Hagb/docker-easyconnect/issues/6
    ( while true; do sleep 5 ; iptables -D SANGFOR_VIRTUAL -j DROP 2>/dev/null ; done ) &
} #}}}

hook_tinyproxy() {
:
}
## from github.com/Hagb/docker-easyconnect/ start.sh
hook_danted() {  #{{{
    local interface=${1:-tun0}
    echo "Run hook_danted with ${DANTEDCONF}"
    cat >${DANTEDCONF} <<EOF
internal: eth0 port = 1080
external: ${interface}
external: eth0
external: lo
external.rotation: route
socksmethod: none
clientmethod: none
user.privileged: root
user.notprivileged: nobody
client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
}
socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
}
EOF
    pidof sockd >/dev/null && killall sockd
    pidof sockd >/dev/null && killall -9 sockd
    # 增加身份验证 https://github.com/Hagb/docker-easyconnect
    if [[ -n "$SOCKS_PASSWD" && -n "$SOCKS_USER" ]];then
        cat >/etc/pam.d/sockd <<EOF
auth required pam_pwdfile.so pwdfile /etc/dante.passwd
account required pam_permit.so
EOF
        echo "$SOCKS_USER:$(mkpasswd --method=md5 $SOCKS_PASSWD)">/etc/dante.passwd
        sed -i 's/socksmethod: none/socksmethod: pam.username/g' ${DANTEDCONF}
        [ -n "$QUIET" ] &&  echo "use socks5 auth: $SOCKS_USER" || echo "use socks5 auth: $SOCKS_USER:$SOCKS_PASSWD"
    fi
    (while true; do
        if [ -d /sys/class/net/${interface} ]; then
            sockd -D -f ${DANTEDCONF}
            echo -e "\nstart danted\n"
            break
        fi
        sleep 3
    done) &
} #}}}

## use conf in resources/conf-v$VERSION
hook_resources_conf() {
    if [ x"$VERSION" = x"7.6.3" ] || [ x"$VERSION" = x"7.6.7" ] || [ x"$VERSION" = x"7.6.8" ]; then
        :
    else
        echo ">> Not supported EC version: $VERSION"
        exit 51
    fi
    echo "Run hook_resources_conf"
    if [ ! -d "${ResourcesDir}/conf-v$VERSION" ]; then
        echo ">> ${ResourcesDir}/conf-v$VERSION/ not found!"
        exit 52
    fi
    rm -f -v ${ResourcesDir}/conf
    ln -sf -v conf-v$VERSION ${ResourcesDir}/conf
    if [ -f /root/.easyconn ]; then
        ln -sf -v /root/.easyconn ${ResourcesDir}/conf/.easyconn
    fi
}

## main
main() {
    echo "Running default main ..."
    hook_resources_conf

    [ -n "$NOIPTABLES" ] || hook_iptables tun0 # IPTABLES_LEGACY=

    run_cmd ECAgent background --resume
    start_easyconn
    [ -n "$NODANTED" ] || hook_danted tun0  # -p xxx:1080
    [ -n "$NOtinyproxy" ] || hook_tinyproxy tun0  # -p xxx:1080
    
    [ -n "$QUIET" ] || $EASYCONN query
    
    keep='K'
    while true; do
        read -p " -> Enter 'XXX' to exit:" keep
        if [ x"$keep" == x'XXX' ]; then
            break
        elif [ x"$keep" == x'RRR' ]
            [ -n "$QUIET" ] || echo "Reloading"
            $EASYCONN logout
            start_easyconn
        else
            $keep
        fi
    done
    [ -n "$QUIET" ] || echo "Run CMD: ${EASYCONN} logout"
    $EASYCONN logout
}

## source hook script, add functions & reload change_authority, main etc.
hook_script="${2:-${EasyConnectDir}/hook_script.sh}"
if [ -f "$hook_script" ]; then
    echo "source hook_script.sh ..."
    source $hook_script
fi

main
