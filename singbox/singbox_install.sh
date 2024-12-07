#!/bin/bash
##（1）节点配置
#服务端 IP 地址（仅用于输出节点链接）
SERVER_IP="s1.serv00.com"
#socks5 配置
SOCKS5_TCP_PORT=26584
SOCKS5_USER="nxhack"
SOCKS5_PASSWORD="dnCh2Cw4WdfbQHp4"
#vless+ws 配置
VLESS_WS_TCP_PORT=55031
VLESS_WS_UUID="4b8ba16b-7a7f-46a9-8575-7b0a5595fa02"
VLESS_WS_PATH="/ray"
#hysteria2 配置
HY2_UDP_PORT=55197
HY2_PASSWORD="hY7zME9p1vfmFHFT"

##（2）sing-box 安装和配置
#sing-box 安装路径
SB_DIR="$HOME/.sb"
#重命名 sing-box 程序名称
SB_EXE="sb-web"

#初始化
if [ -d "$SB_DIR" ]; then
  read -p "是否重装？，重装将会重置配置（Y/N 回车N）: " choice
  choice=${choice^^} # 转换为大写
  if [ "$choice" == "Y" ]; then
    echo "重装..."
    # 在这里添加重置数据的代码
  else
    echo "已取消重装..."
    exit 1
  fi
fi

#重置配置
#删除旧配置
rm -rf $SB_DIR
mkdir -p $SB_DIR
cd $SB_DIR
#删除相关定时任务（如果之前安装过）
crontab -l | grep -v $SB_DIR | crontab -
#创建启动运行和停止运行的相关脚本
cat >start.sh <<EOF
$SB_DIR/$SB_EXE run -c $SB_DIR/config.json
EOF
chmod +x start.sh
cat >start-nohup.sh <<EOF
nohup $SB_DIR/start.sh >/dev/null 2>&1 &
EOF
chmod +x start-nohup.sh
cat >stop.sh <<EOF
ps aux|grep $SB_EXE|grep -v grep | awk '{print \$2}'|xargs kill -9
EOF
chmod +x stop.sh
./stop.sh

input_value=""
read -p "请输入 服务端 IP 地址（默认：$SERVER_IP）: " input_value
SERVER_IP="${input_value:-$SERVER_IP}"
read -p "请输入 socks5 端口号（默认：$SOCKS5_TCP_PORT）: " input_value
SOCKS5_TCP_PORT="${input_value:-$SOCKS5_TCP_PORT}"
read -p "请输入 socks5 用户名（默认：$SOCKS5_USER）: " input_value
SOCKS5_USER="${input_value:-$SOCKS5_USER}"
read -p "请输入 socks5 密码（不能包含 @和:，默认：$SOCKS5_PASSWORD）: " input_value
SOCKS5_PASSWORD="${input_value:-$SOCKS5_PASSWORD}"
read -p "请输入 vless+ws 端口号（默认：$VLESS_WS_TCP_PORT）: " input_value
VLESS_WS_TCP_PORT="${input_value:-$VLESS_WS_TCP_PORT}"
read -p "请输入 vless+ws UUID（默认：$VLESS_WS_UUID）: " input_value
VLESS_WS_UUID="${input_value:-$VLESS_WS_UUID}"
read -p "请输入 vless+ws PATH（默认：$VLESS_WS_PATH）: " input_value
VLESS_WS_PATH="${input_value:-$VLESS_WS_PATH}"
read -p "请输入 hysteria2 端口号（默认：$HY2_UDP_PORT）: " input_value
HY2_UDP_PORT="${input_value:-$HY2_UDP_PORT}"
read -p "请输入 hysteria2 密码（默认：$HY2_PASSWORD）: " input_value
HY2_PASSWORD="${input_value:-$HY2_PASSWORD}"


#生成的自签证书，用于 hysteria2 节点
mkdir -p $SB_DIR/certs
cd $SB_DIR/certs
openssl ecparam -genkey -name prime256v1 -out private.key
openssl req -new -x509 -days 36500 -key private.key -out cert.crt -subj "/EN=time.android.com"
chmod 666 cert.crt
chmod 666 private.key

#下载 freebsd 版本的 sing-box（命名为 sb，目的是为了防止服务器检测）
cd $SB_DIR
wget https://github.com/qlxi/singbox-for-serv00/releases/download/singbox/singbox -O $SB_EXE
chmod +x $SB_EXE

cat >config.json <<EOF
{
  "inbounds": [
    {
      "type": "socks",
      "listen": "::",
      "listen_port": $SOCKS5_TCP_PORT,
      "users": [
        {
          "username": "$SOCKS5_USER",
          "password": "$SOCKS5_PASSWORD"
        }
      ]
    },
    {
      "type": "vless",
      "listen": "::",
      "listen_port": $VLESS_WS_TCP_PORT,
      "users": [
        {
          "uuid": "$VLESS_WS_UUID",
          "flow": ""
        }
      ],
      "transport": {
        "type": "ws",
        "path": "$VLESS_WS_PATH"
      }
    },
    {
      "type": "hysteria2",
      "listen": "::",
      "listen_port": $HY2_UDP_PORT,
      "users": [
        {
          "password": "$HY2_PASSWORD"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "time.android.com",
        "key_path": "$SB_DIR/certs/private.key",
        "certificate_path": "$SB_DIR/certs/cert.crt"
      },
      "masquerade": "https://time.android.com"
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "type": "direct"
    },
    {
      "tag": "block",
      "type": "block"
    }
  ],
  "route": {
    "rules": [
      {
        "rule_set": "geosite-ads",
        "outbound": "block"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      }
    ],
    "rule_set": [
      {
        "type": "remote",
        "tag": "geosite-ads",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/hiddify/hiddify-geo/rule-set/block/geosite-category-ads-all.srs",
        "download_detour": "direct",
        "update_interval": "120h0m0s"
      }
    ]
  }
}
EOF

##（3）后台启动
#后台启动
./start-nohup.sh
sleep 2
pgrep -x "$SB_EXE" >/dev/null && echo -e "\e[1;32m$SB_EXE is running\e[0m" || {
  echo -e "\e[1;35m$SB_EXE is not running...\e[0m"
  exit 1
}

##（4）添加 crontab 守护进程的计划任务
bash <(curl -s https://raw.githubusercontent.com/xtfree/singbox-for-serv00/main/singbox/check_cron_sb.sh)

##（5）将节点链接写入 links.txt 文件
rm -f links.txt
echo "vless+ws link：vless://$VLESS_WS_UUID@$SERVER_IP:$VLESS_WS_TCP_PORT?encryption=none&security=none&type=ws&path=$VLESS_WS_PATH#serv00-vless" >>$SB_DIR/links.txt
echo "socks5 link：socks://$SOCKS5_USER:$SOCKS5_PASSWORD@$SERVER_IP:$SOCKS5_TCP_PORT#serv00-socks" >>$SB_DIR/links.txt
echo "hysteria2 link：hysteria2://$HY2_PASSWORD@$SERVER_IP:$HY2_UDP_PORT/?sni=time.android.com&insecure=1#serv00-hy2" >>$SB_DIR/links.txt
