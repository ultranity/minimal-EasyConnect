#!/bin/bash
logfile=/tmp/deplog
:>$logfile
getDepends(){
   echo "fileName is" $1>>$logfile
   # use tr to del < >
   local ret=`apt-cache depends $1|grep Depends |cut -d: -f2 |tr -d "<>"|xargs`
   echo $ret|tee -a $logfile
}
# 需要获取其所依赖包的包
libs=${*:2}               # 或者用$1，从命令行输入库名字
all=$libs
# download libs dependen. deep in 3
i=0
while [ $i -lt ${1}  ] ; do
    let i++
    echo $i
    # download libs
    newlist=""
    for j in $libs; do
        echo checking $j
        added="$(getDepends $j)"
        newlist="$newlist $added"
    done
    newlist=`echo $newlist|tr " " "\n"|sort|uniq -u|xargs`
    apt install $newlist --reinstall -d -y
    comm=`echo '$all $newlist'|tr ' ' '\n'|sort | uniq -d`
    libs=`echo "$newlist $comm"|tr " " "\n" | sort | uniq -u`
    all="$all $libs"
    echo $libs 
    echo $all
done
echo finished
echo =================
cat $logfile
echo =================
echo ${*:2}
echo =================
echo $all
echo total `echo $all |tr " " "\n"| wc -l`