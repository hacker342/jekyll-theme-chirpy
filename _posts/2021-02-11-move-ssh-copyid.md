---
title: Как заставить работать ssh ключи? 
author: Кирьянов Артем
date: 2021-02-11 11:00:00 +0300
categories: [It, DevOps]
tags: [devops]
---

# Как заставить работать ключи после переноса? 

```
$ ls -l ~/.ssh/id_rsa*
-rw------- 1 benj benj 1766 Jun 22  2011 .ssh/id_rsa
-rw-r--r-- 1 benj benj  388 Jun 22  2011 .ssh/id_rsa.pub
, через который можно осуществить:

$ chown benj:benj ~/.ssh/id_rsa*
$ chmod 600 ~/.ssh/id_rsa
$ chmod 644 ~/.ssh/id_rsa.pub
```