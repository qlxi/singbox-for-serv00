#!/bin/bash

## (1) Генерация случайных данных по умолчанию
DEFAULT_S5_USER="user_$(openssl rand -hex 3)"
DEFAULT_S5_PASS=$(openssl rand -hex 8)
DEFAULT_VLESS_UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || openssl rand -hex 16 | sed 's/\(........\)\(....\)\(....\)\(....\)\(............\)/\1-\2-\3-\4-\5/')
DEFAULT_HY2_PASS=$(openssl rand -hex 10)
DEFAULT_HY2_OBFS=$(openssl rand -hex 8)
DEFAULT_PORT_HY2=$((RANDOM % 1000 + 50000)) 

clear
echo -e "\e[1;34m--- Настройка Sing-box (Hysteria2 + VLESS + SOCKS5) ---\e[0m"
echo "Нажимайте Enter, чтобы использовать предложенные значения."
echo "------------------------------------------------"

# Ввод данных
read -p "IP-адрес или домен сервера: " SERVER_IP
[[ -z "$SERVER_IP" ]] && { echo -e "\e[1;31mОшибка: IP обязателен!\e[0m"; exit 1; }

read -p "SOCKS5 Пользователь [$DEFAULT_S5_USER]: " SOCKS5_USER
SOCKS5_USER="${SOCKS5_USER:-$DEFAULT_S5_USER}"

read -p "SOCKS5 Пароль [$DEFAULT_S5_PASS]: " SOCKS5_PASSWORD
SOCKS5_PASSWORD="${SOCKS5_PASSWORD:-$DEFAULT_S5_PASS}"

read -p "VLESS UUID [$DEFAULT_VLESS_UUID]: " VLESS_WS_UUID
VLESS_WS_UUID="${VLESS_WS_UUID:-$DEFAULT_VLESS_UUID}"

read -p "Hysteria2 Порт (UDP) [$DEFAULT_PORT_HY2]: " HY2_UDP_PORT
HY2_UDP_PORT="${HY2_UDP_PORT:-$DEFAULT_PORT_HY2}"

read -p "Hysteria2 Пароль [$DEFAULT_HY2_PASS]: " HY2_PASSWORD
HY2_PASSWORD="${HY2_PASSWORD:-$DEFAULT_HY2_PASS}"

read -p "Hysteria2 OBFS Пароль [$DEFAULT_HY2_OBFS]: " HY2_OBFS_PASSWORD
HY2_OBFS_PASSWORD="${HY2_OBFS_PASSWORD:-$DEFAULT_HY2_OBFS}"

# Порты для SOCKS5 и VLESS (обычно фиксированные на serv00)
SOCKS5_TCP_PORT=26584
VLESS_WS_TCP_PORT=55031
VLESS_WS_PATH="/ray"

## (2) Подготовка папок и окружения
SB_DIR="$HOME/.syslogd"
SB_EXE=".service"

rm -rf $SB_DIR
mkdir -p $SB_DIR/certs
cd $SB_DIR

# Очистка старых задач cron
crontab -l | grep -v $SB_DIR | crontab -

# Скрипты управления
cat >start.sh <<EOF
#!/bin/bash
$SB_DIR/$SB_EXE run -c $SB_DIR/config.json
EOF
chmod +x start.sh

cat >start-nohup.sh <<EOF
#!/bin/bash
nohup $SB_DIR/start.sh >/dev/null 2>&1 &
EOF
chmod +x start-nohup.sh

cat >stop.sh <<EOF
#!/bin/bash
ps aux | grep $SB_EXE | grep -v grep | awk '{print \$2}' | xargs kill -9 2>/dev/null
EOF
chmod +x stop.sh

# Генерация сертификатов
openssl ecparam -genkey -name prime256v1 -out certs/private.key
openssl req -new -x509 -days 36500 -key certs/private.key -out certs/cert.crt -subj "/CN=www.microsoft.com"
chmod 644 certs/private.key certs/cert.crt

# Скачивание исполняемого файла
wget https://github.com/qlxi/singbox-for-serv00/releases/download/singbox/singbox -O $SB_EXE
chmod +x $SB_EXE

