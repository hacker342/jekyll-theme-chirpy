---
title: Связка Confluence+Jira+Nginx(SSL) в Docker
author: Кирьянов Артем
date: 2020-12-21 12:21:00 +0300
categories: [It, DevOps]
tags: [devops]
---

## Docker. 

Рассказывать про Docker я не буду и пропущю настройку DNS так как этой информации куча в интернете, но сегодня мне хотелось бы рассказать про настройку Confluence+Jira+Nginx(SSL) в Docker контейнерах. Почему в Docker? Так было решено сделать, так как сервер для разработки, ну и в целом это удобно, удобно поддерживать и конфигурировать. 

### docker-compose

Заходим на наш сервер, создаем дирректорию, где у нас будет находится наши docker файлы. Создаем docker-compose.yml
Пишем туда: 

```
version: "3"

services:

  nginx:
    restart: unless-stopped
    image: nginx:1.15-alpine
    ports:
    - 80:80
    - 443:443
    command: "/bin/sh -c 'while :; do sleep 6h & wait $${!}; nginx -s reload; done & nginx -g \"daemon off;\"'"
    volumes:
    - ./configs/nginx:/etc/nginx/conf.d
    - ./logs/nginx:/var/log/nginx
    - ./configs/certbot/conf:/etc/letsencrypt
    - ./configs/certbot/www:/var/www/certbot
    networks: 
    - proxy

  certbot:
    image: certbot/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"
    volumes:
    - /etc/localtime:/etc/localtime
    - ./configs/certbot/conf:/etc/letsencrypt
    - ./configs/certbot/www:/var/www/certbot
    - ./configs/certbot/log:/var/log/letsencrypt/
  
  confuence:
    restart: unless-stopped
    image: atlassian/confluence-server:latest
    environment:
    - JVM_MINIMUM_MEMORY=2048m
    - JVM_MAXIMUM_MEMORY=4096m
    - ATL_proxyName=confluence.test.com
    - ATL_proxyPort=443
    - ATL_tomcat_scheme=https
    ports:
    - 8090:8090
    - 8091:8091
    volumes:
    - ./atlassian/confuence:/var/atlassian/application-data/confuence
    networks:
    - jira

  jira-software:
    restart: unless-stopped
    image: atlassian/jira-software:latest
    container_name: jira-server
    environment:
    - JVM_MINIMUM_MEMORY=2048m
    - JVM_MAXIMUM_MEMORY=4096m
    - ATL_proxyName=jira.test.com
    - ATL_proxyPort=443
    - ATL_tomcat_scheme=https
    ports:
    - 8080:8080
    volumes:
    - ./atlassian/jira:/var/atlassian/application-data/jira
    networks:
    - jira

networks:
  jira:
  proxy: 
  ```

Запускаем docker-compose up и docker запустит наши контейнеры и создаст дирректории наших проектов. 

### Nginx

Давайте создадим конфигурацию для nginx.

```
server {
    server_name confluence.test.com;

    listen 80;
    listen [::]:80;

    listen              443 ssl;
    listen              [::]:443 ssl;
    ssl_certificate     /etc/letsencrypt/live/confluence.test.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/confluence.test.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    charset utf-8;
    server_tokens off;

    resolver 127.0.0.11 ipv6=off;
    set $upstream confluence.test.com;

   if ($scheme = "http") {
      return 301 https://$server_name$request_uri;
  } 
		
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }


    location / {
        proxy_pass_header Authorization;
        proxy_pass http://$upstream:8090;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_buffering off;
        client_max_body_size 0;
        proxy_read_timeout 36000s;
        proxy_redirect off;
    }
}
```

