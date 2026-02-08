#!/bin/bash
## (1) Настройка узлов
# IP-адрес сервера
SERVER_IP="s1.serv00.com"

# Генерация UUID для различных методов
generate_uuid() {
  # Пытаемся использовать системный uuidgen, если нет - генерируем сами
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen | tr '[:upper:]' '[:lower:]'
  else
    # Генерация UUID v4 вручную
    hex_chars="0123456789abcdef"
    uuid=""
    for i in {1..32}; do
      if [[ $i == 9 || $i == 14 || $i == 19 || $i == 24 ]]; then
        uuid+="-"
      fi
      char=${hex_chars:$((RANDOM % 16)):1}
      uuid+=$char
    done
    
    # Устанавливаем версию 4 (случайный UUID) и вариант 1
    # 4 в 13-й позиции (версия) и 8, 9, a, или b в 17-й позиции (вариант)
    uuid=${uuid:0:12}4${uuid:13:3}8${uuid:17}
    echo "$uuid"
  fi
}

# Генерация UUID для разных сервисов
VLESS_WS_UUID=$(generate_uuid)
SOCKS5_UUID=$(generate_uuid)  # UUID как пароль для SOCKS5
HY2_UUID=$(generate_uuid)     # UUID как пароль для Hysteria2

# Настройка портов
SOCKS5_TCP_PORT=26584
VLESS_WS_TCP_PORT=55031
HY2_UDP_PORT=55197

# Настройка путей и имен пользователей
VLESS_WS_PATH="/ray"
SOCKS5_USER="nxhack"  # Имя пользователя остается, пароль заменен на UUID

## (2) Установка и настройка sing-box
# Путь установки sing-box
SB_DIR="$HOME/.syslogd"
# Переименование программы sing-box
SB_EXE=".service"

# Инициализация
if [ -d "$SB_DIR" ]; then
  read -p "Хотите переустановить? Переустановка сбросит настройки (Y/N, по умолчанию N): " choice
  choice=${choice^^}
  if [ "$choice" == "Y" ]; then
    echo "Переустановка..."
  else
    echo "Переустановка отменена..."
    exit 1
  fi
fi

# Сброс настроек
rm -rf $SB_DIR
mkdir -p $SB_DIR
cd $SB_DIR
crontab -l | grep -v $SB_DIR | crontab -

