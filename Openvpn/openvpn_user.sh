#!/bin/bash
 para_num=$#
 operation=$1
 vpn_user=$2

 set -e

 OVPN_USER_KEYS_DIR=/etc/openvpn/client/keys
 EASY_RSA_VERSION=3
 EASY_RSA_DIR=/etc/openvpn/easy-rsa/
 PKI_DIR=$EASY_RSA_DIR/$EASY_RSA_VERSION/pki

 function help()
 {
    echo './openvpn_user.sh add username(vpn username)'
    echo './openvpn_user.sh del username(vpn username)'
 }

 function add_user()
 {
    if [ -d "$OVPN_USER_KEYS_DIR/$vpn_user" ]; then

    rm -rf $OVPN_USER_KEYS_DIR/$vpn_user
    rm -rf  $PKI_DIR/reqs/$vpn_user.req
    sed -i '/'"$vpn_user"'/d' $PKI_DIR/index.txt

    fi

    cd $EASY_RSA_DIR/$EASY_RSA_VERSION
    ./easyrsa build-client-full $vpn_user nopass
    mkdir -p  $OVPN_USER_KEYS_DIR/$vpn_user
    cp $PKI_DIR/ca.crt $OVPN_USER_KEYS_DIR/$vpn_user/   # CA 根证书
    cp $PKI_DIR/issued/$vpn_user.crt $OVPN_USER_KEYS_DIR/$vpn_user/   # 客户端证书
    cp $PKI_DIR/private/$vpn_user.key $OVPN_USER_KEYS_DIR/$vpn_user/  # 客户端证书密钥
    cp /etc/openvpn/server/certs/ta.key $OVPN_USER_KEYS_DIR/$vpn_user/ta.key

    cd $OVPN_USER_KEYS_DIR/$vpn_user
    generate_client_conf
    cp $OVPN_USER_KEYS_DIR/${vpn_user}/${vpn_user}.ovpn /etc/openvpn/client/

    echo "===============================success=================================="
    echo "add vpn user: $vpn_user success!"
    echo "===============================success=================================="

 }

 function del_user()
 {
    cd $EASY_RSA_DIR/$EASY_RSA_VERSION
    echo -e 'yes\n' | ./easyrsa revoke $vpn_user
    ./easyrsa gen-crl
    # 吊销掉证书后清理客户端相关文件
    if [ -d "$OVPN_USER_KEYS_DIR/$vpn_user" ]; then
        rm -rf $OVPN_USER_KEYS_DIR/${vpn_user}*
    fi
    rm -rf /etc/openvpn/client/${vpn_user}.*
    systemctl restart openvpn@server
    echo "================================success================================"
    echo "del vpn user: $vpn_user success!"
    echo "================================success================================"
 }

 function generate_client_conf()
 {
    # client path
    user_path=$OVPN_USER_KEYS_DIR/$vpn_user
    client_file=${user_path}/${vpn_user}.ovpn
    client_crt_file=${user_path}/${vpn_user}.crt
    client_key_file=${user_path}/${vpn_user}.key
    ca_crt_file=${user_path}/ca.crt
    ta_key_file=${user_path}/ta.key

    echo "client" > ${client_file}
    echo "dev tun" >> ${client_file}
    echo "proto udp" >> ${client_file}
    echo "remote 182.92.148.132 11194" >> ${client_file}
    echo "resolv-retry infinite" >> ${client_file}
    echo "nobind" >> ${client_file}
    echo "persist-key" >> ${client_file}
    echo "persist-tun" >> ${client_file}
    echo "compress lzo" >> ${client_file}
    echo "cipher AES-256-CBC" >> ${client_file}
    echo "auth SHA256" >> ${client_file}
    echo "key-direction 1" >> ${client_file}
    echo "remote-cert-tls server" >> ${client_file}
    echo "auth-user-pass" >> ${client_file}
    echo "verb 3" >> ${client_file}
    echo "mute-replay-warnings" >> ${client_file}

    echo "<ca>" >> ${client_file}
    cat ${ca_crt_file} >> ${client_file}
    echo "</ca>" >> ${client_file}

    echo "<cert>" >> ${client_file}
    tail -n 20 ${client_crt_file} >> ${client_file}
    echo "</cert>" >> ${client_file}

    echo "<key>" >> ${client_file}
    cat ${client_key_file} >> ${client_file}
    echo "</key>" >> ${client_file}

    echo "<tls-auth>" >> ${client_file}
    cat ${ta_key_file} >> ${client_file}
    echo "</tls-auth>" >> ${client_file}
 }

 function main()
 {
    if [ $para_num -ne 2 ];then
            echo "para is illegal!"
            help
            exit 1
    else
            if [ $operation = "add" ];then
                    add_user
            elif [ $operation = "del" ];then
                    del_user
            else
                    echo 'operation only support add | del'
                    help
                    exit 1
            fi
    fi
 }

 main