## (3) Создание конфигурации
cat >config.json <<EOF
{
  "log": { "level": "error" },
  "inbounds": [
    {
      "type": "socks",
      "tag": "socks-in",
      "listen": "::",
      "listen_port": $SOCKS5_TCP_PORT,
      "users": [{ "username": "$SOCKS5_USER", "password": "$SOCKS5_PASSWORD" }]
    },
    {
      "type": "vless",
      "tag": "vless-in",
      "listen": "::",
      "listen_port": $VLESS_WS_TCP_PORT,
      "users": [{ "uuid": "$VLESS_WS_UUID" }],
      "transport": { "type": "ws", "path": "$VLESS_WS_PATH" }
    },
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": $HY2_UDP_PORT,
      "users": [{ "password": "$HY2_PASSWORD" }],
      "tls": {
        "enabled": true,
        "server_name": "www.microsoft.com",
        "key_path": "$SB_DIR/certs/private.key",
        "certificate_path": "$SB_DIR/certs/cert.crt"
      },
      "obfs": {
        "type": "salamander",
        "password": "$HY2_OBFS_PASSWORD"
      },
      "up_mbps": 100,
      "down_mbps": 100,
      "ignore_client_bandwidth": true,
      "masquerade": "https://www.microsoft.com"
    }
  ],
  "outbounds": [
    { "tag": "direct", "type": "direct" },
    { "tag": "block", "type": "block" }
  ],
  "route": {
    "rules": [
      { "rule_set": "geosite-ads", "outbound": "block" },
      { "ip_is_private": true, "outbound": "direct" }
    ],
    "rule_set": [
      {
        "type": "remote",
        "tag": "geosite-ads",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/hiddify/hiddify-geo/rule-set/block/geosite-category-ads-all.srs",
        "download_detour": "direct"
      }
    ]
  }
}
EOF

## (4) Запуск
./stop.sh
./start-nohup.sh
sleep 2

# Проверка запуска
if pgrep -x "$SB_EXE" > /dev/null; then
  echo -e "\n\e[1;32mУспешно запущено!\e[0m"
else
  echo -e "\n\e[1;31mОшибка запуска. Проверьте порты в панели Serv00.\e[0m"
  exit 1
fi

# Установка cron для автозапуска
bash <(curl -s https://raw.githubusercontent.com/qlxi/singbox-for-serv00/main/singbox/check_cron_sb.sh)

## (5) Вывод всех ссылок
echo -e "\n\e[1;33m--- ГОТОВЫЕ КОНФИГИ ---\e[0m"

echo -e "\e[1;36m1. SOCKS5:\e[0m"
echo "socks://$SOCKS5_USER:$SOCKS5_PASSWORD@$SERVER_IP:$SOCKS5_TCP_PORT#serv00-socks"

echo -e "\n\e[1;36m2. VLESS + WebSocket:\e[0m"
echo "vless://$VLESS_WS_UUID@$SERVER_IP:$VLESS_WS_TCP_PORT?encryption=none&security=none&type=ws&path=$VLESS_WS_PATH#serv00-vless"

echo -e "\n\e[1;32m3. HYSTERIA2 (Рекомендуется для скорости):\e[0m"
echo "hysteria2://$HY2_PASSWORD@$SERVER_IP:$HY2_UDP_PORT/?sni=www.microsoft.com&insecure=1&obfs=salamander&obfs-password=$HY2_OBFS_PASSWORD#serv00-hy2"

echo -e "\n\e[1;30mВсе ссылки сохранены в файле: $SB_DIR/links.txt\e[0m"
echo "socks://$SOCKS5_USER:$SOCKS5_PASSWORD@$SERVER_IP:$SOCKS5_TCP_PORT#serv00-socks" > links.txt
echo "vless://$VLESS_WS_UUID@$SERVER_IP:$VLESS_WS_TCP_PORT?encryption=none&security=none&type=ws&path=$VLESS_WS_PATH#serv00-vless" >> links.txt
echo "hysteria2://$HY2_PASSWORD@$SERVER_IP:$HY2_UDP_PORT/?sni=www.microsoft.com&insecure=1&obfs=salamander&obfs-password=$HY2_OBFS_PASSWORD#serv00-hy2" >> links.txt
