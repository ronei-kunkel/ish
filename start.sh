#!/bin/bash

### Network

NETWORK_NAME="ish_internal"

if [ -z "$(docker network ls -q -f name=$NETWORK_NAME)" ]; then
    docker network create -d bridge $NETWORK_NAME
    echo "Rede '$NETWORK_NAME' criada com sucesso"
    echo ""
else
    echo "A rede '$NETWORK_NAME' já existe. Ignorando a criação."
    echo ""
fi





### MariaDB

if [ "$(docker ps -q -f name=ish_mariadb)" ]; then
    echo "O container 'ish_mariadb' já está em execução"
    echo ""
else
    echo "O container 'ish_mariadb' será iniciado"

    env $(cat .env) \
    docker run --rm -d \
    -v $(pwd)/.docker/database/:/var/lib/mysql/ \
    -p 3306:3306 \
    --name ish_mariadb \
    --network $NETWORK_NAME \
    -e MYSQL_ROOT_PASSWORD=$DB_PASSWORD \
    -e MARIADB_ROOT_PASSWORD=$DB_PASSWORD \
    -e MARIADB_PASSWORD=$DB_PASSWORD \
    -e MARIADB_USER=$DB_USERNAME \
    mariadb:11.0.2

    echo ""
fi





### Fila

if [ "$(docker ps -q -f name=ish_rabbitmq)" ]; then
    echo "O container 'ish_rabbitmq' já está em execução"
    echo ""
else
    echo "O container 'ish_rabbitmq' será iniciado"

    chmod 777 -R $(pwd)/.docker/queue
    chmod 777 -R $(pwd)/.docker/rabbitmq
    chmod 777 -R $(pwd)/.docker/logs/rabbitmq

    rm -rf $(pwd)/.docker/queue/mnesia/
    rm -rf $(pwd)/.docker/queue/.erlang.cookie
    rm -rf $(pwd)/.docker/logs/rabbitmq/rabbit.log

    env $(cat .env) \
    docker run --rm -d \
    -v $(pwd)/.docker/queue:/var/lib/rabbitmq \
    -v $(pwd)/.docker/rabbitmq/10-defaults.conf:/etc/rabbitmq/conf.d/10-defaults.conf \
    -v $(pwd)/.docker/logs/rabbitmq:/var/log/rabbitmq/ \
    -p 5672:5672 \
    -p 15672:15672 \
    --name ish_rabbitmq \
    --network $NETWORK_NAME \
    -e RABBITMQ_ERLANG_COOKIE=$Q_COOKIE \
    -e RABBITMQ_DEFAULT_USER=$Q_USER \
    -e RABBITMQ_DEFAULT_PASS=$Q_PASS \
    rabbitmq:management

    echo ""
fi





### PHP Image

echo "A imagem 'ish_php82' está sendo criada."
docker build --quiet --rm -t ish_php82 .
echo ""

### PHP Container

if [ "$(docker ps -q -f name=ish_php82)" ]; then
    echo "O container 'ish_php82' já está em execução"
    echo ""
else
    echo "O container 'ish_php82' será iniciado"

    docker run --rm -d \
    -v $(pwd)/backend:/backend \
    -w / \
    -p 9000:9000 \
    --name ish_php82 \
    --network $NETWORK_NAME \
    ish_php82

    echo ""
fi





### Nginx

if [ "$(docker ps -q -f name=ish_nginx)" ]; then
    echo "O container 'ish_nginx' já está em execução"
    echo ""
else
    echo "O container 'ish_nginx' será iniciado"

    docker run --rm -d \
    -v $(pwd)/.docker/nginx/nginx.conf:/etc/nginx/nginx.conf \
    -v $(pwd)/.docker/logs/nginx/:/var/log/nginx/ \
    -v $(pwd)/backend:/backend \
    -p 80:80 \
    --name ish_nginx \
    --network $NETWORK_NAME \
    nginx:stable-alpine3.17-slim

    echo ""
fi

echo "Containers:"
docker ps -a --filter "status=running" --format 'table {{.Names }} \t {{.Status}}' | grep ish_
echo ""