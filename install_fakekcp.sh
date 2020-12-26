#!/bin/bash

blue(){
    echo -e "\033[34m\033[01m$1\033[0m"
}
green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}
red(){
    echo -e "\033[31m\033[01m$1\033[0m"
}
yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

logcmd(){
    eval $1 | tee -ai /var/atrandys.log
}

randpwd(){
    mpasswd=$(cat /dev/urandom | head -1 | md5sum | head -c 4)
    echo ${mpasswd}  
}

rand(){
    min=$1
    max=$(($2-$min+1))
    num=$(cat /dev/urandom | head -n 10 | cksum | awk -F ' ' '{print $1}')
    echo $(($num%$max+$min))  
}

source /etc/os-release
RELEASE=$ID
VERSION=$VERSION_ID
cat >> /usr/src/atrandys.log <<-EOF
== Script: atrandys/xray/install.sh
== Time  : $(date +"%Y-%m-%d %H:%M:%S")
== OS    : $RELEASE $VERSION
== Kernel: $(uname -r)
== User  : $(whoami)
EOF
sleep 2s
check_release(){
    green "$(date +"%Y-%m-%d %H:%M:%S") ==== 检查系统版本"
    if [ "$RELEASE" == "centos" ]; then
        systemPackage="yum"
        yum install -y wget
        if  [ "$VERSION" == "6" ] ;then
            red "$(date +"%Y-%m-%d %H:%M:%S") - 暂不支持CentOS 6.\n== Install failed."
            exit
        fi
        if  [ "$VERSION" == "5" ] ;then
            red "$(date +"%Y-%m-%d %H:%M:%S") - 暂不支持CentOS 5.\n== Install failed."
            exit
        fi
        if [ -f "/etc/selinux/config" ]; then
            CHECK=$(grep SELINUX= /etc/selinux/config | grep -v "#")
            if [ "$CHECK" == "SELINUX=enforcing" ]; then
                green "$(date +"%Y-%m-%d %H:%M:%S") - SELinux状态非disabled,关闭SELinux."
                setenforce 0
                sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
                #loggreen "SELinux is not disabled, add port 80/443 to SELinux rules."
                #loggreen "==== Install semanage"
                #logcmd "yum install -y policycoreutils-python"
                #semanage port -a -t http_port_t -p tcp 80
                #semanage port -a -t http_port_t -p tcp 443
                #semanage port -a -t http_port_t -p tcp 37212
                #semanage port -a -t http_port_t -p tcp 37213
            elif [ "$CHECK" == "SELINUX=permissive" ]; then
                green "$(date +"%Y-%m-%d %H:%M:%S") - SELinux状态非disabled,关闭SELinux."
                setenforce 0
                sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config
            fi
        fi
        firewall_status=`firewall-cmd --state`
        if [ "$firewall_status" == "running" ]; then
            green "$(date +"%Y-%m-%d %H:%M:%S") - FireWalld状态非disabled,添加80/443到FireWalld rules."
            firewall-cmd --zone=public --add-port=80/tcp --permanent
            firewall-cmd --zone=public --add-port=443/tcp --permanent
            firewall-cmd --reload
        fi
        yum install -y epel-release
    elif [ "$RELEASE" == "ubuntu" ]; then
        systemPackage="apt-get"
        if  [ "$VERSION" == "14" ] ;then
            red "$(date +"%Y-%m-%d %H:%M:%S") - 暂不支持Ubuntu 14.\n== Install failed."
            exit
        fi
        if  [ "$VERSION" == "12" ] ;then
            red "$(date +"%Y-%m-%d %H:%M:%S") - 暂不支持Ubuntu 12.\n== Install failed."
            exit
        fi
        ufw_status=`systemctl status ufw | grep "Active: active"`
        if [ -n "$ufw_status" ]; then
            ufw allow 80/tcp
            ufw allow 443/tcp
            ufw reload
        fi
        apt-get update >/dev/null 2>&1
    elif [ "$RELEASE" == "debian" ]; then
        systemPackage="apt-get"
        ufw_status=`systemctl status ufw | grep "Active: active"`
        if [ -n "$ufw_status" ]; then
            ufw allow 80/tcp
            ufw allow 443/tcp
            ufw reload
        fi
        apt-get update >/dev/null 2>&1
    else
        red "$(date +"%Y-%m-%d %H:%M:%S") - 当前系统不被支持. \n== Install failed."
        exit
    fi
}

check_port(){
    green "$(date +"%Y-%m-%d %H:%M:%S") ==== 检查端口"
    $systemPackage -y install net-tools
    Port443=`netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 443`
    if [ -n "$Port443" ]; then
        process443=`netstat -tlpn | awk -F '[: ]+' '$5=="443"{print $9}'`
        red "$(date +"%Y-%m-%d %H:%M:%S") - 443端口被占用,占用进程:${process443}\n== Install failed."
        exit 1
    fi
}