Выходим из конфигов и там где у нас docker файлы, создаем папку scripts и создаем файл init-letsencrypt.sh c таким вот содержаением: 
```
#!/bin/bash

if ! [ -x "$(command -v docker-compose)" ]; then
  echo 'Error: docker-compose is not installed.' >&2
  exit 1
fi

domains=(jira.test.com)
rsa_key_size=4096
data_path="../configs/certbot"
email="test@test.com" # Adding a valid address is strongly recommended
staging=0 # Set to 1 if you're testing your setup to avoid hitting request limits

if [ -d "$data_path" ]; then
  read -p "Existing data found for $domains. Continue and replace existing certificate? (y/N) " decision
  if [ "$decision" != "Y" ] && [ "$decision" != "y" ]; then
    exit
  fi
fi


if [ ! -e "$data_path/conf/options-ssl-nginx.conf" ] || [ ! -e "$data_path/conf/ssl-dhparams.pem" ]; then
  echo "### Downloading recommended TLS parameters ..."
  mkdir -p "$data_path/conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$data_path/conf/options-ssl-nginx.conf"
  curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$data_path/conf/ssl-dhparams.pem"
  echo
fi

echo "### Creating dummy certificate for $domains ..."
path="/etc/letsencrypt/live/$domains"
mkdir -p "$data_path/conf/live/$domains"
docker-compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:$rsa_key_size -days 1\
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot
echo


echo "### Starting nginx ..."
docker-compose up --force-recreate -d nginx
echo

echo "### Deleting dummy certificate for $domains ..."
docker-compose run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$domains && \
  rm -Rf /etc/letsencrypt/archive/$domains && \
  rm -Rf /etc/letsencrypt/renewal/$domains.conf" certbot
echo


echo "### Requesting Let's Encrypt certificate for $domains ..."
#Join $domains to -d args
domain_args=""
for domain in "${domains[@]}"; do
  domain_args="$domain_args -d $domain"
done

# Select appropriate email arg
case "$email" in
  "") email_arg="--register-unsafely-without-email" ;;
  *) email_arg="--email $email" ;;
esac

# Enable staging mode if needed
if [ $staging != "0" ]; then staging_arg="--staging"; fi

docker-compose run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $staging_arg \
    $email_arg \
    $domain_args \
    --rsa-key-size $rsa_key_size \
    --agree-tos \
    --force-renewal" certbot
echo

echo "### Reloading nginx ..."
docker-compose exec nginx nginx -s reload
```
В скрипте надо указать домен и почту. Сохраняем скрипт и делаем его исполняемым, запускаем скрипт, скрипт создаст сертификат для вашего домена и запустит docker-compose.

Все конечно хорошо, но нужно создать БД для jira и confluence. 
Я решил не прописывать в docker-compose.yml БД, а создать ее вот так:
```
docker run -d  -p 5432:5432 \
    --name postgres \
    -e POSTGRES_USER=postgres \
    -e POSTGRES_PASSWORD=mysecretpassword \
    -v postgresData:/var/lib/postgresql/data \
    postgres:10
```

Мы конечно можем войти в контейнер и создать БД и все такое, но лучше было бы отобразить все это дело через интерфейс. 
Для этого нам поможет pgAdmin

```
docker run -p 5050:80 \
    --name pgadmin \
    -e 'PGADMIN_DEFAULT_EMAIL=postgres' \
    -e 'PGADMIN_DEFAULT_PASSWORD=SuperSecret' \
    -v pgadminData:/pgadmin4 \
    -v pgAdminApplicationData:/var/lib/pgadmin \
    -d dpage/pgadmin4
```

Заходим в браузер ip:5050, входим в интерфейс. 
![](https://i.ibb.co/gTJp6R5/pg-Admin-Add-new-server.png)

Далее Нажмите на кнопку " Добавить новый сервер” в разделе быстрых ссылок
Добавьте “имя " для соединения
На вкладке "подключение" настройте “имя хоста / адрес", "имя пользователя" и "пароль – - затем нажмите кнопку" Сохранить“
подключение к серверу в pgAdmin

![](https://i.ibb.co/svSKk13/pg-Admin-Add-new-server-enter-name.png)
![](https://i.ibb.co/1dNmr9L/pg-Admin-Add-new-server-configure-connection.png)


### Создание БД для Jira и Confluence

Мы создадим собственного пользователя для каждой базы данных, который является владельцем ее собственной базы данных. Имя пользователя и имя базы данных будут одинаковыми, чтобы все было просто. Это более безопасно, чем использование системного пользователя postgres для баз данных.

Сначала мы создадим пользователя и базу данных для Jira:
![](https://i.ibb.co/W2D9ttc/pg-Admin-create-new-user.png)

Заполните ваши пользователи “имя” в общем разделе
![](https://i.ibb.co/8NWxNQ8/pg-Admin-create-new-user-general.png)

Перейдите на вкладку и введите свой новый "пароль”:
![](https://i.ibb.co/DDFYcw8/pg-Admin-create-new-user-definition.png)
![](https://i.ibb.co/DwnMFzP/pg-Admin-create-new-user-privileges.png)
![](https://i.ibb.co/Jjcjbgx/pg-Admin-create-new-database.png)
![](https://i.ibb.co/XtQDpjz/pg-Admin-create-new-database-general.png)
![](https://i.ibb.co/bv461pW/pg-Admin-create-new-database-definition.png)
![](https://i.ibb.co/jGP6tkC/pg-Admin-create-new-database-definition-confluence.png)