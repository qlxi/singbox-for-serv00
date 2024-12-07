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
> - 如需修改节点配置，只需修改 sing-box 配置文件（`$HOME/.sb/config.json`）然后重启即可（重启  sing-box 命令：`cd $HOME/.sb; ./stop.sh && ./start-nohup.sh`），注意：手动修改配置文件重启，不会自动更新 `links.txt` 节点链接文件。

一键脚本卸载 sing-box 和相关配置：

```bash
bash <(curl -s https://raw.githubusercontent.com/qlxi/singbox-for-serv00/refs/heads/main/singbox/singbox_uninstall.sh)
```


一键脚本安装 nezha-agent 并自动配置：

```bash
bash <(curl -s https://raw.githubusercontent.com/xtfree/singbox-for-serv00/main/nezha/nezha_install.sh)
#bash <(curl -s https://raw.githubusercontent.com/xtfree/singbox-for-serv00/refs/heads/main/nezha/nezha_install.sh)
```

默认安装目录：`$HOME/.nezha-agent`

一键脚本卸载 nezha-agent 和相关配置：

```bash
bash <(curl -s https://raw.githubusercontent.com/xtfree/singbox-for-serv00/main/nezha/nezha_uninstall.sh)
```




## Github Actions 保活

Settings >> Secrets and variables >> Actions >> Repository secrets >> New repository secret
- Name（变量名）：`ACCOUNTS_JSON`
- Secret（秘钥内容）如下：

    ```json
    [
      { "username": "xts001", "password": "7HEt(xeRxttdvgB^nCU6", "panel": "panel4.serv00.com", "ssh": "s4.serv00.com" },
      { "username": "xts002", "password": "4))@cRP%Ht8AryHlh^#", "panel": "panel7.serv00.com", "ssh": "s7.serv00.com" },
      { "username": "xts003", "password": "%Mg^dDMo6yIY$dZmxWNy", "panel": "panel.ct8.pl", "ssh": "s1.ct8.pl" }
    ]
    ```
    
    > 说明：请根据自己 Serv00 账号情况对 Secret 进行修改。以上秘钥内容是多个账号的情况，单个账号只需保留一个 json 对象即可

更详细操作参考：

- https://blog.cmliussss.com/p/Serv00-Socks5/
- https://www.youtube.com/watch?v=L6gPyyD3dUw

## 参考

- https://github.com/cmliu/socks5-for-serv00
- https://github.com/gshtwy/socks5-hysteria2-for-Serv00-CT8
