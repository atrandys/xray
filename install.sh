#!/bin/bash
#Date   : 18:00 2021-11-16
#Author : atrandys
#Bolg   : https://atrandys.com
#Version: 1.0

EchoB(){
    echo -e "\033[34m\033[01m$1\033[0m$2"
}

EchoG(){
    echo -e "\033[32m\033[01m$1\033[0m$2"
}

EchoR(){
    echo -e "\033[31m\033[01m$1\033[0m$2"
}

EchoY(){
    echo -e "\033[33m\033[01m$1\033[0m$2"
}

CheckRelease(){
    source /etc/os-release
    RELEASE=$ID
    VERSION=$VERSION_ID
    if [ "$RELEASE" == "centos" ]; then
        if [[ "56" =~ "$VERSION" ]]; then
		    EchoR "[error]脚本不支持当前系统."
			exit
		fi
        systemPackage="yum" && yum install -y wget epel-release
        if [[ -f "/etc/selinux/config" && "$(grep SELINUX= /etc/selinux/config | grep -v "#")" != "SELINUX=disabled" ]]; then
            setenforce 0
            sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
        fi
        if [ "$(firewall-cmd --state:-'no')" == "running" ]; then
            #EchoG "添加放行80/443端口规则."
            firewall-cmd --zone=public --add-port=80/tcp --permanent
            firewall-cmd --zone=public --add-port=443/tcp --permanent
            firewall-cmd --reload
        fi
    elif [[ "ubuntudebian" =~ "$RELEASE" ]]; then
        systemPackage="apt-get"
        if [[ "12 14" =~ "$VERSION" ]]; then
		    EchoR "[error]脚本不支持当前系统."
			exit
		fi
        if [ -n "$(systemctl status ufw | grep "Active: active":-'')" ]; then
		    #EchoG "添加放行80/443端口规则."
            ufw allow 80/tcp
            ufw allow 443/tcp
            ufw reload
        fi
        apt-get update
    else
        EchoR "[error]当前系统不被支持."
        exit
    fi
	EchoG "[1]系统检查通过"
}

CheckPort(){
    $systemPackage -y install net-tools
    if [[ -n "$(netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 80)" || -n "$(netstat -tlpn | awk -F '[: ]+' '$1=="tcp"{print $5}' | grep -w 443)" ]]; then
        EchoR "[error]80/443端口被占用，退出脚本."
        exit
    fi
	EchoG "[2]端口检查通过"
}

CheckDomain(){
    $systemPackage install -y wget curl unzip
	EchoB "输入已解析到VPS的域名，请不要带https://或http://，例如可以输入：" "atrandys.com" 
    EchoB "请输入域名:"
    read yourDomain
 #   realAddr=`ping ${yourDomain} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`
    localAddr=`curl ipv4.icanhazip.com`
    if [ `host "$yourDomain" | grep "$localAddr" | wc -l` -gt 0 ] ; then
        EchoG "[3]域名验证通过."
    else
        EchoR "[error]域名解析地址与VPS IP地址不匹配，可能的原因："
		EchoY "1.不可开启CDN"
		EchoY "2.解析还未生效"
		EchoY "3.输入的域名有误"
        read -p "若无上述问题，强制安装?是否继续 [Y/n] :" yn
        [ -z "${yn}" ] && yn="y"
        if [[ $yn == [Yy] ]]; then
            EchoG "开始强制申请域名证书，但可能不成功."
        else
            exit 1
        fi
    fi
}

InstallNginx(){
    $systemPackage install -y nginx
    if [ ! -d "/etc/nginx" ]; then
        EchoR "[error]nginx没有安装成功."
        exit 1
    fi
   
   
cat > /etc/nginx/conf.d/default.conf<<-EOF
 server {
    listen       127.0.0.1:37212;
    server_name  $yourDomain;
    root /usr/share/nginx/html;
    index index.php index.html index.htm;
}
 server {
    listen       127.0.0.1:37213 http2;
    server_name  $yourDomain;
    root /usr/share/nginx/html;
    index index.php index.html index.htm;
}
    
server { 
    listen       0.0.0.0:80;
    server_name  $yourDomain;
    root /usr/share/nginx/html/;
    index index.php index.html;
}
EOF
    systemctl enable nginx.service
    systemctl restart nginx.service
	EchoG "[4]nginx安装完成"
}

CreateCert(){
	$systemPackage -y install socat
	curl https://get.acme.sh | sh
	~/.acme.sh/acme.sh  --register-account  -m test@$yourDomain --server zerossl
	~/.acme.sh/acme.sh  --issue  -d $yourDomain  --webroot /usr/share/nginx/html/
	if test -s /root/.acme.sh/$yourDomain/fullchain.cer; then
		EchoG "[5]申请证书成功."
	else
		EchoR "[error]申请证书失败，开始尝试使用standalone模式申请。"
		systemctl stop nginx
		~/.acme.sh/acme.sh  --issue  -d $yourDomain  --standalone
		systemctl start nginx
		if test -s /root/.acme.sh/$yourDomain/fullchain.cer; then
			EchoG "[info]standalone模式申请证书成功."
		else
			EchoR "[error]standalone模式申请证书失败，请稍后自行申请并相应命名，置于以下路径："
			EchoG "/usr/local/etc/xray/cert/fullchain.cer"
			EchoG "/usr/local/etc/xray/cert/private.key"
		fi
	fi		
}

InstallXray(){ 
    mkdir /usr/local/etc/xray/
    mkdir /usr/local/etc/xray/cert
    bash <(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
    cd /usr/local/etc/xray/
    rm -f config.json
    v2uuid=$(cat /proc/sys/kernel/random/uuid)
cat > /usr/local/etc/xray/config.json<<-EOF
{
    "log": {
        "loglevel": "error"
    }, 
    "inbounds": [
        {
            "listen": "0.0.0.0", 
            "port": 443, 
            "protocol": "vless", 
            "settings": {
                "clients": [
                    {
                        "id": "$v2uuid", 
                        "level": 0, 
                        "email": "a@b.com",
                        "flow":"xtls-rprx-direct"
                    }
                ], 
                "decryption": "none", 
                "fallbacks": [
                    {
                        "dest": 37212
                    }, 
                    {
                        "alpn": "h2", 
                        "dest": 37213
                    }
                ]
            }, 
            "streamSettings": {
                "network": "tcp", 
                "security": "xtls", 
                "xtlsSettings": {
                    "serverName": "$yourDomain", 
                    "alpn": [
                        "h2", 
                        "http/1.1"
                    ], 
                    "certificates": [
                        {
                            "certificateFile": "/usr/local/etc/xray/cert/fullchain.cer", 
                            "keyFile": "/usr/local/etc/xray/cert/private.key"
                        }
                    ]
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
cat > /usr/local/etc/xray/client.json<<-EOF
{
    "log": {
        "loglevel": "warning"
    },
    "inbounds": [
        {
            "port": 1080,
            "listen": "127.0.0.1",
            "protocol": "socks",
            "settings": {
                "udp": true
            }
        }
    ],
    "outbounds": [
        {
            "protocol": "vless",
            "settings": {
                "vnext": [
                    {
                        "address": "$yourDomain",
                        "port": 443,
                        "users": [
                            {
                                "id": "$v2uuid",
                                "flow": "xtls-rprx-direct",
                                "encryption": "none",
                                "level": 0
                            }
                        ]
                    }
                ]
            },
            "streamSettings": {
                "network": "tcp",
                "security": "xtls",
                "xtlsSettings": {
                    "serverName": "$yourDomain"
                }
            }
        }
    ]
}
EOF
    if [ -d "/usr/share/nginx/html/" ]; then
        cd /usr/share/nginx/html/ && rm -f ./*
        wget https://github.com/atrandys/trojan/raw/master/fakesite.zip
        unzip -o fakesite.zip
    fi
    systemctl enable xray.service
    sed -i "s/User=nobody/User=root/;" /etc/systemd/system/xray.service
    systemctl daemon-reload
    ~/.acme.sh/acme.sh  --installcert  -d  $yourDomain   \
        --key-file   /usr/local/etc/xray/cert/private.key \
        --fullchain-file  /usr/local/etc/xray/cert/fullchain.cer \
        --reloadcmd  "chmod -R 777 /usr/local/etc/xray/cert"
	 systemctl restart xray.service

cat > /usr/local/etc/xray/myconfig.json<<-EOF
{
地址：${yourDomain}
端口：443
id：${v2uuid}
加密：none
流控：xtls-rprx-direct
别名：自定义
传输协议：tcp
伪装类型：none
底层传输：xtls
跳过证书验证：false
}
EOF

    EchoG "[6]Xray安装完成."
	echo
    EchoG "xray客户端配置文件存放路径: " "/usr/local/etc/xray/client.json"
    echo
    echo
    EchoG "xray配置参数:"
    cat /usr/local/etc/xray/myconfig.json
    
}



RemoveXray(){
    source /etc/os-release
    systemctl stop xray.service
    systemctl disable xray.service
    systemctl stop nginx
    systemctl disable nginx
    if [ "$ID" == "centos" ]; then
        yum remove -y nginx
    else
        apt-get -y autoremove nginx
        apt-get -y --purge remove nginx
        apt-get -y autoremove && apt-get -y autoclean
        find / | grep nginx | sudo xargs rm -rf
    fi
    rm -rf /usr/local/share/xray/ /usr/local/etc/xray/
    rm -f /usr/local/bin/xray
    rm -rf /etc/systemd/system/xray*
    rm -rf /etc/nginx
    rm -rf /usr/share/nginx/html/*
    rm -rf /root/.acme.sh/
    EchoG "nginx & xray has been deleted."
    
}

function StartMenu(){
    clear
    EchoG " ====================================================="
    EchoG " 描述：" "xray + tcp + xtls一键安装脚本"
    EchoG " 系统：" "支持centos7/debian9+/ubuntu16.04+     "
    EchoG " 作者：" "atrandys"
	EchoG " 博客：" "www.atrandys.com"
    EchoG " ====================================================="
    echo
    EchoG " 1. 安装 xray + tcp + xtls"
    EchoG " 2. 更新 xray"
    EchoR " 3. 删除 xray"
    EchoG " 4. 查看配置参数"
    EchoY " 0. Exit"
    echo
    read -p "输入数字:" num
    case "$num" in
    1)
	CheckRelease
	CheckPort
	CheckDomain
	InstallNginx
	CreateCert
	InstallXray
    ;;
    2)
    bash <(curl -L https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh)
    systemctl restart xray
    ;;
    3)
    RemoveXray
    ;;
    4)
    cat /usr/local/etc/xray/myconfig.json
    ;;
    0)
    exit 1
    ;;
    *)
    clear
    EchoR "Enter a correct number"
    sleep 2s
    StartMenu
    ;;
    esac
}

StartMenu
