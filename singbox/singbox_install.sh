#!/bin/bash
## (1) Настройка узлов
# IP-адрес сервера
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

# Функция генерации безопасных паролей
generate_secure_password() {
  tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c 24
}

generate_secure_uuid() {
  uuidgen 2>/dev/null || (echo -n "$(date +%s%N)$RANDOM" | md5sum | awk '{print $1}' | sed 's/\(........\)\(....\)\(....\)\(....\)\(............\)/\1-\2-\3-\4-\5/')
}

# Предложение сгенерировать более безопасные учетные данные
echo "=== Генерация безопасных учетных данных ==="
read -p "Сгенерировать новый безопасный UUID для VLESS? (Y/N, по умолчанию Y): " gen_uuid
gen_uuid=${gen_uuid:-Y}
gen_uuid=${gen_uuid^^}
if [ "$gen_uuid" == "Y" ]; then
  VLESS_WS_UUID=$(generate_secure_uuid)
  echo "Новый UUID: $VLESS_WS_UUID"
fi

read -p "Сгенерировать новый безопасный пароль для SOCKS5? (Y/N, по умолчанию Y): " gen_socks_pass
gen_socks_pass=${gen_socks_pass:-Y}
gen_socks_pass=${gen_socks_pass^^}
if [ "$gen_socks_pass" == "Y" ]; then
  SOCKS5_PASSWORD=$(generate_secure_password)
  echo "Новый пароль SOCKS5: $SOCKS5_PASSWORD"
fi

read -p "Сгенерировать новый безопасный пароль для Hysteria2? (Y/N, по умолчанию Y): " gen_hy2_pass
gen_hy2_pass=${gen_hy2_pass:-Y}
gen_hy2_pass=${gen_hy2_pass^^}
if [ "$gen_hy2_pass" == "Y" ]; then
  HY2_PASSWORD=$(generate_secure_password)
  echo "Новый пароль Hysteria2: $HY2_PASSWORD"
fi

# Ввод параметров
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

# Генерация сертификата ECDSA P-256 (самый распространенный, хороший баланс безопасности и производительности)
mkdir -p $SB_DIR/certs
cd $SB_DIR/certs
openssl ecparam -genkey -name prime256v1 -out private.key 2>/dev/null
if [ $? -ne 0 ]; then
  # Fallback если openssl не поддерживает ecparam
  openssl genrsa -out private.key 2048
  openssl req -new -x509 -days 365 -key private.key -out cert.crt -subj "/CN=time.android.com" -sha256
else
  openssl req -new -x509 -days 365 -key private.key -out cert.crt -subj "/CN=time.android.com" -sha256
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