# Функция для проверки и генерации UUID
validate_uuid() {
  local uuid="$1"
  # Проверяем формат UUID (8-4-4-4-12 hex символов)
  if [[ "$uuid" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
    echo "$uuid"
  else
    echo "$(generate_uuid)"
  fi
}

echo "=== Генерация UUID для всех сервисов ==="
echo "VLESS UUID: $VLESS_WS_UUID"
echo "SOCKS5 UUID (пароль): $SOCKS5_UUID"
echo "Hysteria2 UUID (пароль): $HY2_UUID"
echo ""

# Ввод параметров
input_value=""
read -p "Введите IP-адрес сервера (по умолчанию: $SERVER_IP): " input_value
SERVER_IP="${input_value:-$SERVER_IP}"
read -p "Введите порт SOCKS5 (по умолчанию: $SOCKS5_TCP_PORT): " input_value
SOCKS5_TCP_PORT="${input_value:-$SOCKS5_TCP_PORT}"
read -p "Введите имя пользователя SOCKS5 (по умолчанию: $SOCKS5_USER): " input_value
SOCKS5_USER="${input_value:-$SOCKS5_USER}"
read -p "Введите UUID для SOCKS5 (пароль) (по умолчанию сгенерирован): " input_value
SOCKS5_UUID="${input_value:-$SOCKS5_UUID}"
SOCKS5_UUID=$(validate_uuid "$SOCKS5_UUID")
read -p "Введите порт vless+ws (по умолчанию: $VLESS_WS_TCP_PORT): " input_value
VLESS_WS_TCP_PORT="${input_value:-$VLESS_WS_TCP_PORT}"
read -p "Введите UUID для vless+ws (по умолчанию сгенерирован): " input_value
VLESS_WS_UUID="${input_value:-$VLESS_WS_UUID}"
VLESS_WS_UUID=$(validate_uuid "$VLESS_WS_UUID")
read -p "Введите путь vless+ws (по умолчанию: $VLESS_WS_PATH): " input_value
VLESS_WS_PATH="${input_value:-$VLESS_WS_PATH}"
read -p "Введите порт hysteria2 (по умолчанию: $HY2_UDP_PORT): " input_value
HY2_UDP_PORT="${input_value:-$HY2_UDP_PORT}"
read -p "Введите UUID для hysteria2 (пароль) (по умолчанию сгенерирован): " input_value
HY2_UUID="${input_value:-$HY2_UUID}"
HY2_UUID=$(validate_uuid "$HY2_UUID")

# Создание сценариев для запуска и остановки
cat >start.sh <<EOF
#!/bin/bash
ulimit -n 65535 2>/dev/null || true
$SB_DIR/$SB_EXE run -c $SB_DIR/config.json
EOF
chmod +x start.sh

cat >start-nohup.sh <<EOF
#!/bin/bash
nohup $SB_DIR/start.sh > $SB_DIR/nohup.log 2>&1 &
echo \$! > $SB_DIR/pid.txt
EOF
chmod +x start-nohup.sh

cat >stop.sh <<EOF
#!/bin/bash
if [ -f "$SB_DIR/pid.txt" ]; then
  kill -9 \$(cat $SB_DIR/pid.txt) 2>/dev/null
  rm -f $SB_DIR/pid.txt
fi
ps aux | grep -v grep | grep "$SB_EXE" | awk '{print \$2}' | xargs kill -9 2>/dev/null
EOF
chmod +x stop.sh

# Остановка предыдущих процессов
./stop.sh

# Генерация сертификата с уникальным CN на основе UUID
mkdir -p $SB_DIR/certs
cd $SB_DIR/certs
CERT_CN="server-$(echo $HY2_UUID | cut -d'-' -f1).com"

echo "Генерация сертификата с CN: $CERT_CN"
openssl ecparam -genkey -name prime256v1 -out private.key 2>/dev/null
if [ $? -ne 0 ]; then
  openssl genrsa -out private.key 2048
  openssl req -new -x509 -days 365 -key private.key -out cert.crt -subj "/CN=$CERT_CN" -sha256
else
  openssl req -new -x509 -days 365 -key private.key -out cert.crt -subj "/CN=$CERT_CN" -sha256
fi
chmod 600 private.key
chmod 644 cert.crt

# Скачивание sing-box для FreeBSD
cd $SB_DIR
echo "Скачивание sing-box..."
wget -q --timeout=30 --tries=3 https://github.com/qlxi/singbox-for-serv00/releases/download/singbox/singbox -O $SB_EXE
chmod +x $SB_EXE

# Проверка наличия файла
if [ ! -f "$SB_EXE" ]; then
  echo "Ошибка: не удалось скачать sing-box"
  exit 1
fi

# Генерация obfs password на основе UUID (первые 16 символов без дефисов)
OBFS_PASSWORD=$(echo $HY2_UUID | tr -d '-' | cut -c 1-16)

# Создание конфига с UUID аутентификацией
cat >config.json <<EOF
{
  "log": {
    "level": "warn",
    "timestamp": true,
    "output": "$SB_DIR/singbox.log"
  },
  "inbounds": [
    {
      "type": "socks",
      "tag": "socks-in",
      "listen": "::",
      "listen_port": $SOCKS5_TCP_PORT,
      "users": [
        {
          "username": "$SOCKS5_USER",
          "password": "$SOCKS5_UUID"
        }
      ],
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "prefer_ipv4",
      "udp_enabled": true
    },
    {
      "type": "vless",
      "tag": "vless-in",
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
        "path": "$VLESS_WS_PATH",
        "headers": {
          "Host": "$CERT_CN"
        },
        "max_early_data": 2048
      },
      "sniff": true,
      "sniff_override_destination": true
    },
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": $HY2_UDP_PORT,
      "users": [
        {
          "password": "$HY2_UUID"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "$CERT_CN",
        "key_path": "$SB_DIR/certs/private.key",
        "certificate_path": "$SB_DIR/certs/cert.crt",
        "alpn": ["h3"],
        "min_version": "1.3"
      },
      "obfs": {
        "type": "salamander",
        "password": "$OBFS_PASSWORD"
      },
      "masquerade": {
        "type": "proxy",
        "proxy": {
          "url": "https://$CERT_CN",
          "rewrite_host": true
        }
      },
      "ignore_client_bandwidth": false,
      "up_mbps": 100,
      "down_mbps": 100,
      "recv_window_conn": 8388608,
      "recv_window_client": 33554432,
      "max_udp_relay_packet_size": 1400,
      "disable_mtu_discovery": false
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "type": "direct",
      "domain_strategy": "prefer_ipv4"
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
      },
      {
        "protocol": "dns",
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
        "update_interval": "24h"
      }
    ],
    "final": "direct"
  }
}
EOF

