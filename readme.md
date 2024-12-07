# singbox-for-serv00

На машинах Serv00 или CT8 установите и настройте sing-box с помощью скрипта одного клика (поддерживает socks5, vless+ws, hysteria2 узлы)
Поддерживает Crontab для поддержания процесса в активном состоянии, а также использует GitHub Actions для автоматического продления аккаунта и автоматизации управления, обеспечивая долгосрочную стабильную работу.

- socks5 Узлы могут быть использованы в проекте [cmliu/edgetunnel](https://github.com/cmliu/edgetunnel) чтобы помочь узлам CF vless разблокировать такие сервисы, как ChatGPT.
- vless+ws Узлы могут самостоятельно использовать CDN для реализации прокси-ускорения (рекомендуется добавить TLS в CDN).
- hysteria2 Узлы в первую очередь используются для захвата пропускной способности с целью улучшения скорости интернета (если сеть доступна).


## Быстрое использование.

一Скрипт для установки sing-box и автоматической настройки узлов socks5, vless+ws, hysteria2:

```bash
bash <(curl -s https://raw.githubusercontent.com/qlxi/singbox-for-serv00/refs/heads/main/singbox/singbox_install.sh)
```

> Описание:
>
> - Директория установки по умолчанию: `$HOME/.sb`
> - При установке с помощью скрипта, следуйте интерактивным подсказкам и введите основную конфигурацию для различных узлов. Установочный скрипт автоматически запустит sing-box и добавит задачу на перезапуск в crontab. После завершения установки скрипт автоматически сгенерирует ссылки на узлы и сохранит их в файл `$HOME/.sb/links.txt`
> - Чтобы изменить настройки узла, достаточно отредактировать конфигурационный файл sing-box（`$HOME/.sb/config.json`), а затем перезапустить программу (команда для перезапуска sing-box: `cd $HOME/.sb; ./stop.sh && ./start-nohup.sh`). Обратите внимание: ручное изменение конфигурационного файла и перезапуск не приведут к автоматическому обновлению файла ссылок узлов `links.txt`

一Команда для удаления sing-box и связанных конфигураций:

```bash
bash <(curl -s https://raw.githubusercontent.com/qlxi/singbox-for-serv00/refs/heads/main/singbox/singbox_uninstall.sh)
```

## Github Actions (поддержание жизни)

Settings >> Secrets and variables >> Actions >> Repository secrets >> New repository secret
- Name (имя переменной): `ACCOUNTS_JSON`
- Secret (Содержание секрета):

    ```json
    [
      { "username": "xts001", "password": "7HEt(xeRxttdvgB^nCU6", "panel": "panel4.serv00.com", "ssh": "s4.serv00.com" },
      { "username": "xts002", "password": "4))@cRP%Ht8AryHlh^#", "panel": "panel7.serv00.com", "ssh": "s7.serv00.com" },
      { "username": "xts003", "password": "%Mg^dDMo6yIY$dZmxWNy", "panel": "panel.ct8.pl", "ssh": "s1.ct8.pl" }
    ]
    ```
    
    > Объяснение: Пожалуйста, измените Secret в соответствии с ситуацией вашего аккаунта Serv00. Содержимое выше — это информация для нескольких аккаунтов, для одного аккаунта достаточно оставить только один объект в формате JSON.