# Создание оптимизированного конфига для FreeBSD без root
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
          "password": "$SOCKS5_PASSWORD"
        }
      ],
      "sniff": true,
      "sniff_override_destination": true,
      "domain_strategy": "prefer_ipv4"
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
          "Host": "time.android.com"
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
          "password": "$HY2_PASSWORD"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "time.android.com",
        "key_path": "$SB_DIR/certs/private.key",
        "certificate_path": "$SB_DIR/certs/cert.crt",
        "alpn": ["h3"],
        "min_version": "1.3"
      },
      "obfs": {
        "type": "salamander",
        "password": "$HY2_PASSWORD"
      },
      "masquerade": {
        "type": "proxy",
        "proxy": {
          "url": "https://time.android.com",
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

## (4) Добавление планового задания без sudo
# Создание скрипта для проверки и перезапуска
cat >check_service.sh <<EOF
#!/bin/bash
SB_DIR="$SB_DIR"
SB_EXE="$SB_EXE"
LOG_FILE="\$SB_DIR/service.log"

# Проверка работает ли сервис
if ! pgrep -x "\$SB_EXE" >/dev/null; then
  echo "\$(date): Сервис не запущен, перезапуск..." >> "\$LOG_FILE"
  cd "\$SB_DIR"
  ./stop.sh >/dev/null 2>&1
  sleep 1
  ./start-nohup.sh >/dev/null 2>&1
fi

# Очистка старых логов (сохраняем последние 1000 строк)
if [ -f "\$SB_DIR/singbox.log" ]; then
  tail -1000 "\$SB_DIR/singbox.log" > "\$SB_DIR/singbox.log.tmp"
  mv "\$SB_DIR/singbox.log.tmp" "\$SB_DIR/singbox.log"
fi

# Очистка nohup.log
if [ -f "\$SB_DIR/nohup.log" ]; then
  tail -500 "\$SB_DIR/nohup.log" > "\$SB_DIR/nohup.log.tmp"
  mv "\$SB_DIR/nohup.log.tmp" "\$SB_DIR/nohup.log"
fi
EOF

chmod +x check_service.sh

# Добавление в cron пользователя
(crontab -l 2>/dev/null | grep -v "$SB_DIR/check_service.sh"; echo "*/5 * * * * $SB_DIR/check_service.sh >/dev/null 2>&1") | crontab -

## (5) Запись ссылок на узлы
rm -f links.txt
echo "=== Конфигурация сервера ===" > $SB_DIR/links.txt
echo "Дата: $(date)" >> $SB_DIR/links.txt
echo "IP сервера: $SERVER_IP" >> $SB_DIR/links.txt
echo "" >> $SB_DIR/links.txt

echo "=== VLESS+WS (WebSocket) ===" >> $SB_DIR/links.txt
echo "vless://$VLESS_WS_UUID@$SERVER_IP:$VLESS_WS_TCP_PORT?encryption=none&security=none&type=ws&path=$VLESS_WS_PATH&host=time.android.com#serv00-vless" >> $SB_DIR/links.txt
echo "" >> $SB_DIR/links.txt

echo "=== SOCKS5 ===" >> $SB_DIR/links.txt
echo "socks://$SOCKS5_USER:$SOCKS5_PASSWORD@$SERVER_IP:$SOCKS5_TCP_PORT#serv00-socks" >> $SB_DIR/links.txt
echo "" >> $SB_DIR/links.txt

echo "=== Hysteria2 (Рекомендуется) ===" >> $SB_DIR/links.txt
echo "Сервер: $SERVER_IP" >> $SB_DIR/links.txt
echo "Порт UDP: $HY2_UDP_PORT" >> $SB_DIR/links.txt
echo "Пароль: $HY2_PASSWORD" >> $SB_DIR/links.txt
echo "SNI: time.android.com" >> $SB_DIR/links.txt
echo "Obfs: salamander" >> $SB_DIR/links.txt
echo "Пароль obfs: $HY2_PASSWORD" >> $SB_DIR/links.txt
echo "" >> $SB_DIR/links.txt

# Ссылка Hysteria2 для клиентов
echo "Ссылка для клиентов Hysteria2:" >> $SB_DIR/links.txt
echo "hysteria2://$HY2_PASSWORD@$SERVER_IP:$HY2_UDP_PORT/?sni=time.android.com&insecure=1&obfs=salamander&obfs-password=$HY2_PASSWORD&upmbps=100&downmbps=100#serv00-hy2" >> $SB_DIR/links.txt
echo "" >> $SB_DIR/links.txt

echo "=== Быстрая команда для клиента Hysteria2 ===" >> $SB_DIR/links.txt
echo "Для Linux/macOS:" >> $SB_DIR/links.txt
echo "curl -fsSL https://get.hy2.sh/ | bash" >> $SB_DIR/links.txt
echo "hysteria client --config config.yaml" >> $SB_DIR/links.txt
echo "" >> $SB_DIR/links.txt

# Создание примера конфига для клиента Hysteria2
cat > $SB_DIR/client-config-hysteria2.yaml <<EOF
server: $SERVER_IP:$HY2_UDP_PORT
auth: $HY2_PASSWORD
tls:
  sni: time.android.com
  insecure: true
obfs:
  type: salamander
  password: $HY2_PASSWORD
bandwidth:
  up: 100 mbps
  down: 100 mbps
socks5:
  listen: 127.0.0.1:1080
http:
  listen: 127.0.0.1:8080
EOF

echo "Пример конфига клиента Hysteria2 сохранен: $SB_DIR/client-config-hysteria2.yaml" >> $SB_DIR/links.txt

cat $SB_DIR/links.txt
echo ""
echo -e "\e[1;32m✓ Настройка завершена!\e[0m"
echo -e "\e[1;33m• Конфиг: $SB_DIR/config.json\e[0m"
echo -e "\e[1;33m• Логи: $SB_DIR/singbox.log\e[0m"
echo -e "\e[1;33m• Ссылки: $SB_DIR/links.txt\e[0m"
echo -e "\e[1;33m• Конфиг клиента Hysteria2: $SB_DIR/client-config-hysteria2.yaml\e[0m"
echo -e "\e[1;33m• Проверка сервиса каждые 5 минут\e[0m"
echo -e "\e[1;36mДля остановки: $SB_DIR/stop.sh\e[0m"
echo -e "\e[1;36mДля запуска: $SB_DIR/start-nohup.sh\e[0m"
