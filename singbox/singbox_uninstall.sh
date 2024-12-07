#!/bin/bash
# Путь установки sing-box
SB_DIR="$HOME/.sb"
# Переименование программы sing-box
SB_EXE="sb-web"

if [ -d "$SB_DIR" ]; then
    read -p "Вы уверены, что хотите удалить? (Y/N, по умолчанию N): " choice
    choice=${choice^^} # Преобразование в верхний регистр
    if [ "$choice" == "Y" ]; then
        echo "Удаление..."
        # Здесь добавьте код для сброса данных
    else
        echo "Удаление отменено..."
        exit 1
    fi
fi
# Остановка программы
$SB_DIR/stop.sh
# Удаление старых настроек
rm -rf $SB_DIR
# Удаление связанных заданий (если были установлены ранее)
crontab -l | grep -v $SB_EXE | crontab -
