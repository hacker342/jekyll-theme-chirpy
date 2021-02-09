---
title: Почему Git думает что файлы изменились
author: Кирьянов Артем
date: 2021-02-09 16:06:00 +0300
categories: [It, DevOps]
tags: [devops]
---

# Настройки

Я очень долго мучился в подсистеме Linux - WSL. Почему-то Git считает, что все файлы изменились. 
Решение ниже:

Для текущего репозитория
git config core.filemode false   

Глобальные настройки
git config --global core.filemode false