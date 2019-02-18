#!/bin/bash

Green_font="\033[32m" && Red_font="\033[31m" && Font_suffix="\033[0m"
Info="${Green_font}[Info]${Font_suffix}"
Error="${Red_font}[Error]${Font_suffix}"

# check env
[[ -z "`cat /etc/redhat-release | grep -iE "CentOS"`" ]] && echo -e "${Error} Only support CentOS!" && exit 1
[[ "`uname -m`" != "x86_64" ]] && echo -e "${Error} Only support 64bit!" && exit 1
[[ "`id -u`" != "0" ]] && echo -e "${Error} Must be root user!" && exit 1

# install shadowsocks
yum install -y python-setuptools
easy_install pip
pip install shadowsocks

# disable selinux
if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
	sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
	setenforce 0
fi

# disable iptables&firewalld
service iptables stop
chkconfig iptables off
systemctl stop firewalld
systemctl disable firewalld

# set up config
echo -e "请输入你想要的VPN密码，然后回车"
read -p "(若不输入，默认使用 1234567890):" passwd
[ -z "${passwd}" ] && passwd="1234567890"

cat > /etc/shadowsocks.json << EOF
{
"server":"0.0.0.0",
"server_port":8388,
"local_address": "127.0.0.1",
"local_port":1080,
"password":"$passwd",
"timeout":300,
"method":"rc4-md5",
"fast_open":false
}
EOF

cat > /root/restart.sh << EOF
#!/bin/bash
ssserver -c /etc/shadowsocks.json -d stop
sleep 5
ssserver -c /etc/shadowsocks.json -d start
EOF
echo "1 4 * * 5    /bin/sh /root/restart.sh > /root/restart.log 2>&1" > /var/spool/cron/root
systemctl restart crond

# start
/usr/bin/ssserver -c /etc/shadowsocks.json -d start

# print msg
IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
[ -z ${IP} ] && IP=$( wget -qO- icanhazip.com )
[ -z ${IP} ] && IP=$( wget -qO- ipinfo.io/ip )

if [[ ! -z `ps -A | grep ssserver` ]];then
    echo -e "${Info} Shadowsocks install successful!"
	echo "========牢记以下信息========"
	echo "服务器地址：${IP}"
	echo "服务器端口：8388"
	echo "密码：${passwd}"
	echo "加密：rc4-md5"
	echo "============================"
else 
	echo -e "${Error} Shadowsocks install failed!"
fi
