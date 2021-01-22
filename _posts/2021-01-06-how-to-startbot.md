---
title: Запуск бота на сервере
author: Кирьянов Артем
date: 2021-01-06 11:00:00 +0300
categories: [It, DevOps]
tags: [devops]
---

## Настройка бота.

После того как вы реализовали функционал вашего бота, его надо как-то запустить на сервере. Давайте это сделаем. 
Создайте файл на Вашем ПК с именем bot.service с таким содержанием:
```
[Unit]
Description=Telegram bot 'Town Wars'
After=syslog.target
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/local/bin/bot
ExecStart=/usr/bin/python3 /usr/local/bin/bot/bot.py
RestartSec=10
Restart=always
 
[Install]
WantedBy=multi-user.target
```
И загружаем его в нужный каталог
```
pscp.exe "C:\Users\Ilya\PycharmProjects\Bot\bot.service" root@123.123.12.12:/etc/systemd/system

```

Далее нужно прописать 4 команды в консоли сервера:

```
systemctl daemon-reload
systemctl enable bot
systemctl start bot
systemctl status bot

```

В моём случаи из-за определённых ошибок реализации, а конкретно многопоточности, пришлось переносить функцию для расчёта битв (battle_counter.py) в отдельного демона.

```
[Unit]
Description=Battle counter for telegram bot 'Town Wars'
After=syslog.target
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/usr/local/bin/bot
ExecStart=/usr/bin/python3 /usr/local/bin/bot/battle_counter.py
RestartSec=10
Restart=always
 
[Install]
WantedBy=multi-user.target
```
Ваш бот запущен и готов к работе!