#!/bin/bash
## (1) Настройка узлов
# IP-адрес сервера (используется только для вывода ссылки на узел)
SERVER_IP="s1.serv00.com"
# Настройка SOCKS5
SOCKS5_TCP_PORT=26584
SOCKS5_USER="nxhack"
SOCKS5_PASSWORD="dnCh2Cw4WdfbQHp4"
# Настройка vless+ws
VLESS_WS_TCP_PORT=55031
VLESS_WS_UUID="4b8ba16b-7a7f-46a9-8575-7b0a5595fa02"
VLESS_WS_PATH="/ray"
# Настройка hysteria2
HY2_UDP_PORT=55197
HY2_PASSWORD="hY7zME9p1vfmFHFT"

## (2) Установка и настройка sing-box
# Путь установки sing-box
SB_DIR="$HOME/.syslogd"
# Переименование программы sing-box
SB_EXE=".service"

# Инициализация
if [ -d "$SB_DIR" ]; then
  read -p "Хотите переустановить? Переустановка сбросит настройки (Y/N, по умолчанию N): " choice
  choice=${choice^^} # Преобразование в верхний регистр
  if [ "$choice" == "Y" ]; then
    echo "Переустановка..."
    # Здесь добавьте код для сброса данных
  else
    echo "Переустановка отменена..."
    exit 1
  fi
fi

# Сброс настроек
# Удаление старых настроек
rm -rf $SB_DIR
mkdir -p $SB_DIR
cd $SB_DIR
# Удаление связанных с этим заданий (если ранее были установлены)
crontab -l | grep -v $SB_DIR | crontab -
# Создание сценариев для запуска и остановки
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
read -p "Введите IP-адрес сервера (по умолчанию: $SERVER_IP): " input_value
SERVER_IP="${input_value:-$SERVER_IP}"
read -p "Введите порт SOCKS5 (по умолчанию: $SOCKS5_TCP_PORT): " input_value
SOCKS5_TCP_PORT="${input_value:-$SOCKS5_TCP_PORT}"
read -p "Введите имя пользователя SOCKS5 (по умолчанию: $SOCKS5_USER): " input_value
SOCKS5_USER="${input_value:-$SOCKS5_USER}"
read -p "Введите пароль SOCKS5 (не должен содержать @ и :, по умолчанию: $SOCKS5_PASSWORD): " input_value
SOCKS5_PASSWORD="${input_value:-$SOCKS5_PASSWORD}"
read -p "Введите порт vless+ws (по умолчанию: $VLESS_WS_TCP_PORT): " input_value
VLESS_WS_TCP_PORT="${input_value:-$VLESS_WS_TCP_PORT}"
read -p "Введите UUID vless+ws (по умолчанию: $VLESS_WS_UUID): " input_value
VLESS_WS_UUID="${input_value:-$VLESS_WS_UUID}"
read -p "Введите путь vless+ws (по умолчанию: $VLESS_WS_PATH): " input_value
VLESS_WS_PATH="${input_value:-$VLESS_WS_PATH}"
read -p "Введите порт hysteria2 (по умолчанию: $HY2_UDP_PORT): " input_value
HY2_UDP_PORT="${input_value:-$HY2_UDP_PORT}"
read -p "Введите пароль hysteria2 (по умолчанию: $HY2_PASSWORD): " input_value
HY2_PASSWORD="${input_value:-$HY2_PASSWORD}"

# Генерация самоподписанного сертификата для узла hysteria2
mkdir -p $SB_DIR/certs
cd $SB_DIR/certs
openssl ecparam -genkey -name prime256v1 -out private.key
openssl req -new -x509 -days 36500 -key private.key -out cert.crt -subj "/EN=time.android.com"
chmod 666 cert.crt
chmod 666 private.key

# Скачивание версии sing-box для FreeBSD (переименован в sb, чтобы избежать обнаружения сервером)
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

## (3) Запуск в фоновом режиме
# Запуск в фоновом режиме
./start-nohup.sh
sleep 2
pgrep -x "$SB_EXE" >/dev/null && echo -e "\e[1;32m$SB_EXE работает\e[0m" || {
  echo -e "\e[1;35m$SB_EXE не работает...\e[0m"
  exit 1
}

## (4) Добавление планового задания для cron
bash <(curl -s https://raw.githubusercontent.com/qlxi/singbox-for-serv00/main/singbox/check_cron_sb.sh)

## (5) Запись ссылок на узлы в файл links.txt
rm -f links.txt
echo "Ссылка vless+ws：vless://$VLESS_WS_UUID@$SERVER_IP:$VLESS_WS_TCP_PORT?encryption=none&security=none&type=ws&path=$VLESS_WS_PATH#serv00-vless" >>$SB_DIR/links.txt
echo "Ссылка socks5：socks://$SOCKS5_USER:$SOCKS5_PASSWORD@$SERVER_IP:$SOCKS5_TCP_PORT#serv00-socks" >>$SB_DIR/links.txt
echo "Ссылка hysteria2：hysteria2://$HY2_PASSWORD@$SERVER_IP:$HY2_UDP_PORT/?sni=time.android.com&insecure=1#serv00-hy2" >>$SB_DIR/links.txt
