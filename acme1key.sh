#!/bin/bash

# 获取本机公网 IP
VPS_IP=$(curl -s http://ip-api.com/line?fields=query)

green(){
    echo -e "\033[32m\033[01m$1\033[0m"
}

yellow(){
    echo -e "\033[33m\033[01m$1\033[0m"
}

red(){
    echo -e "\033[31m$1\033[0m";
}

# 检查是否以 root 用户运行
if [[ $(id -u) != 0 ]]; then
    red "请在root用户下运行脚本"
    rm -f acme1key.sh
    exit 0
fi

# 根据发行版安装依赖
if [[ -f /etc/redhat-release ]]; then
    release="Centos"
elif cat /etc/issue | grep -q -E -i "debian"; then
    release="Debian"
elif cat /etc/issue | grep -q -E -i "ubuntu"; then
    release="Ubuntu"
fi

# 安装所需的依赖
function install_dependencies() {
    if [ "$release" = "Centos" ]; then
        yum -y update && yum install curl -y && yum install -y socat 
    else
        apt update -y && apt install curl -y && apt install -y socat
    fi
}

# 申请 SSL 证书
function acme(){
    install_dependencies
    curl https://get.acme.sh | sh

    # 获取用户邮箱和域名
    read -p "请输入注册邮箱：" email
    bash /root/.acme.sh/acme.sh --register-account -m ${email}

    read -p "输入需要申请SSL证书的域名：" domain

    # 使用 dig 获取域名的 IP 地址
    domainIP=$(dig +short "$domain" | head -n 1)

    # 打印 VPS 本机 IP 和域名解析到的 IP
    yellow "VPS本机IP：$VPS_IP"
    yellow "当前的域名解析到的IP：$domainIP"

    # 检查域名解析 IP 和 VPS 本机 IP 是否匹配
    if [ "$VPS_IP" = "$domainIP" ]; then
        # 判断是否是 IPv6
        if echo "$domainIP" | grep -q ":"; then
            bash /root/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256 --server letsencrypt --listen-v6
        else
            bash /root/.acme.sh/acme.sh --issue -d "$domain" --standalone -k ec-256 --server letsencrypt
        fi
        
        bash /root/.acme.sh/acme.sh --installcert -d "$domain" --key-file /root/private.key --fullchain-file /root/cert.crt --ecc
        green "域名证书（cert.crt）和私钥（private.key）已保存到 /root 文件夹，请注意保存"
    else
        red "域名解析IP不匹配"
        green "请确认DNS已正确解析到VPS，或CloudFlare的小云朵没关闭，请关闭小云朵后重试"
        exit 0
    fi
}

# 续期 SSL 证书
function renew(){
    read -p "请输入需要续期的域名：" domain
    bash /root/.acme.sh/acme.sh --renew -d "$domain" --force --ecc
}

# 更新脚本
function update(){
    wget -N https://raw.githubusercontent.com/vipmc838/acme/master/acme1key.sh && chmod -R 777 acme1key.sh && bash acme1key.sh
}

# 主菜单
function start_menu(){
    clear
    red "=================================="
    echo "                           "
    red "    Acme.sh 域名证书一键申请脚本     "
    red "          by 小御坂的破站           "
    echo "                           "
    red "  Site: https://blog.misaka.rest  "
    echo "                           "
    red "=================================="
    echo "                           "
    echo "1. 申请证书"
    echo "2. 续期证书"
    echo "v. 更新脚本"
    echo "0. 退出脚本"
    echo "                           "
    read -p "请输入数字:" menuNumberInput
    case "$menuNumberInput" in     
        1 ) acme ;;
        2 ) renew ;;
        v ) update ;;
        0 ) exit 0 ;;
    esac
}   

start_menu