install_xray(){ 
    green "$(date +"%Y-%m-%d %H:%M:%S") ==== 安装xray"
    mkdir /usr/local/etc/xray/
    mkdir /usr/local/etc/xray/cert
    bash <(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
    cd /usr/local/etc/xray/
    rm -f config.json
    serverip=$(curl ipv4.icanhazip.com)
    v2uuid=$(cat /proc/sys/kernel/random/uuid)
    seed=$(randpwd)
cat > /usr/local/etc/xray/config.json<<-EOF
{
    "log": {
        "loglevel": "warning"
    }, 
    "inbounds": [
        {
            "listen": "127.0.0.1", 
            "port": 11234, 
            "protocol": "vless", 
            "settings": {
                "clients": [
                    {
                        "id": "$v2uuid", 
                        "email": "a@b.com"
                    }
                ], 
                "decryption": "none"
            }, 
            "streamSettings": {
                "network": "kcp", 
                "kcpSettings": {
                    "seed": "$seed"
                }
            }
        }
    ], 
    "outbounds": [
        {
            "protocol": "freedom", 
            "settings": { }
        }
    ]
}
EOF
    mkdir /usr/src/udp
    cd /usr/src/udp
    wget https://github.com/atrandys/wireguard/raw/master/udp2raw
    wget https://raw.githubusercontent.com/atrandys/wireguard/master/run.sh
    chmod +x udp2raw run.sh
    password=$(randpwd)


cat > /etc/wireguard/udp.sh <<-EOF
#!/bin/bash
nohup usr/src/udp/udp2raw -s -l0.0.0.0:443 -r 127.0.0.1:11234  --raw-mode faketcp  -a -k $password >udp2raw.log 2>&1 &
EOF

    chmod +x /etc/wireguard/udp.sh

#增加自启动脚本
cat > /etc/systemd/system/autoudp.service<<-EOF
[Unit]  
Description=autoudp 
After=network.target  
   
[Service]  
Type=forking
ExecStart=/etc/wireguard/udp.sh
ExecReload=/bin/kill -9 \$(pidof udp2raw) && /bin/kill -9 \$(pidof udpspeeder)
Restart=on-failure
RestartSec=1s
   
[Install]  
WantedBy=multi-user.target
EOF

#设置脚本权限
    chmod +x /etc/systemd/system/autoudp.service
    systemctl enable autoudp.service
    systemctl start autoudp.service
    systemctl enable xray.service
    sed -i "s/User=nobody/User=root/;" /etc/systemd/system/xray.service
    systemctl daemon-reload
    systemctl restart xray

cat > /usr/local/etc/xray/myconfig.json<<-EOF
{
==xray配置==
IP：127.0.0.1
端口：443
id：${v2uuid}
加密：none
别名：自定义
传输协议：kcp
伪装类型：none
seed： ${seed}
==udp2raw==
IP：${serverip}
password：${password}
raw-mode：faketcp
}
EOF

    green "== 安装完成."
    green "==xray配置参数=="
    cat /usr/local/etc/xray/myconfig.json
    green "本次安装检测信息如下，如udp2raw与xray正常启动，表示安装正常："
    ps -aux | grep -e udp2raw -e xray
    
}

remove_xray(){
    green "$(date +"%Y-%m-%d %H:%M:%S") - 删除xray."
    systemctl stop xray.service
    systemctl disable xray.service
    rm -rf /usr/local/share/xray/ /usr/local/etc/xray/
    rm -f /usr/local/bin/xray
    rm -rf /etc/systemd/system/xray*
    rm -rf /etc/systemd/system/autoudp
    rm -rf /usr/src/udp
    green "xray & udp2raw has been deleted."
    
}

function start_menu(){
    clear
    green " ====================================================="
    green " 描述：xray + kcp + udp2raw一键安装脚本"
    green " 系统：支持centos7/debian9+/ubuntu16.04+     "
    green " 作者：atrandys  www.atrandys.com"
    green " ====================================================="
    echo
    green " 1. 安装 xray + kcp + udp2raw"
    green " 2. 更新 xray"
    red " 3. 删除 xray"
    green " 4. 查看配置参数"
    yellow " 0. Exit"
    echo
    read -p "输入数字:" num
    case "$num" in
    1)
    check_release
    check_port
    install_xray
    ;;
    2)
    bash <(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
    systemctl restart xray
    ;;
    3)
    remove_xray 
    ;;
    4)
    cat /usr/local/etc/xray/myconfig.json
    ;;
    0)
    exit 1
    ;;
    *)
    clear
    red "Enter a correct number"
    sleep 2s
    start_menu
    ;;
    esac
}

start_menu