## (3) Запуск в фоновом режиме
echo "Запуск sing-box..."
./start-nohup.sh
sleep 5

# Проверка
if pgrep -x "$SB_EXE" >/dev/null; then
  echo -e "\e[1;32m✓ $SB_EXE успешно запущен\e[0m"
  echo "PID: $(cat $SB_DIR/pid.txt 2>/dev/null || pgrep -x "$SB_EXE")"
else
  echo -e "\e[1;31m✗ $SB_EXE не запущен. Проверьте логи...\e[0m"
  if [ -f "$SB_DIR/nohup.log" ]; then
    tail -20 "$SB_DIR/nohup.log"
  fi
  exit 1
fi

## (4) Добавление планового задания
cat >check_service.sh <<EOF
#!/bin/bash
SB_DIR="$SB_DIR"
SB_EXE="$SB_EXE"
LOG_FILE="\$SB_DIR/service.log"

if ! pgrep -x "\$SB_EXE" >/dev/null; then
  echo "\$(date): Сервис не запущен, перезапуск..." >> "\$LOG_FILE"
  cd "\$SB_DIR"
  ./stop.sh >/dev/null 2>&1
  sleep 1
  ./start-nohup.sh >/dev/null 2>&1
fi

# Очистка логов
if [ -f "\$SB_DIR/singbox.log" ]; then
  tail -1000 "\$SB_DIR/singbox.log" > "\$SB_DIR/singbox.log.tmp"
  mv "\$SB_DIR/singbox.log.tmp" "\$SB_DIR/singbox.log"
fi
EOF

chmod +x check_service.sh

# Добавление в cron
(crontab -l 2>/dev/null | grep -v "$SB_DIR/check_service.sh"; echo "*/5 * * * * $SB_DIR/check_service.sh >/dev/null 2>&1") | crontab -

## (5) Запись конфигурации
rm -f links.txt config-summary.txt

# Создание файла со всей конфигурацией
cat > $SB_DIR/config-summary.txt <<EOF
==================================================
           КОНФИГУРАЦИЯ СЕРВЕРА
==================================================
Дата создания: $(date)
IP сервера: $SERVER_IP
Домен TLS: $CERT_CN

==================================================
1. SOCKS5 ПРОКСИ
==================================================
Порт TCP: $SOCKS5_TCP_PORT
Имя пользователя: $SOCKS5_USER
Пароль (UUID): $SOCKS5_UUID
Поддержка UDP: Да

Ссылка SOCKS5:
socks://$SOCKS5_USER:$SOCKS5_UUID@$SERVER_IP:$SOCKS5_TCP_PORT#serv00-socks

==================================================
2. VLESS + WebSocket
==================================================
Порт TCP: $VLESS_WS_TCP_PORT
UUID: $VLESS_WS_UUID
Путь WS: $VLESS_WS_PATH
Хост: $CERT_CN

Ссылка VLESS:
vless://$VLESS_WS_UUID@$SERVER_IP:$VLESS_WS_TCP_PORT?encryption=none&security=none&type=ws&path=$VLESS_WS_PATH&host=$CERT_CN#serv00-vless

