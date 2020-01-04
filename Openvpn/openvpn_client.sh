#!/bin/bash

api_url='https://oapi.dingtalk.com/robot/send?access_token=713504bfb79938ab486e77474cad9ad1fb5dc09181ec3d2f18f08cbe6ceef690'
D=`date "+%Y-%m-%d %H:%M"`
client_msg="[$D] ($local_port_1:$proto_1) $X509_0_CN: $trusted_ip => $ifconfig_pool_remote_ip"

iplist=`cat /etc/openvpn/server/iplist.conf `

for ip in ${iplist}
do

if [ $trusted_ip = $ip ];then
    echo "The current IP is an internal user!"
else
    echo "当前IP为陌生地址"
    curl $api_url -H 'Content-Type: application/json' -d "
    {
        'msgtype': 'text',
        'text': {
            'content': '钱包VPN登录警告\n登录时间：[$D]\n登录用户：$X509_0_CN \n登录IP地址：$trusted_ip \n请用户确认是否为陌生IP '
        },
        'at': {
            'isAtAll': false
        }
    }"
fi

done

echo ${client_msg} >> /var/log/openvpn/openvpn-client.log


