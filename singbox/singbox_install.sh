#!/bin/bash

# --- Цвета ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Пути ---
SB_DIR="$HOME/.syslogd"
SB_EXE=".service"
ENV_FILE="$SB_DIR/.env"
CONFIG_FILE="$SB_DIR/config.json"

info() { echo -e "${CYAN}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Функция генерации UUID
gen_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen
    else
        openssl rand -hex 16 | sed -E 's/(.{8})(.{4})(.{4})(.{4})(.{12})/\1-\2-\3-\4-\5/'
    fi
}

# Загрузка настроек
load_env() {
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
    else
        info "Первая настройка: генерация UUID..."
        SERVER_IP="s1.serv00.com"
        SOCKS5_TCP_PORT=26584
        SOCKS5_USER="user_$(openssl rand -hex 3)"
        SOCKS5_PASSWORD=$(gen_uuid)
        VLESS_WS_UUID=$(gen_uuid)
        VLESS_WS_TCP_PORT=55031
        VLESS_WS_PATH="/ray-$(openssl rand -hex 4)"
        HY2_UDP_PORT=55197
        HY2_PASSWORD=$(gen_uuid)
        HY2_OBFS_PASS=$(gen_uuid)
        save_env
    fi
}

save_env() {
    mkdir -p "$SB_DIR"
    cat > "$ENV_FILE" <<EOF
SERVER_IP="$SERVER_IP"
SOCKS5_TCP_PORT=$SOCKS5_TCP_PORT
SOCKS5_USER="$SOCKS5_USER"
SOCKS5_PASSWORD="$SOCKS5_PASSWORD"
VLESS_WS_TCP_PORT=$VLESS_WS_TCP_PORT
VLESS_WS_UUID="$VLESS_WS_UUID"
VLESS_WS_PATH="$VLESS_WS_PATH"
HY2_UDP_PORT=$HY2_UDP_PORT
HY2_PASSWORD="$HY2_PASSWORD"
HY2_OBFS_PASS="$HY2_OBFS_PASS"
EOF
}

stop_service() {
    pkill -f "$SB_EXE" && success "Сервис остановлен" || warn "Процесс не найден"
    rm -f "$SB_DIR/nohup.out" 2>/dev/null
}

create_config() {
    cat > "$CONFIG_FILE" <<EOF
{
  "log": { "level": "silent", "disabled": true },
  "inbounds": [
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": $HY2_UDP_PORT,
      "users": [ { "password": "$HY2_PASSWORD" } ],
      "obfs": { "type": "salamander", "password": "$HY2_OBFS_PASS" },
      "up_mbps": 100,
      "down_mbps": 100,
      "ignore_client_bandwidth": true,
      "tls": {
        "enabled": true,
        "server_name": "$SERVER_IP",
        "key_path": "$SB_DIR/certs/private.key",
        "certificate_path": "$SB_DIR/certs/cert.crt"
      },
      "masquerade": "https://www.bing.com"
    },
    {
      "type": "vless",
      "listen": "::",
      "listen_port": $VLESS_WS_TCP_PORT,
      "users": [ { "uuid": "$VLESS_WS_UUID" } ],
      "transport": { "type": "ws", "path": "$VLESS_WS_PATH" }
    }
  ],
  "outbounds": [
    { "type": "direct", "tag": "direct" },
    { "type": "block", "tag": "block" }
  ],
  "route": {
    "rules": [
      { "rule_set": "ads", "outbound": "block" },
      { "ip_is_private": true, "outbound": "direct" }
    ],
    "rule_set": [
      {
        "type": "remote",
        "tag": "ads",
        "format": "binary",
        "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ads-all.srs",
        "download_detour": "direct"
      }
    ]
  }
}
EOF
}

# --- Интерфейс ---
mkdir -p "$SB_DIR/certs"
load_env

while true; do
    echo -e "\n${BLUE}=== Hysteria2 UUID Panel (Fixed) ===${NC}"
    echo "1) Установить / Обновить"
    echo "2) Быстрый перезапуск"
    echo "3) Остановить"
    echo "4) Показать ссылки"
    echo "5) Удалить всё"
    echo "0) Выход"
    read -p "Выберите действие: " opt

    case $opt in
        1)
            read -p "IP сервера [$SERVER_IP]: " input; SERVER_IP=${input:-$SERVER_IP}
            read -p "Порт Hy2 [$HY2_UDP_PORT]: " input; HY2_UDP_PORT=${input:-$HY2_UDP_PORT}
            save_env
            openssl ecparam -genkey -name prime256v1 -out "$SB_DIR/certs/private.key"
            openssl req -new -x509 -days 36500 -key "$SB_DIR/certs/private.key" -out "$SB_DIR/certs/cert.crt" -subj "/CN=$SERVER_IP"
            wget -q https://github.com/qlxi/singbox-for-serv00/releases/download/singbox/singbox -O "$SB_DIR/$SB_EXE"
            chmod +x "$SB_DIR/$SB_EXE"
            create_config
            stop_service
            nohup "$SB_DIR/$SB_EXE" run -c "$CONFIG_FILE" >/dev/null 2>&1 &
            success "Запущено в фоне (логи отключены)"
            bash <(curl -s https://raw.githubusercontent.com/qlxi/singbox-for-serv00/main/singbox/check_cron_sb.sh) 2>/dev/null
            ;;
        2)
            stop_service
            nohup "$SB_DIR/$SB_EXE" run -c "$CONFIG_FILE" >/dev/null 2>&1 &
            success "Перезапущено"
            ;;
        3)
            stop_service
            ;;
        4)
            echo -e "\n${PURPLE}--- HYSTERIA2 (UUID) ---${NC}"
            echo -e "Ссылка: hysteria2://$HY2_PASSWORD@$SERVER_IP:$HY2_UDP_PORT/?sni=$SERVER_IP&obfs=salamander&obfs-password=$HY2_OBFS_PASS&insecure=1#Serv00_UUID"
            echo -e "\n${CYAN}--- VLESS ---${NC}"
            echo -e "vless://$VLESS_WS_UUID@$SERVER_IP:$VLESS_WS_TCP_PORT?encryption=none&security=none&type=ws&path=$VLESS_WS_PATH#Serv00_VLESS"
            ;;
        5)
            stop_service
            rm -rf "$SB_DIR"
            success "Удалено"
            exit 0
            ;;
        0) exit 0 ;;
        *) error "Неверный ввод" ;;
    esac
done