==================================================
3. HYSTERIA 2.0 (РЕКОМЕНДУЕТСЯ)
==================================================
Порт UDP: $HY2_UDP_PORT
Пароль (UUID): $HY2_UUID
TLS SNI: $CERT_CN
Obfs: salamander
Пароль obfs: $OBFS_PASSWORD
Скорость: 100 Mbps ↑/↓

Ссылка Hysteria2:
hysteria2://$HY2_UUID@$SERVER_IP:$HY2_UDP_PORT/?sni=$CERT_CN&insecure=1&obfs=salamander&obfs-password=$OBFS_PASSWORD&upmbps=100&downmbps=100#serv00-hy2

Команда для быстрого подключения:
curl -x socks5://$SOCKS5_USER:$SOCKS5_UUID@$SERVER_IP:$SOCKS5_TCP_PORT https://google.com

==================================================
УПРАВЛЕНИЕ СЕРВИСОМ
==================================================
Запуск:    $SB_DIR/start-nohup.sh
Остановка: $SB_DIR/stop.sh
Логи:      $SB_DIR/singbox.log
Конфиг:    $SB_DIR/config.json
Авто-перезапуск: каждые 5 минут
EOF

# Создание конфига для клиента Hysteria2
cat > $SB_DIR/client-hysteria2.yaml <<EOF
# Конфигурация клиента Hysteria2
server: $SERVER_IP:$HY2_UDP_PORT
auth: $HY2_UUID

tls:
  sni: $CERT_CN
  insecure: true
  alpn: h3

obfs:
  type: salamander
  password: $OBFS_PASSWORD

bandwidth:
  up: 100 mbps
  down: 100 mbps

fastOpen: true
lazyStart: true

socks5:
  listen: 127.0.0.1:1080
  disableUdp: false

http:
  listen: 127.0.0.1:8080
  user: proxy
  password: $SOCKS5_UUID

# Оптимизации для FreeBSD
udpIdleTimeout: 60s
maxUdpRelayPacketSize: 1400
EOF

# Создание конфига для клиента v2ray (VLESS)
cat > $SB_DIR/client-vless.json <<EOF
{
  "inbounds": [
    {
      "port": 1080,
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
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
            "address": "$SERVER_IP",
            "port": $VLESS_WS_TCP_PORT,
            "users": [
              {
                "id": "$VLESS_WS_UUID",
                "encryption": "none"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "$VLESS_WS_PATH",
          "headers": {
            "Host": "$CERT_CN"
          }
        }
      }
    }
  ]
}
EOF

echo ""
echo -e "\e[1;36m==================================================\e[0m"
echo -e "\e[1;32m✓ НАСТРОЙКА ЗАВЕРШЕНА!\e[0m"
echo -e "\e[1;36m==================================================\e[0m"
echo ""
echo -e "\e[1;33m▸ Все пароли заменены на UUID для безопасности\e[0m"
echo -e "\e[1;33m▸ Конфигурация сохранена: $SB_DIR/config-summary.txt\e[0m"
echo -e "\e[1;33m▸ Конфиг клиента Hysteria2: $SB_DIR/client-hysteria2.yaml\e[0m"
echo -e "\e[1;33m▸ Конфиг клиента VLESS: $SB_DIR/client-vless.json\e[0m"
echo -e "\e[1;33m▸ Домен TLS: $CERT_CN (уникальный на основе UUID)\e[0m"
echo ""
echo -e "\e[1;32mСгенерированные UUID:\e[0m"
echo -e "  VLESS: \e[1;36m$VLESS_WS_UUID\e[0m"
echo -e "  SOCKS5: \e[1;36m$SOCKS5_UUID\e[0m"
echo -e "  Hysteria2: \e[1;36m$HY2_UUID\e[0m"
echo -e "  Obfs: \e[1;36m$OBFS_PASSWORD\e[0m"
echo ""
echo -e "\e[1;35mДля подключения используйте ссылки из config-summary.txt\e[0m"
