#!/bin/bash
SB_DIR="$HOME/.sb"
# Переименование программы sing-box
SB_EXE="sb-web"
CRON_SB="nohup ${SB_DIR}/start.sh >/dev/null 2>&1 &"
echo "Проверка и добавление задач в crontab"
if [ -e "${SB_DIR}/start.sh" ]; then
    echo "Добавление задачи на перезагрузку для sing-box в crontab"
    (crontab -l | grep -F "@reboot pkill -kill -u $(whoami) && ${CRON_SB}") || (
        crontab -l
        echo "@reboot pkill -kill -u $(whoami) && ${CRON_SB}"
    ) | crontab -
    (crontab -l | grep -F "* * pgrep -x \"$SB_EXE\" > /dev/null || ${CRON_SB}") || (
        crontab -l
        echo "*/12 * * * * pgrep -x \"$SB_EXE\" > /dev/null || ${CRON_SB}"
    ) | crontab -
fi
